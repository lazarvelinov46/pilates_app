import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import '../models/session_model.dart';

/// Handles all local push notifications for the app:
///   • Immediate booking confirmation
///   • 24-hour session reminder
///   • 1-hour session reminder
///   • Cancellation of pending reminders when a session is cancelled
class NotificationService {
  // Singleton so the plugin is only initialised once.
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Call once at app startup (e.g. in main.dart after Firebase.initializeApp).
  Future<void> init() async {
    if (_initialized) return;

    // Set up timezone data so scheduled notifications fire at the right time.
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

    // Android 13+ requires explicit runtime permission for notifications.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  // ── Shared notification channel/details ──────────────────────────────────

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'pilates_sessions', // channel id
          'Pilates Sessions', // channel name
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

  /// Shows an immediate notification confirming a successful booking.
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

  /// Schedules a 24-hour and a 1-hour reminder for [session].
  /// Reminders that are already in the past are silently skipped.
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

  /// Cancels all pending reminders (24h + 1h) for [sessionId].
  /// Call this when the user cancels a booking.
  Future<void> cancelSessionReminders(String sessionId) async {
    await _plugin.cancel(_reminder24hId(sessionId));
    await _plugin.cancel(_reminder1hId(sessionId));
  }

  // ── Stable ID helpers ─────────────────────────────────────────────────────
  // These use a deterministic hash so notification IDs are stable
  // across app restarts, enabling reliable cancellation of scheduled alerts.

  int _stableHash(String s) {
    var hash = 0;
    for (final c in s.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return hash % 100000; // keep within reasonable int range
  }

  int _confirmationId(String sessionId) => _stableHash(sessionId);
  int _reminder24hId(String sessionId) => _stableHash(sessionId) + 100000;
  int _reminder1hId(String sessionId) => _stableHash(sessionId) + 200000;
}