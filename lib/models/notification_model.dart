import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { bookingConfirmed, sessionReminder, sessionCancelled }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final NotificationType type;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.type = NotificationType.bookingConfirmed,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      type: _typeFromString(data['type'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      type: type,
    );
  }

  static NotificationType _typeFromString(String value) {
    switch (value) {
      case 'sessionReminder':
        return NotificationType.sessionReminder;
      case 'sessionCancelled':
        return NotificationType.sessionCancelled;
      default:
        return NotificationType.bookingConfirmed;
    }
  }
}
