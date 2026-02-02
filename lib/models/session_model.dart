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
    final data = doc.data() as Map<String, dynamic>;

    return Session(
      id: doc.id,
      startsAt: (data['startsAt'] as Timestamp).toDate(),
      endsAt: (data['endsAt'] as Timestamp).toDate(),
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
