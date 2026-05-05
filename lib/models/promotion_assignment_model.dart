import 'package:cloud_firestore/cloud_firestore.dart';

class PromotionAssignment {
  final String id;
  final String assignedByUid;
  final String assignedByName;
  final String packageId;
  final String packageName;
  final int numberOfSessions;
  final String targetUserId;
  final String targetUserName;
  final String targetUserEmail;
  final DateTime assignedAt;

  const PromotionAssignment({
    required this.id,
    required this.assignedByUid,
    required this.assignedByName,
    required this.packageId,
    required this.packageName,
    required this.numberOfSessions,
    required this.targetUserId,
    required this.targetUserName,
    required this.targetUserEmail,
    required this.assignedAt,
  });

  factory PromotionAssignment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PromotionAssignment(
      id: doc.id,
      assignedByUid: d['assignedByUid'] as String? ?? '',
      assignedByName: d['assignedByName'] as String? ?? '',
      packageId: d['packageId'] as String? ?? '',
      packageName: d['packageName'] as String? ?? '',
      numberOfSessions: d['numberOfSessions'] as int? ?? 0,
      targetUserId: d['targetUserId'] as String? ?? '',
      targetUserName: d['targetUserName'] as String? ?? '',
      targetUserEmail: d['targetUserEmail'] as String? ?? '',
      assignedAt: (d['assignedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'assignedByUid': assignedByUid,
        'assignedByName': assignedByName,
        'packageId': packageId,
        'packageName': packageName,
        'numberOfSessions': numberOfSessions,
        'targetUserId': targetUserId,
        'targetUserName': targetUserName,
        'targetUserEmail': targetUserEmail,
        'assignedAt': Timestamp.fromDate(assignedAt),
      };
}
