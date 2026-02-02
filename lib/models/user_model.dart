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

  final Promotion? promotion;
  final UserPreferences preferences;

  AppUser({
    required this.uid,
    required this.role,
    required this.name,
    required this.surname,
    required this.email,
    required this.createdAt,
    this.promotion,
    required this.preferences,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AppUser(
      uid: doc.id,
      role: data['role'] == 'admin' ? UserRole.admin : UserRole.user,
      name: data['name'] ?? '',
      surname: data['surname'] ?? '',
      email: data['email'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      promotion: data['promotion'] != null
          ? Promotion.fromMap(data['promotion'])
          : null,
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
      'promotion': promotion?.toMap(),
      'preferences': preferences.toMap(),
    };
  }
}
