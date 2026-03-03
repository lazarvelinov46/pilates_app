import 'package:cloud_firestore/cloud_firestore.dart';

class Package {
  final String id;
  final String name;
  final int numberOfSessions;

  Package({
    required this.id,
    required this.name,
    required this.numberOfSessions,
  });

  factory Package.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Package(
      id: doc.id,
      name: data['name'] ?? '',
      numberOfSessions: data['numberOfSessions'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'numberOfSessions': numberOfSessions,
    };
  }
}