

class UserPreferences {
  final String language;
  final bool notifications;

  UserPreferences({
    required this.language,
    required this.notifications,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      language: map['language'] ?? 'en',
      notifications: map['notifications'] ?? true,
    );
  }
  factory UserPreferences.defaultPreferences() {
    return UserPreferences(
      language: 'en',
      notifications: true
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'language': language,
      'notifications': notifications,
    };
  }
}
