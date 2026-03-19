import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/package_model.dart';
import '../models/user_model.dart';
import '../models/user_preferences_model.dart';
import '../models/booking_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------- SEARCH USERS BY EMAIL (role == 'user' only) ----------------
  // Requires a Firestore composite index on: role ASC, email ASC
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

  // ---------------- REAL-TIME USER STREAM ----------------
  Stream<AppUser> getUserStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snap) => AppUser.fromFirestore(snap));
  }

  // ---------------- UPDATE PREFERENCES ----------------
  Future<void> updatePreferences(
      String userId, UserPreferences preferences) async {
    await _db.collection('users').doc(userId).update({
      'preferences': preferences.toMap(),
    });
  }

  // ---------------- ASSIGN PROMOTION FROM PACKAGE ----------------
  // If the user has a pending trial booking, the new promotion absorbs it:
  //   • Promotion starts with booked=1 (future trial) or attended=1 (past trial).
  //   • The trial booking's promotionCreatedAt is updated so cancel/refund
  //     routing works normally from that point on.
  //   • trialSessionUsed is reset to false.

  Future<void> assignPromotionFromPackage({
    required String userId,
    required Package package,
    required DateTime expiresAt,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final now = DateTime.now();
    final promoCreatedAt = Timestamp.fromDate(now);

    // ── Step 1: read user doc outside transaction to decide trial state ───
    final userSnap = await userRef.get();
    final data = userSnap.data()!;
    final trialSessionUsed = data['trialSessionUsed'] as bool? ?? false;

    // ── Step 2: find the active trial booking (if any) ────────────────────
    // Done outside the transaction because Firestore transactions don't
    // support collection-group queries.
    Booking? trialBooking;
    if (trialSessionUsed) {
      final trialSnap = await _db
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('isTrialBooking', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      if (trialSnap.docs.isNotEmpty) {
        // We only need a few fields — parse directly.
        final d = trialSnap.docs.first.data();
        final sessionStartsAt =
            (d['sessionStartsAt'] as Timestamp).toDate();
        trialBooking = _MinimalTrialBooking(
          ref: trialSnap.docs.first.reference,
          sessionStartsAt: sessionStartsAt,
        ) as Booking?;

        // Actually let's just keep track of what we need.
        final trialRef = trialSnap.docs.first.reference;
        final trialStartsAt = sessionStartsAt;

        // ── Step 3: atomic user update ────────────────────────────────────
        await _db.runTransaction((tx) async {
          final freshSnap = await tx.get(userRef);
          final freshData = freshSnap.data()!;

          final int initialBooked =
              trialStartsAt.isAfter(now) ? 1 : 0; // future → booked
          final int initialAttended =
              trialStartsAt.isAfter(now) ? 0 : 1; // past → attended

          final newPromo = {
            'packageId': package.id,
            'packageName': package.name,
            'totalSessions': package.numberOfSessions,
            'booked': initialBooked,
            'attended': initialAttended,
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

          final updates = <String, dynamic>{
            'promotions': existing,
            'trialSessionUsed': false,
          };
          if (freshData['promotion'] != null) {
            updates['promotion'] = FieldValue.delete();
          }
          tx.update(userRef, updates);
        });

        // ── Step 4: link the trial booking to the new promotion ───────────
        // Now the cancel logic will route refunds via promotionCreatedAt.
        await trialRef.update({'promotionCreatedAt': promoCreatedAt});
        return;
      }
    }

    // ── No trial to absorb: standard assignment ───────────────────────────
    await _db.runTransaction((tx) async {
      final freshSnap = await tx.get(userRef);
      final freshData = freshSnap.data()!;

      final newPromo = {
        'packageId': package.id,
        'packageName': package.name,
        'totalSessions': package.numberOfSessions,
        'booked': 0,
        'attended': 0,
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
      // If trialSessionUsed was true but no active booking found
      // (session was in the past and already attended), absorb via attended.
      if (trialSessionUsed) {
        // Bump the just-added promo's attended count.
        final idx = existing.length - 1;
        (existing[idx] as Map<String, dynamic>)['attended'] = 1;
        updates['promotions'] = existing;
        updates['trialSessionUsed'] = false;
      }
      tx.update(userRef, updates);
    });
  }
}

/// Tiny helper — not a real Booking, just carries what we need.
class _MinimalTrialBooking {
  final DocumentReference ref;
  final DateTime sessionStartsAt;
  _MinimalTrialBooking({required this.ref, required this.sessionStartsAt});
}