import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

class BookingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------- BOOK SESSION ----------------

  Future<void> bookSession({
    required String userId,
    required String sessionId,
  }) async {
    final sessionRef = _db.collection('sessions').doc(sessionId);
    final userRef = _db.collection('users').doc(userId);
    final bookingsRef = _db.collection('bookings');

    await _db.runTransaction((tx) async {
      final sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) {
        throw Exception('Session does not exist');
      }

      final sessionData = sessionSnap.data()!;
      if (sessionData['active'] != true) {
        throw Exception('Session inactive');
      }

      final int capacity = sessionData['capacity'];
      final int bookedCount = sessionData['bookedCount'];

      if (bookedCount >= capacity) {
        throw Exception('Session full');
      }

      // Check duplicate booking
      final existing = await bookingsRef
          .where('userId', isEqualTo: userId)
          .where('sessionId', isEqualTo: sessionId)
          .where('status', isEqualTo: 'active')
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception('Already booked');
      }

      final bookingRef = bookingsRef.doc();

      tx.set(bookingRef, {
        'userId': userId,
        'sessionId': sessionId,
        'sessionStartsAt': sessionData['startsAt'],
        'createdAt': Timestamp.now(),
        'status': 'active',
      });

      tx.update(sessionRef, {
        'bookedCount': bookedCount + 1,
      });

      tx.update(userRef, {
        'promotion.booked': FieldValue.increment(1),
      });
    });
  }

  // ---------------- CANCEL BOOKING ----------------

  Future<void> cancelBooking({
    required Booking booking,
  }) async {
    final bookingRef = _db.collection('bookings').doc(booking.id);
    final sessionRef = _db.collection('sessions').doc(booking.sessionId);
    final userRef = _db.collection('users').doc(booking.userId);

    await _db.runTransaction((tx) async {
      final bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) {
        throw Exception('Booking not found');
      }

      final bookingData = bookingSnap.data()!;
      if (bookingData['status'] != 'active') {
        throw Exception('Already cancelled');
      }

      final sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) {
        throw Exception('Session missing');
      }

      final int bookedCount = sessionSnap['bookedCount'];

      tx.update(bookingRef, {
        'status': 'cancelled',
        'cancelledAt': Timestamp.now(),
      });

      tx.update(sessionRef, {
        'bookedCount': bookedCount > 0 ? bookedCount - 1 : 0,
      });

      // Refund only if allowed
      if (booking.canCancel()) {
        tx.update(userRef, {
          'promotion.booked': FieldValue.increment(-1),
        });
      }
    });
  }

  
  Future<Set<String>> getUserActiveBookings(String userId) async {
  final snap = await _db
      .collection('bookings')
      .where('userId', isEqualTo: userId)
      .where('status', isEqualTo: 'active')
      .get();

  return snap.docs
      .map((d) => d['sessionId'] as String)
      .toSet();
  }

  Future<List<Booking>> getActiveBookingsForUser(String userId) async {
  final snap = await _db
      .collection('bookings')
      .where('userId', isEqualTo: userId)
      .where('status', isEqualTo: 'active')
      .orderBy('startsAt')
      .get();

  return snap.docs
      .map((d) => Booking.fromFirestore(d))
      .toList();
}


}
