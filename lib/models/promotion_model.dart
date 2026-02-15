import 'package:cloud_firestore/cloud_firestore.dart';

class Promotion {
  final int totalSessions;
  final int attended;
  final int booked;
  final DateTime expiresAt;

  Promotion({
    required this.totalSessions,
    required this.attended,
    required this.booked,
    required this.expiresAt,
  });

  int get remaining => totalSessions - attended - booked;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool canBook() => !isExpired && remaining > 0;

  factory Promotion.fromMap(Map<String, dynamic> map) {
    return Promotion(
      totalSessions: map['totalSessions'],
      attended: map['attended'],
      booked: map['booked'],
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalSessions': totalSessions,
      'attended': attended,
      'booked': booked,
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }
}
