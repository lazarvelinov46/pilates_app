import '../models/session_model.dart';

/// Stub — flutter_local_notifications temporarily disabled.
/// Re-enable by restoring pubspec.yaml entries and the original implementation.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> init() async {}
  Future<void> notifyBookingConfirmed(Session session) async {}
  Future<void> scheduleSessionReminders(Session session) async {}
  Future<void> cancelSessionReminders(String sessionId) async {}
}