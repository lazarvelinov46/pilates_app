import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------- ASSIGN PROMOTION (ADMIN ONLY) ----------------
  Future<void> assignPromotion({
    required String userId,
    required int total,
    required DateTime expiresAt,
  }) async {
    await _db.collection('users').doc(userId).update({
      'promotion': {
        'total': total,
        'booked': 0,
        'attended': 0,
        'expiresAt': Timestamp.fromDate(expiresAt),
      },
    });
  }
}
