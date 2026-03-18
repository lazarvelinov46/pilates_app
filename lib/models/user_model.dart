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

  /// All promotions assigned to this user (active, exhausted, and expired).
  /// Replaces the old single `promotion` field.
  final List<Promotion> promotions;

  /// Legacy archive of promotions that were replaced before multi-promotion
  /// support was added. Still shown in profile history.
  final List<Promotion> promotionHistory;

  final UserPreferences preferences;

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
  });

  /// Promotions that still have sessions remaining and haven't expired,
  /// sorted oldest first (so bookings consume the oldest promotion first).
  List<Promotion> get activePromotions {
    final active = promotions.where((p) => p.canBook()).toList();
    active.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return active;
  }

  /// All promotions sorted oldest first (for display on home screen).
  List<Promotion> get sortedPromotions {
    final sorted = [...promotions];
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  /// Whether the user has at least one bookable promotion.
  bool get hasActivePromotion => activePromotions.isNotEmpty;

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // ── Migration: support both old single `promotion` field and new array ──
    List<Promotion> promotions = [];
    if (data['promotions'] != null) {
      final raw = data['promotions'] as List<dynamic>;
      promotions =
          raw.map((e) => Promotion.fromMap(e as Map<String, dynamic>)).toList();
    } else if (data['promotion'] != null) {
      // Legacy: migrate single promotion into a one-item list.
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
    };
  }
}