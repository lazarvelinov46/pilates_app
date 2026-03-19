import 'package:cloud_firestore/cloud_firestore.dart';
import 'promotion_model.dart';
import 'user_preferences_model.dart';

enum UserRole { user, admin }

class AppUser {
  final String uid;
  final UserRole role;
  final String name;
  final String surname;
  final String email;
  final DateTime createdAt;
  final List<Promotion> promotions;
  final List<Promotion> promotionHistory;
  final UserPreferences preferences;

  /// True when the user has consumed their one free trial booking slot
  /// and it hasn't yet been absorbed by a promotion.
  final bool trialSessionUsed;

  AppUser({
    required this.uid,
    required this.role,
    required this.name,
    required this.surname,
    required this.email,
    required this.createdAt,
    this.promotions = const [],
    this.promotionHistory = const [],
    required this.preferences,
    this.trialSessionUsed = false,
  });

  List<Promotion> get activePromotions {
    final active = promotions.where((p) => p.canBook()).toList();
    active.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return active;
  }

  List<Promotion> get sortedPromotions {
    final sorted = [...promotions];
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  bool get hasActivePromotion => activePromotions.isNotEmpty;

  /// User can book a trial session: no active promotion and trial not yet used.
  bool get canBookTrial => !hasActivePromotion && !trialSessionUsed;

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<Promotion> promotions = [];
    if (data['promotions'] != null) {
      final raw = data['promotions'] as List<dynamic>;
      promotions =
          raw.map((e) => Promotion.fromMap(e as Map<String, dynamic>)).toList();
    } else if (data['promotion'] != null) {
      promotions = [
        Promotion.fromMap(data['promotion'] as Map<String, dynamic>)
      ];
    }

    final historyRaw = data['promotionHistory'] as List<dynamic>? ?? [];

    return AppUser(
      uid: doc.id,
      role: data['role'] == 'admin' ? UserRole.admin : UserRole.user,
      name: data['name'] ?? '',
      surname: data['surname'] ?? '',
      email: data['email'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      promotions: promotions,
      promotionHistory: historyRaw
          .map((e) => Promotion.fromMap(e as Map<String, dynamic>))
          .toList(),
      preferences: UserPreferences.fromMap(data['preferences'] ?? {}),
      trialSessionUsed: data['trialSessionUsed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role.name,
      'name': name,
      'surname': surname,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'promotions': promotions.map((p) => p.toMap()).toList(),
      'promotionHistory': promotionHistory.map((p) => p.toMap()).toList(),
      'preferences': preferences.toMap(),
      'trialSessionUsed': trialSessionUsed,
    };
  }
}