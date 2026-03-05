import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import '../models/session_model.dart';

/// Handles all push notifications for the app:
///
///   Local (device-only):
///     • Immediate booking confirmation
///     • 24-hour session reminder
///     • 1-hour session reminder
///     • Cancellation of pending reminders when user cancels
///
///   Remote via FCM (sent by Cloud Functions):
///     • Session cancelled by admin — received passively, no code needed here
///
///   Token management:
///     • Saves the device FCM token to the user's Firestore doc on init
///       so the Cloud Function can send remote notifications to this device
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final String localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request FCM permission and save the device token to Firestore.
    // The Cloud Function reads this token to send remote push notifications
    // when the admin cancels a session.
    await _initFcmToken();

    _initialized = true;
  }

  // ── FCM token management ──────────────────────────────────────────────────

  Future<void> _initFcmToken() async {
    final messaging = FirebaseMessaging.instance;

    // Required on iOS; harmless no-op on Android.
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();
    if (token != null) await _saveToken(token);

    // FCM can rotate tokens — keep Firestore up to date.
    messaging.onTokenRefresh.listen(_saveToken);
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'fcmToken': token});
  }

  // ── Shared notification channel/details ──────────────────────────────────

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'pilates_sessions',
          'Pilates Sessions',
          channelDescription:
              'Booking confirmations and session reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  // ── Public API ────────────────────────────────────────────────────────────

  /// Immediate local notification confirming a successful booking.
  Future<void> notifyBookingConfirmed(Session session) async {
    await init();
    final formattedTime =
        DateFormat('EEE dd MMM • HH:mm').format(session.startsAt);

    await _plugin.show(
      _confirmationId(session.id),
      'Booking Confirmed ✓',
      'Your pilates session on $formattedTime is confirmed.',
      _details,
    );
  }

  /// Schedules a 24h and a 1h local reminder for [session].
  /// Past reminders are silently skipped.
  Future<void> scheduleSessionReminders(Session session) async {
    await init();
    final sessionTime = DateFormat('HH:mm').format(session.startsAt);
    final now = DateTime.now();

    final reminder24h = session.startsAt.subtract(const Duration(hours: 24));
    final reminder1h = session.startsAt.subtract(const Duration(hours: 1));

    if (reminder24h.isAfter(now)) {
      await _plugin.zonedSchedule(
        _reminder24hId(session.id),
        'Session Tomorrow 🧘',
        'You have a pilates session tomorrow at $sessionTime. See you there!',
        tz.TZDateTime.from(reminder24h, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    if (reminder1h.isAfter(now)) {
      await _plugin.zonedSchedule(
        _reminder1hId(session.id),
        'Session in 1 Hour ⏰',
        'Your pilates session starts at $sessionTime. Get ready!',
        tz.TZDateTime.from(reminder1h, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Cancels pending local reminders (24h + 1h) for [sessionId].
  /// Call this when the user cancels their own booking.
  Future<void> cancelSessionReminders(String sessionId) async {
    await _plugin.cancel(_reminder24hId(sessionId));
    await _plugin.cancel(_reminder1hId(sessionId));
  }

  // ── Stable ID helpers ─────────────────────────────────────────────────────

  int _stableHash(String s) {
    var hash = 0;
    for (final c in s.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return hash % 100000;
  }

  int _confirmationId(String sessionId) => _stableHash(sessionId);
  int _reminder24hId(String sessionId) => _stableHash(sessionId) + 100000;
  int _reminder1hId(String sessionId) => _stableHash(sessionId) + 200000;
}