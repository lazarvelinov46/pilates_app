import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> init(String userId) async {
    await _messaging.requestPermission();

    final token = await _messaging.getToken();

    if (token != null) {
      await _db.collection('users').doc(userId).update({
        'fcmToken': token,
      });
    }
  }
}
