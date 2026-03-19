import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/package_model.dart';
import '../models/user_model.dart';
import '../models/user_preferences_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  Stream<AppUser> getUserStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snap) => AppUser.fromFirestore(snap));
  }

  Future<void> updatePreferences(
      String userId, UserPreferences preferences) async {
    await _db.collection('users').doc(userId).update({
      'preferences': preferences.toMap(),
    });
  }

  Future<void> assignPromotionFromPackage({
    required String userId,
    required Package package,
    required DateTime expiresAt,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final now = DateTime.now();
    final promoCreatedAt = Timestamp.fromDate(now);

    // Read user to check trial state before opening the transaction.
    final userSnap = await userRef.get();
    final data = userSnap.data()!;
    final trialSessionUsed = data['trialSessionUsed'] as bool? ?? false;

    // Locate the active trial booking outside the transaction (query needed).
    DocumentReference? trialBookingRef;
    bool trialSessionIsFuture = false;

    if (trialSessionUsed) {
      final trialSnap = await _db
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('isTrialBooking', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (trialSnap.docs.isNotEmpty) {
        trialBookingRef = trialSnap.docs.first.reference;
        final sessionStartsAt =
            (trialSnap.docs.first.data()['sessionStartsAt'] as Timestamp)
                .toDate();
        trialSessionIsFuture = sessionStartsAt.isAfter(now);
      }
    }

    // Determine initial usage counts for the new promotion.
    final int initialBooked = (trialSessionUsed && trialSessionIsFuture) ? 1 : 0;
    final int initialAttended =
        (trialSessionUsed && !trialSessionIsFuture && trialBookingRef != null)
            ? 1
            : 0;
    // Edge case: trialSessionUsed but no active booking found means the trial
    // session is already completed/past → count as attended=1.
    final int attendedFallback =
        (trialSessionUsed && trialBookingRef == null) ? 1 : initialAttended;

    await _db.runTransaction((tx) async {
      final freshSnap = await tx.get(userRef);
      final freshData = freshSnap.data()!;

      final newPromo = {
        'packageId': package.id,
        'packageName': package.name,
        'totalSessions': package.numberOfSessions,
        'booked': initialBooked,
        'attended': trialBookingRef != null ? initialAttended : attendedFallback,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': promoCreatedAt,
      };

      List<dynamic> existing = [];
      if (freshData['promotions'] != null) {
        existing = List<dynamic>.from(freshData['promotions'] as List);
      } else if (freshData['promotion'] != null) {
        existing = [freshData['promotion']];
      }
      existing.add(newPromo);

      final updates = <String, dynamic>{'promotions': existing};
      if (freshData['promotion'] != null) {
        updates['promotion'] = FieldValue.delete();
      }
      if (trialSessionUsed) {
        updates['trialSessionUsed'] = false;
      }
      tx.update(userRef, updates);
    });

    // After the transaction: link the trial booking to the new promotion so
    // that any future cancellation uses the normal refund path.
    if (trialBookingRef != null) {
      await trialBookingRef.update({'promotionCreatedAt': promoCreatedAt});
    }
  }
}