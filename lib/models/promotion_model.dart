import 'package:cloud_firestore/cloud_firestore.dart';

class Promotion {
  // Snapshot of package info at the time of creation.
  // Changes to the original package do NOT affect this promotion.
  final String packageId;
  final String packageName;
  final int totalSessions;

  final int attended;
  final int booked;
  final DateTime expiresAt;

  /// Unique identifier for this promotion within the user's promotions array.
  /// Used to route booking charges and refunds to the correct entry.
  final DateTime createdAt;

  Promotion({
    required this.packageId,
    required this.packageName,
    required this.totalSessions,
    required this.attended,
    required this.booked,
    required this.expiresAt,
    required this.createdAt,
  });

  int get remaining => totalSessions - attended - booked;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool canBook() => !isExpired && remaining > 0;

  factory Promotion.fromMap(Map<String, dynamic> map) {
    return Promotion(
      packageId: map['packageId'] ?? '',
      packageName: map['packageName'] ?? '',
      totalSessions: map['totalSessions'] ?? 0,
      attended: map['attended'] ?? 0,
      booked: map['booked'] ?? 0,
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      // Fallback for legacy promotions that pre-date multi-promotion support.
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime(2000),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageId': packageId,
      'packageName': packageName,
      'totalSessions': totalSessions,
      'attended': attended,
      'booked': booked,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}