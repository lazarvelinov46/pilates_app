import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/package_model.dart';
import '../models/user_model.dart';
import '../models/user_preferences_model.dart';

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

  // ---------------- REAL-TIME USER STREAM ----------------
  Stream<AppUser> getUserStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snap) => AppUser.fromFirestore(snap));
  }

  // ---------------- UPDATE PREFERENCES ----------------
  Future<void> updatePreferences(
      String userId, UserPreferences preferences) async {
    await _db.collection('users').doc(userId).update({
      'preferences': preferences.toMap(),
    });
  }

  // ---------------- ASSIGN PROMOTION FROM PACKAGE ----------------
  // Appends a new promotion to the user's `promotions` array.
  // Multiple active promotions are allowed; bookings always consume
  // the oldest one first.
  // Also handles one-time migration of legacy single `promotion` field.
  Future<void> assignPromotionFromPackage({
    required String userId,
    required Package package,
    required DateTime expiresAt,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final now = DateTime.now();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data()!;

      final newPromo = {
        'packageId': package.id,
        'packageName': package.name,
        'totalSessions': package.numberOfSessions,
        'booked': 0,
        'attended': 0,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': Timestamp.fromDate(now),
      };

      // Build the updated promotions array, migrating the legacy field if present.
      List<dynamic> existing = [];
      if (data['promotions'] != null) {
        existing = List<dynamic>.from(data['promotions'] as List);
      } else if (data['promotion'] != null) {
        // One-time migration: carry the old single promotion forward.
        existing = [data['promotion']];
      }
      existing.add(newPromo);

      final updates = <String, dynamic>{'promotions': existing};

      // Clean up the legacy field if it still exists.
      if (data['promotion'] != null) {
        updates['promotion'] = FieldValue.delete();
      }

      tx.update(userRef, updates);
    });
  }
}