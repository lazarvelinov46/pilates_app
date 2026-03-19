import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum BookingStatus { active, cancelled, cancelledByAdmin }

class Booking {
  final String id;
  final String userId;
  final String sessionId;
  final DateTime sessionStartsAt;
  final DateTime createdAt;
  final BookingStatus status;
  final bool reminderSent;

  /// The `createdAt` of the promotion that was charged for this booking.
  /// Used to route refunds to the correct promotion on cancellation.
  /// Null for bookings created before multi-promotion support.
  final DateTime? promotionCreatedAt;

  /// True when this booking was made without an active promotion (trial slot).
  final bool isTrialBooking;

  Booking({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.sessionStartsAt,
    required this.createdAt,
    required this.status,
    required this.reminderSent,
    this.promotionCreatedAt,
    this.isTrialBooking = false,
  });

  String get formattedDateTime {
    return DateFormat('EEE, dd MMM • HH:mm').format(sessionStartsAt);
  }

  bool canCancel() {
    return status == BookingStatus.active &&
        sessionStartsAt.difference(DateTime.now()).inHours >= 12;
  }

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    BookingStatus status;
    switch (data['status']) {
      case 'cancelled_by_admin':
        status = BookingStatus.cancelledByAdmin;
        break;
      case 'cancelled':
        status = BookingStatus.cancelled;
        break;
      default:
        status = BookingStatus.active;
    }

    return Booking(
      id: doc.id,
      userId: data['userId'],
      sessionId: data['sessionId'],
      sessionStartsAt: (data['sessionStartsAt'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: status,
      reminderSent: data['reminderSent'] ?? false,
      promotionCreatedAt: data['promotionCreatedAt'] != null
          ? (data['promotionCreatedAt'] as Timestamp).toDate()
          : null,
      isTrialBooking: data['isTrialBooking'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    String statusStr;
    switch (status) {
      case BookingStatus.cancelledByAdmin:
        statusStr = 'cancelled_by_admin';
        break;
      case BookingStatus.cancelled:
        statusStr = 'cancelled';
        break;
      default:
        statusStr = 'active';
    }

    return {
      'userId': userId,
      'sessionId': sessionId,
      'sessionStartsAt': Timestamp.fromDate(sessionStartsAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': statusStr,
      'reminderSent': reminderSent,
      'isTrialBooking': isTrialBooking,
      if (promotionCreatedAt != null)
        'promotionCreatedAt': Timestamp.fromDate(promotionCreatedAt!),
    };
  }
}