import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating_model.dart';

class RatingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Doc ID encodes userId+sessionId — enforces one rating per user per session.
  String _docId(String userId, String sessionId) => '${userId}_$sessionId';

  Future<void> submitRating({
    required String sessionId,
    required String bookingId,
    required String userId,
    required String userName,
    required String userEmail,
    required int rating,
    required String comment,
    required DateTime sessionStartsAt,
  }) async {
    await _db
        .collection('ratings')
        .doc(_docId(userId, sessionId))
        .set({
      'sessionId': sessionId,
      'bookingId': bookingId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'rating': rating,
      'comment': comment,
      'sessionStartsAt': Timestamp.fromDate(sessionStartsAt),
      'createdAt': Timestamp.now(),
    });
  }

  /// Returns a map of sessionId → SessionRating for the given user.
  Future<Map<String, SessionRating>> getUserRatingsMap(
      String userId) async {
    final snap = await _db
        .collection('ratings')
        .where('userId', isEqualTo: userId)
        .get();
    return {
      for (final doc in snap.docs)
        (doc.data()['sessionId'] as String): SessionRating.fromFirestore(doc),
    };
  }

  /// Admin stream — all ratings, newest first.
  Stream<List<SessionRating>> streamAllRatings() {
    return _db
        .collection('ratings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(SessionRating.fromFirestore).toList());
  }
}