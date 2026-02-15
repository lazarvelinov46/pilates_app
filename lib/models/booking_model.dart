import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum BookingStatus { active, cancelled }

class Booking {
  final String id;
  final String userId;
  final String sessionId;
  final DateTime sessionStartsAt;
  final DateTime createdAt;
  final BookingStatus status;
  final bool reminderSent; 

  Booking({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.sessionStartsAt,
    required this.createdAt,
    required this.status,
    required this.reminderSent,
  });

  String get formattedDateTime {
    return DateFormat('EEE, dd MMM • HH:mm').format(sessionStartsAt);
  }

  bool canCancel() {
    final now = DateTime.now();
    return status == BookingStatus.active &&
        sessionStartsAt.difference(now).inHours >= 12;
  }

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Booking(
      id: doc.id,
      userId: data['userId'],
      sessionId: data['sessionId'],
      sessionStartsAt:
          (data['sessionStartsAt'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: data['status'] == 'cancelled'
          ? BookingStatus.cancelled
          : BookingStatus.active,
      reminderSent: data['reminderSent'] ?? false
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'sessionId': sessionId,
      'sessionStartsAt':
          Timestamp.fromDate(sessionStartsAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name,
      'reminderSent': reminderSent
    };
  }
}
