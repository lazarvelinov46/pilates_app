import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final int capacity;
  final int bookedCount;
  final bool active;
  final DateTime createdAt;

  Session({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    required this.bookedCount,
    required this.active,
    required this.createdAt,
  });

  bool get isFull => bookedCount >= capacity;

  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Session ${doc.id} has no data');
    }

    final startsTimestamp = data['startsAt'];
    final endsTimestamp = data['endsAt'];

    if (startsTimestamp == null || startsTimestamp is! Timestamp) {
      throw Exception('Session ${doc.id} has invalid startsAt');
    }

    DateTime startsAt = startsTimestamp.toDate();

    DateTime endsAt;

    if (endsTimestamp != null && endsTimestamp is Timestamp) {
      endsAt = endsTimestamp.toDate();
    } else {
      // Fallback: if endsAt missing, auto-calculate
      endsAt = startsAt.add(const Duration(hours: 1));
    }

    return Session(
      id: doc.id,
      startsAt: startsAt,
      endsAt: endsAt,
      capacity: data['capacity'],
      bookedCount: data['bookedCount'],
      active: data['active'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'capacity': capacity,
      'bookedCount': bookedCount,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
