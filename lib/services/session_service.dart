import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';

class SessionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get all active sessions for a specific day
  Future<List<Session>> getSessionsForDate(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snap = await _db
        .collection('sessions')
        .where('active', isEqualTo: true)
        .where(
          'startsAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where(
          'startsAt',
          isLessThan: Timestamp.fromDate(endOfDay),
        )
        .orderBy('startsAt')
        .get();

    return snap.docs.map(Session.fromFirestore).toList();
  }

  /// Get all sessions in a date range (for calendar dots)
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

  Future<void> createSession({
    required DateTime startsAt,
    required int capacity,
  }) async {
    await _db.collection('sessions').add({
      'startsAt': Timestamp.fromDate(startsAt),
      'capacity': capacity,
      'bookedCount': 0,
      'active': true,
      'createdAt': Timestamp.now(),
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


}
