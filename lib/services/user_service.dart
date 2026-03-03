import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/package_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------- SEARCH USERS BY EMAIL (role == 'user' only) ----------------
  // Requires a Firestore composite index on: role ASC, email ASC
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String query) async {
    if (query.trim().isEmpty) return [];

    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'user')
        .where('email', isGreaterThanOrEqualTo: query.trim())
        .where('email', isLessThanOrEqualTo: '${query.trim()}\uf8ff')
        .limit(20)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'email': data['email'] ?? '',
        'name': data['name'] ?? '',
        'surname': data['surname'] ?? '',
      };
    }).toList();
  }

  // ---------------- ASSIGN PROMOTION FROM PACKAGE ----------------
  // Stores a snapshot of the package at assignment time.
  // Future edits or deletion of the package do NOT affect this promotion.
  Future<void> assignPromotionFromPackage({
    required String userId,
    required Package package,
    required DateTime expiresAt,
  }) async {
    await _db.collection('users').doc(userId).update({
      'promotion': {
        'packageId': package.id,
        'packageName': package.name,
        'totalSessions': package.numberOfSessions,
        'booked': 0,
        'attended': 0,
        'expiresAt': Timestamp.fromDate(expiresAt),
      },
    });
  }
}