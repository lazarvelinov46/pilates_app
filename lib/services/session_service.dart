import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';

class SessionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get all active sessions for a specific day (one-shot fetch).
  Future<List<Session>> getSessionsForDate(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snap = await _db
        .collection('sessions')
        .where('active', isEqualTo: true)
        .where('startsAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startsAt', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('startsAt')
        .get();

    final now = DateTime.now(); // ← add this

    return snap.docs
        .where((d) => d.data()['startsAt'] != null)
        .map((d) => Session.fromFirestore(d))
        .where((s) => s.startsAt.isAfter(now)) // ← add this
        .toList();
  }

  /// Real-time stream of active sessions for [day].
  /// Automatically reflects capacity changes as other users book/cancel.
  Stream<List<Session>> streamSessionsForDate(DateTime day) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db
        .collection('sessions')
        .where('active', isEqualTo: true)
        .where('startsAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startsAt', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('startsAt')
        .snapshots()
        .map((snap) {
          final now = DateTime.now(); // ← add this
          return snap.docs
              .where((d) => d.data()['startsAt'] != null)
              .map((d) => Session.fromFirestore(d))
              .where((s) => s.startsAt.isAfter(now)) // ← add this
              .toList();
        });
  }

  /// Get all sessions in a date range (for calendar dots).
  Future<List<Session>> getSessionsInRange(
    DateTime from,
    DateTime to,
  ) async {
    final snap = await _db
        .collection('sessions')
        .where('active', isEqualTo: true)
        .where(
          'startsAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from),
        )
        .where(
          'startsAt',
          isLessThanOrEqualTo: Timestamp.fromDate(to),
        )
        .get();

    return snap.docs.map(Session.fromFirestore).toList();
  }

  /// Get the next [limit] upcoming sessions that aren't full.
  /// Used for the quick-booking section on the Home screen.
  Future<List<Session>> getUpcomingSessions({int limit = 3}) async {
    final now = DateTime.now();

    final snap = await _db
        .collection('sessions')
        .where('active', isEqualTo: true)
        .where('startsAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('startsAt')
        .limit(limit * 3) // fetch more so we can filter full sessions client-side
        .get();

    final sessions = snap.docs
        .where((d) => d.data()['startsAt'] != null)
        .map((d) => Session.fromFirestore(d))
        .where((s) => s.bookedCount < s.capacity)
        .take(limit)
        .toList();

    return sessions;
  }

  Future<void> createSession({
    required DateTime startsAt,
    required DateTime endsAt,
    required int capacity,
  }) async {
    // Fetch all active sessions on the same day and check for overlap.
    final startOfDay = DateTime(startsAt.year, startsAt.month, startsAt.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snap = await _db
        .collection('sessions')
        .where('active', isEqualTo: true)
        .where('startsAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startsAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final hasOverlap = snap.docs.any((doc) {
      final existingStart = (doc['startsAt'] as Timestamp).toDate();
      final existingEnd = (doc['endsAt'] as Timestamp).toDate();
      // Two intervals [a,b) and [c,d) overlap when a < d && c < b.
      return startsAt.isBefore(existingEnd) && existingStart.isBefore(endsAt);
    });

    if (hasOverlap) {
      throw Exception('This time slot overlaps with an existing session.');
    }

    await _db.collection('sessions').add({
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'capacity': capacity,
      'bookedCount': 0,
      'active': true,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updateSession({
    required String sessionId,
    required DateTime startsAt,
    required int capacity,
  }) async {
    await _db.collection('sessions').doc(sessionId).update({
      'startsAt': Timestamp.fromDate(startsAt),
      'capacity': capacity,
    });
  }

  Future<void> deactivateSession(String sessionId) async {
    await _db.collection('sessions').doc(sessionId).update({
      'active': false,
    });
  }

  /// Cancels a session as admin: marks every active booking as
  /// cancelled_by_admin, refunds the credit back to the correct promotion
  /// (checking both active promotions and promotionHistory), then deactivates
  /// the session. Runs entirely client-side — no Cloud Function needed.
  Future<void> cancelSessionByAdmin(String sessionId) async {
    final bookingsSnap = await _db
        .collection('bookings')
        .where('sessionId', isEqualTo: sessionId)
        .where('status', isEqualTo: 'active')
        .get();

    for (final bookingDoc in bookingsSnap.docs) {
      final bookingData = bookingDoc.data();
      final userId = bookingData['userId'] as String;
      final userRef = _db.collection('users').doc(userId);
      final isTrialBooking = bookingData['isTrialBooking'] == true;
      final promoCreatedAt = bookingData['promotionCreatedAt'] as Timestamp?;

      await _db.runTransaction((tx) async {
        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) return;

        final userData = userSnap.data()!;

        tx.update(bookingDoc.reference, {
          'status': 'cancelled_by_admin',
          'cancelledAt': Timestamp.fromDate(DateTime.now()),
          'cancelledByAdmin': true,
        });

        // Trial booking not yet absorbed by a promotion.
        if (isTrialBooking && promoCreatedAt == null) {
          tx.update(userRef, {'trialSessionUsed': false});
          return;
        }

        if (promoCreatedAt != null) {
          final targetMs = promoCreatedAt.millisecondsSinceEpoch;

          // First look in the active promotions array.
          if (userData['promotions'] != null) {
            final promos = (userData['promotions'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

            final idx = promos.indexWhere((p) =>
                p['createdAt'] is Timestamp &&
                (p['createdAt'] as Timestamp).millisecondsSinceEpoch ==
                    targetMs);

            if (idx != -1) {
              final current = (promos[idx]['booked'] as int? ?? 0);
              promos[idx] = {
                ...promos[idx],
                'booked': (current - 1).clamp(0, 999),
              };
              tx.update(userRef, {'promotions': promos});
              return;
            }
          }

          // Not in active promotions — check promotionHistory (can happen when
          // a promotion is expired & fully booked/attended, so it gets archived
          // by syncAttendedSessions even while a future session is still booked).
          if (userData['promotionHistory'] != null) {
            final history = (userData['promotionHistory'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

            final idx = history.indexWhere((p) =>
                p['createdAt'] is Timestamp &&
                (p['createdAt'] as Timestamp).millisecondsSinceEpoch ==
                    targetMs);

            if (idx != -1) {
              final current = (history[idx]['booked'] as int? ?? 0);
              final restored = {
                ...history[idx],
                'booked': (current - 1).clamp(0, 999),
              };
              history.removeAt(idx);

              final activePromos = userData['promotions'] != null
                  ? (userData['promotions'] as List)
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .toList()
                  : <Map<String, dynamic>>[];
              activePromos.add(restored);

              tx.update(userRef, {
                'promotions': activePromos,
                'promotionHistory': history,
              });
              return;
            }
          }
        } else if (userData['promotion'] != null && !isTrialBooking) {
          // Legacy single-field path.
          tx.update(userRef, {
            'promotion.booked': FieldValue.increment(-1),
          });
        }
      });
    }

    await _db.collection('sessions').doc(sessionId).update({'active': false});
  }

  Future<Set<DateTime>> getAvailableSessionDates() async {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 365));

    final snap = await FirebaseFirestore.instance
        .collection('sessions')
        .where('startsAt', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('startsAt', isLessThan: Timestamp.fromDate(end))
        .where('active', isEqualTo: true)
        .get();

    return snap.docs.map((doc) {
      final date = (doc['startsAt'] as Timestamp).toDate();
      return DateTime(date.year, date.month, date.day);
    }).toSet();
  }
}