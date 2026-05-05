import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/package_model.dart';
import '../models/promotion_assignment_model.dart';
import '../models/user_model.dart';
import '../models/user_preferences_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> searchUsersByEmail(String query) async {
    if (query.trim().isEmpty) return [];
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'user')
        .where('email', isGreaterThanOrEqualTo: query.trim())
        .where('email', isLessThanOrEqualTo: '${query.trim()}\uf8ff')
        .limit(20)
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'email': data['email'] ?? '',
        'name': data['name'] ?? '',
        'surname': data['surname'] ?? '',
      };
    }).toList();
  }

  Stream<AppUser> getUserStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snap) => AppUser.fromFirestore(snap));
  }

  Future<void> updatePreferences(
      String userId, UserPreferences preferences) async {
    await _db.collection('users').doc(userId).update({
      'preferences': preferences.toMap(),
    });
  }

  // ── Attendance sync ────────────────────────────────────────────────────────
  //
  // Called when the HomeScreen loads. Finds every active booking whose session
  // has already started and hasn't yet been counted, then:
  //   • decrements `booked` in the matching promotion
  //   • increments `attended` in the matching promotion
  //   • stamps `attendanceRecorded: true` on the booking (idempotency guard)
  //   • archives promotions that are fully attended OR expired with no pending bookings
  //
  // Edge case: expired promotion with booked-but-not-yet-attended sessions stays
  // in promotions[] (shown with "Expired" badge) until those sessions are attended,
  // then it archives. This way the user can still see their pending sessions.
  //
  // Comparing against sessionStartsAt is intentional: once a session begins
  // the slot is consumed whether the user physically attended or not.

  Future<void> syncAttendedSessions(String userId) async {
    final nowTs = Timestamp.fromDate(DateTime.now());

    // Fetch all past active bookings. The composite index needed is:
    //   bookings | userId ASC · status ASC · sessionStartsAt ASC
    // Firestore will surface a link to create it on first run if absent.
    final snap = await _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .where('sessionStartsAt', isLessThan: nowTs)
        .get();

    if (snap.docs.isEmpty) return;

    // Client-side filter: skip already-recorded ones (handles legacy bookings
    // that predate the attendanceRecorded field — they'll be treated as false).
    final toProcess = snap.docs
        .where((doc) => doc.data()['attendanceRecorded'] != true)
        .toList();

    if (toProcess.isEmpty) return;

    await _db.runTransaction((tx) async {
      final userRef = _db.collection('users').doc(userId);
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) return;

      final userData = userSnap.data()!;

      // Build a mutable copy of the promotions array.
      final List<Map<String, dynamic>> promos = userData['promotions'] != null
          ? (userData['promotions'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : [];

      // ── Step 1: move booked → attended for each unrecorded past booking ──
      for (final bookingDoc in toProcess) {
        final data = bookingDoc.data();
        final promoTs = data['promotionCreatedAt'];

        if (promoTs != null && promos.isNotEmpty) {
          final targetMs = (promoTs as Timestamp).millisecondsSinceEpoch;
          final idx = promos.indexWhere((p) =>
              p['createdAt'] is Timestamp &&
              (p['createdAt'] as Timestamp).millisecondsSinceEpoch ==
                  targetMs);

          if (idx != -1) {
            final currentBooked = (promos[idx]['booked'] as int? ?? 0);
            final currentAttended = (promos[idx]['attended'] as int? ?? 0);
            promos[idx] = {
              ...promos[idx],
              'booked': (currentBooked - 1).clamp(0, 999),
              'attended': currentAttended + 1,
            };
          }
        }

        // Stamp the booking so we never process it again.
        tx.update(bookingDoc.reference, {'attendanceRecorded': true});
      }

      // ── Step 2: archive promotions that are done ──────────────────────────
      //
      // Archive when fully attended (attended >= total) regardless of expiry,
      // OR when expired with no pending booked sessions (booked == 0).
      // Expired promotions with still-booked sessions stay visible so the user
      // can track those pending sessions; they archive once all are attended.
      final now = DateTime.now();
      final List<Map<String, dynamic>> activePromos = [];
      final List<Map<String, dynamic>> toArchive = [];

      for (final p in promos) {
        final expiresAt = (p['expiresAt'] as Timestamp).toDate();
        final total = (p['totalSessions'] as int? ?? 0);
        final attended = (p['attended'] as int? ?? 0);
        final booked = (p['booked'] as int? ?? 0);
        final isExpired = now.isAfter(expiresAt);
        final isFullyAttended = attended >= total;
        final isExpiredNoPending = isExpired && booked == 0;

        if (isFullyAttended || isExpiredNoPending) {
          toArchive.add(p);
        } else {
          activePromos.add(p);
        }
      }

      final List<dynamic> existingHistory =
          (userData['promotionHistory'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

      final updates = <String, dynamic>{'promotions': activePromos};
      if (toArchive.isNotEmpty) {
        updates['promotionHistory'] = [...existingHistory, ...toArchive];
      }

      tx.update(userRef, updates);
    });
  }

  // ── Assign promotion ───────────────────────────────────────────────────────

  Future<void> assignPromotionFromPackage({
    required String userId,
    required Package package,
    required DateTime expiresAt,
    required String assignedByUid,
    required String assignedByName,
    required String targetUserName,
    required String targetUserEmail,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final now = DateTime.now();
    final promoCreatedAt = Timestamp.fromDate(now);

    // Read user to check trial state before opening the transaction.
    final userSnap = await userRef.get();
    final data = userSnap.data()!;
    final trialSessionUsed = data['trialSessionUsed'] as bool? ?? false;

    // Locate the active trial booking outside the transaction (query needed).
    DocumentReference? trialBookingRef;
    bool trialSessionIsFuture = false;

    if (trialSessionUsed) {
      final trialSnap = await _db
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('isTrialBooking', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (trialSnap.docs.isNotEmpty) {
        trialBookingRef = trialSnap.docs.first.reference;
        final sessionStartsAt =
            (trialSnap.docs.first.data()['sessionStartsAt'] as Timestamp)
                .toDate();
        trialSessionIsFuture = sessionStartsAt.isAfter(now);
      }
    }

    // Determine initial usage counts for the new promotion.
    final int initialBooked = (trialSessionUsed && trialSessionIsFuture) ? 1 : 0;
    final int initialAttended =
        (trialSessionUsed && !trialSessionIsFuture && trialBookingRef != null)
            ? 1
            : 0;
    // Edge case: trialSessionUsed but no active booking found means the trial
    // session is already completed/past → count as attended=1.
    final int attendedFallback =
        (trialSessionUsed && trialBookingRef == null) ? 1 : initialAttended;

    await _db.runTransaction((tx) async {
      final freshSnap = await tx.get(userRef);
      final freshData = freshSnap.data()!;

      final newPromo = {
        'packageId': package.id,
        'packageName': package.name,
        'totalSessions': package.numberOfSessions,
        'booked': initialBooked,
        'attended': trialBookingRef != null ? initialAttended : attendedFallback,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': promoCreatedAt,
      };

      List<dynamic> existing = [];
      if (freshData['promotions'] != null) {
        existing = List<dynamic>.from(freshData['promotions'] as List);
      } else if (freshData['promotion'] != null) {
        existing = [freshData['promotion']];
      }
      existing.add(newPromo);

      final updates = <String, dynamic>{'promotions': existing};
      if (freshData['promotion'] != null) {
        updates['promotion'] = FieldValue.delete();
      }
      if (trialSessionUsed) {
        updates['trialSessionUsed'] = false;
      }
      tx.update(userRef, updates);
    });

    // After the transaction: link the trial booking to the new promotion so
    // that any future cancellation uses the normal refund path.
    if (trialBookingRef != null) {
      await trialBookingRef.update({'promotionCreatedAt': promoCreatedAt});
    }

    // Record the assignment for owner audit history.
    final assignment = PromotionAssignment(
      id: '',
      assignedByUid: assignedByUid,
      assignedByName: assignedByName,
      packageId: package.id,
      packageName: package.name,
      numberOfSessions: package.numberOfSessions,
      targetUserId: userId,
      targetUserName: targetUserName,
      targetUserEmail: targetUserEmail,
      assignedAt: now,
    );
    await _db.collection('promotion_assignments').add(assignment.toMap());
  }
}