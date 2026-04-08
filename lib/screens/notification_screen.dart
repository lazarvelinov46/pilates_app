import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final service = NotificationService();

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<AppNotification>>(
        stream: service.notificationsStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 48,
                    color: AppTheme.textColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      color: AppTheme.textColor.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final n = notifications[index];
              return _NotificationTile(
                notification: n,
                onTap: () => service.markAsRead(userId, n.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isUnread
              ? AppTheme.secondary
              : AppTheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _iconFor(notification.type),
          size: 20,
          color: isUnread
              ? AppTheme.primary
              : AppTheme.textColor.withValues(alpha: 0.4),
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
          color: AppTheme.textColor,
        ),
      ),
      subtitle: Text(
        notification.message,
        style: TextStyle(
          color: AppTheme.textColor.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      ),
      trailing: Text(
        _formatTime(notification.createdAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: isUnread ? onTap : null,
    );
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.bookingConfirmed:
        return Icons.check_circle_outline;
      case NotificationType.sessionReminder:
        return Icons.alarm_outlined;
      case NotificationType.sessionCancelled:
        return Icons.cancel_outlined;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}
