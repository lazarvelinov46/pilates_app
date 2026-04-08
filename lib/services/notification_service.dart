import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_model.dart';
import '../models/session_model.dart';

/// Top-level handler for FCM background messages (required by firebase_messaging).
/// Must be a top-level function — cannot be a class method.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled automatically by the OS when the app is
  // not in the foreground. No action needed here.
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'pilates_reminders';
  static const _channelName = 'Session Reminders';
  static const _channelDesc =
      'Reminds you 2 hours before a booked session starts.';

  // ── Initialise once at app startup ───────────────────────────────────────

  Future<void> init() async {
    await _initTimezone();
    await _initLocalNotifications();

    // FCM is not supported on Windows or Linux desktop builds.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _listenForForegroundMessages();

    // Whenever the auth state changes, refresh the FCM token in Firestore.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _storeFCMToken(user.uid);
      }
    });
  }

  // ── Called after a session is successfully booked ────────────────────────

  /// Writes a booking-confirmed notification to Firestore and schedules the
  /// 2-hour local reminder. Both actions respect the user's notification pref.
  Future<void> notifyBookingConfirmed(Session session) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final notificationsEnabled = await _getNotificationsEnabled(userId);

    if (notificationsEnabled) {
      await _storeNotification(
        userId: userId,
        title: 'Booking confirmed',
        message:
            'Your session on ${_formatDateTime(session.startsAt)} is confirmed.',
        type: NotificationType.bookingConfirmed,
      );
    }

    await scheduleSessionReminders(session, enabled: notificationsEnabled);
  }

  // ── Schedule the 2-hour local reminder ───────────────────────────────────

  /// Schedules a local notification 2 hours before [session] starts.
  /// Client-side only — works on the Spark (free) Firebase plan.
  /// Pass [enabled] directly to avoid a redundant Firestore read when called
  /// from [notifyBookingConfirmed].
  Future<void> scheduleSessionReminders(
    Session session, {
    bool? enabled,
  }) async {
    // Local notifications are only supported on mobile / macOS.
    if (kIsWeb || Platform.isWindows || Platform.isLinux) return;

    final notifEnabled =
        enabled ?? await _getNotificationsEnabled(
          FirebaseAuth.instance.currentUser?.uid ?? '',
        );
    if (!notifEnabled) return;

    final reminderTime =
        session.startsAt.subtract(const Duration(hours: 2));
    if (!reminderTime.isAfter(DateTime.now())) return; // Already past

    final notifId = _notifIdFor(session.id);

    await _local.zonedSchedule(
      notifId,
      'Session in 2 hours',
      'Your pilates session starts at ${_formatTime(session.startsAt)}. See you soon!',
      tz.TZDateTime.from(reminderTime, tz.local),
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(sound: 'default'),
        macOS: const DarwinNotificationDetails(sound: 'default'),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Cancel 2-hour reminder when user cancels a booking ───────────────────

  Future<void> cancelSessionReminders(String sessionId) async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) return;
    await _local.cancel(_notifIdFor(sessionId));
  }

  // ── Firestore notification stream (used by NotificationsScreen) ──────────

  Stream<List<AppNotification>> notificationsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(AppNotification.fromFirestore).toList());
  }

  /// Count of unread notifications (for the badge in the nav bar).
  Stream<int> unreadCountStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Mark a single notification as read in Firestore.
  Future<void> markAsRead(String userId, String notificationId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _initTimezone() async {
    tz.initializeTimeZones();
    if (!kIsWeb) {
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );

    // Create the Android notification channel once.
    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDesc,
              importance: Importance.high,
            ),
          );
    }
  }

  /// Requests FCM permission and stores the token in the user's Firestore doc.
  Future<void> _storeFCMToken(String userId) async {
    try {
      NotificationSettings settings;

      if (kIsWeb || !Platform.isWindows) {
        settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } else {
        return; // Windows not supported
      }

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db
            .collection('users')
            .doc(userId)
            .update({'fcmToken': token});
      }

      // Keep the token fresh on every rotation.
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _db
            .collection('users')
            .doc(userId)
            .update({'fcmToken': newToken});
      });
    } catch (_) {
      // FCM token setup failure must never crash the app.
    }
  }

  /// Shows a local notification when an FCM message arrives while the app
  /// is open (foreground). The OS handles display when the app is closed.
  void _listenForForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      if (kIsWeb || Platform.isWindows || Platform.isLinux) return;

      _local.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(sound: 'default'),
          macOS: DarwinNotificationDetails(sound: 'default'),
        ),
      );
    });
  }

  /// Writes a notification document to `users/{userId}/notifications`.
  Future<void> _storeNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'title': title,
      'message': message,
      'type': type.name,
      'createdAt': Timestamp.now(),
      'isRead': false,
    });
  }

  /// Returns the user's `preferences.notifications` flag from Firestore.
  /// Defaults to `true` on any error so we don't silently swallow notifications.
  Future<bool> _getNotificationsEnabled(String userId) async {
    if (userId.isEmpty) return false;
    try {
      final doc = await _db.collection('users').doc(userId).get();
      final prefs = doc.data()?['preferences'] as Map<String, dynamic>?;
      return prefs?['notifications'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Converts a session ID to a stable 32-bit int for local notification IDs.
  int _notifIdFor(String sessionId) =>
      sessionId.hashCode.abs() % 0x7FFFFFFF;

  String _formatDateTime(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = days[dt.weekday - 1];
    final month = months[dt.month - 1];
    return '$day ${dt.day} $month at ${_formatTime(dt)}';
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
