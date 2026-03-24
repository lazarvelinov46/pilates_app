import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

class BookingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------- BOOK SESSION ----------------
  // Charges the oldest bookable promotion (earliest createdAt).
  // Stores `promotionCreatedAt` on the booking for precise refund routing.

  Future<void> bookSession({
    required String userId,
    required String sessionId,
  }) async {
    final sessionRef = _db.collection('sessions').doc(sessionId);
    final userRef = _db.collection('users').doc(userId);
    final bookingsRef = _db.collection('bookings');

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final userData = userSnap.data()!;

      // ── Load promotions (supports both new array and legacy single field) ──
      List<Map<String, dynamic>> promosRaw = [];
      if (userData['promotions'] != null) {
        promosRaw = (userData['promotions'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (userData['promotion'] != null) {
        promosRaw = [
          Map<String, dynamic>.from(userData['promotion'] as Map)
        ];
      }

      // Sort oldest-first.
      promosRaw.sort((a, b) {
        final aMs = a['createdAt'] != null
            ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch
            : 0;
        final bMs = b['createdAt'] != null
            ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch
            : 0;
        return aMs.compareTo(bMs);
      });

      // Find the first bookable promotion.
      int? targetIdx;
      for (int i = 0; i < promosRaw.length; i++) {
        final p = promosRaw[i];
        final expiresAt = (p['expiresAt'] as Timestamp).toDate();
        final total = p['totalSessions'] as int;
        final booked = p['booked'] as int;
        final attended = p['attended'] as int;
        if (!DateTime.now().isAfter(expiresAt) &&
            total - booked - attended > 0) {
          targetIdx = i;
          break;
        }
      }

      // ── Session validation ───────────────────────────────────────────────
      final sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) throw Exception('Session does not exist');

      final sessionData = sessionSnap.data()!;
      if (sessionData['active'] != true) {
        throw Exception('Session is no longer active');
      }

      final int capacity = sessionData['capacity'];
      final int bookedCount = sessionData['bookedCount'];
      if (bookedCount >= capacity) throw Exception('Session is full');

      // Duplicate-booking guard.
      final existing = await bookingsRef
          .where('userId', isEqualTo: userId)
          .where('sessionId', isEqualTo: sessionId)
          .where('status', isEqualTo: 'active')
          .get();
      if (existing.docs.isNotEmpty) {
        throw Exception('You already booked this session');
      }

      final bookingRef = bookingsRef.doc();

      // ── TRIAL PATH: no bookable promotion found ──────────────────────────
      if (targetIdx == null) {
        final trialAlreadyUsed =
            userData['trialSessionUsed'] as bool? ?? false;
        if (trialAlreadyUsed) {
          throw Exception(
            'You have no active promotion and your free trial session '
            'has already been used.',
          );
        }

        tx.set(bookingRef, {
          'userId': userId,
          'sessionId': sessionId,
          'sessionStartsAt': sessionData['startsAt'],
          'createdAt': Timestamp.now(),
          'status': 'active',
          'reminderSent': false,
          'isTrialBooking': true,
          'attendanceRecorded': false,   // ← add this
          // No promotionCreatedAt — linked when promotion is assigned.
        });

        tx.update(sessionRef, {'bookedCount': bookedCount + 1});
        tx.update(userRef, {'trialSessionUsed': true});
        return;
      }

      // ── NORMAL PATH: charge the target promotion ─────────────────────────
      final targetPromo = promosRaw[targetIdx];
      final promoCreatedAt = targetPromo['createdAt'] as Timestamp?;

      promosRaw[targetIdx] = Map<String, dynamic>.from(targetPromo)
        ..['booked'] = (targetPromo['booked'] as int) + 1;

      tx.set(bookingRef, {
        'userId': userId,
        'sessionId': sessionId,
        'sessionStartsAt': sessionData['startsAt'],
        'createdAt': Timestamp.now(),
        'status': 'active',
        'reminderSent': false,
        'isTrialBooking': false,
        'attendanceRecorded': false,   // ← add this
        if (promoCreatedAt != null) 'promotionCreatedAt': promoCreatedAt,
      });

      tx.update(sessionRef, {'bookedCount': bookedCount + 1});

      final userUpdates = <String, dynamic>{'promotions': promosRaw};
      if (userData['promotion'] != null) {
        userUpdates['promotion'] = FieldValue.delete();
      }
      tx.update(userRef, userUpdates);
    });
  }

  // ---------------- CANCEL BOOKING ----------------
  // Refunds the credit to the exact promotion that was originally charged,
  // identified by `booking.promotionCreatedAt`.

  Future<void> cancelBooking({required Booking booking}) async {
    final bookingRef = _db.collection('bookings').doc(booking.id);
    final sessionRef = _db.collection('sessions').doc(booking.sessionId);
    final userRef = _db.collection('users').doc(booking.userId);

    await _db.runTransaction((tx) async {
      // ── ALL READS FIRST ──────────────────────────────────────────────────
      final bookingSnap = await tx.get(bookingRef);
      final sessionSnap = await tx.get(sessionRef);
      final userSnap = await tx.get(userRef);

      // ── VALIDATION ───────────────────────────────────────────────────────
      if (!bookingSnap.exists) throw Exception('Booking not found');

      final bookingData = bookingSnap.data()!;
      if (bookingData['status'] != 'active') {
        throw Exception('Booking is already cancelled');
      }

      if (!sessionSnap.exists) throw Exception('Session not found');

      // ── WRITES ───────────────────────────────────────────────────────────
      final int bookedCount = sessionSnap['bookedCount'];

      tx.update(bookingRef, {
        'status': 'cancelled',
        'cancelledAt': Timestamp.now(),
      });

      tx.update(sessionRef, {
        'bookedCount': bookedCount > 0 ? bookedCount - 1 : 0,
      });

      if (!booking.canCancel()) return;

      final userData = userSnap.data()!;

      // ── Trial booking, not yet absorbed by a promotion ───────────────────
      if (booking.isTrialBooking && booking.promotionCreatedAt == null) {
        tx.update(userRef, {'trialSessionUsed': false});
        return;
      }

      // ── Regular path (or trial already absorbed → has promotionCreatedAt) ─
      if (userData['promotions'] != null &&
          booking.promotionCreatedAt != null) {
        final promosRaw = (userData['promotions'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        final targetMs = booking.promotionCreatedAt!.millisecondsSinceEpoch;
        final idx = promosRaw.indexWhere((p) {
          if (p['createdAt'] == null) return false;
          return (p['createdAt'] as Timestamp).millisecondsSinceEpoch ==
              targetMs;
        });

        if (idx != -1) {
          final current = promosRaw[idx]['booked'] as int;
          promosRaw[idx] = Map<String, dynamic>.from(promosRaw[idx])
            ..['booked'] = current > 0 ? current - 1 : 0;
          tx.update(userRef, {'promotions': promosRaw});
        }
      } else if (!booking.isTrialBooking) {
        // Legacy single-field path.
        tx.update(userRef, {
          'promotion.booked': FieldValue.increment(-1),
        });
      }
    });
  }

  // ---------------- QUERIES ----------------

  /// One-shot fetch — returns session IDs with an active booking.
  Future<Set<String>> getUserActiveBookings(String userId) async {
    final snap = await _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();
    return snap.docs.map((d) => d['sessionId'] as String).toSet();
  }

  /// Real-time stream of session IDs that the user has an active booking for.
  /// The BookingScreen subscribes to this so the UI updates immediately when
  /// another device or the backend changes a booking's status.
  Stream<Set<String>> getUserActiveBookingsStream(String userId) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => d['sessionId'] as String).toSet());
  }

  Future<List<Booking>> getActiveBookingsForUser(String userId) async {
    final snap = await _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .orderBy('sessionStartsAt')
        .get();
    return snap.docs.map((d) => Booking.fromFirestore(d)).toList();
  }

  Stream<List<Booking>> getActiveBookingsForUserStream(String userId) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .orderBy('sessionStartsAt')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Booking.fromFirestore(d)).toList());
  }

  /// Returns only future bookings (session hasn't started yet).
  Stream<List<Booking>> getUpcomingBookingsStream(String userId) {
    final now = Timestamp.fromDate(DateTime.now());
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .where('sessionStartsAt', isGreaterThan: now)
        .orderBy('sessionStartsAt')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Booking.fromFirestore(d)).toList());
  }

  /// Past sessions the user attended (active bookings with sessionStartsAt < now).
  /// Requires a Firestore composite index:
  ///   Collection: bookings  |  userId ASC, status ASC, sessionStartsAt DESC
  Future<List<Booking>> getCompletedBookingsForUser(String userId) async {
    final now = Timestamp.fromDate(DateTime.now());
    final snap = await _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .where('sessionStartsAt', isLessThan: now)
        .orderBy('sessionStartsAt', descending: true)
        .get();
    return snap.docs.map((d) => Booking.fromFirestore(d)).toList();
  }

  /// Future bookings the admin cancelled — shown as "Cancelled by Studio" in UI.
  /// Requires a composite Firestore index:
  ///   Collection: bookings | userId ASC, status ASC, sessionStartsAt ASC
  Stream<List<Booking>> getAdminCancelledUpcomingStream(String userId) {
    final now = Timestamp.fromDate(DateTime.now());
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'cancelled_by_admin')
        .where('sessionStartsAt', isGreaterThan: now)
        .orderBy('sessionStartsAt')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Booking.fromFirestore(d)).toList());
  }

  /// Real-time stream of all active bookings for a specific session.
  /// Used by the admin attendees screen to show who has booked a session.
  Stream<List<Booking>> getBookingsForSession(String sessionId) {
    return _db
        .collection('bookings')
        .where('sessionId', isEqualTo: sessionId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Booking.fromFirestore(d)).toList());
  }
}