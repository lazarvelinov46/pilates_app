import 'package:cloud_firestore/cloud_firestore.dart';

class SessionRating {
  final String id;
  final String sessionId;
  final String bookingId;
  final String userId;
  final String userName;
  final String userEmail;
  final int rating; // 1–5
  final String comment;
  final DateTime sessionStartsAt;
  final DateTime createdAt;

  SessionRating({
    required this.id,
    required this.sessionId,
    required this.bookingId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.rating,
    required this.comment,
    required this.sessionStartsAt,
    required this.createdAt,
  });

  factory SessionRating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionRating(
      id: doc.id,
      sessionId: data['sessionId'] ?? '',
      bookingId: data['bookingId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      rating: data['rating'] ?? 0,
      comment: data['comment'] ?? '',
      sessionStartsAt: (data['sessionStartsAt'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'sessionId': sessionId,
        'bookingId': bookingId,
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'rating': rating,
        'comment': comment,
        'sessionStartsAt': Timestamp.fromDate(sessionStartsAt),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}