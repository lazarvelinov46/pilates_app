import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<AppNotification> _notifications = [
    AppNotification(
      id: '1',
      title: 'Booking confirmed',
      message: 'Your session on 12 Oct at 18:00 is confirmed.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: '2',
      title: 'Reminder',
      message: 'You have a session tomorrow at 10:00.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_outlined,
                      size: 48,
                      color: AppTheme.textColor.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications',
                    style: TextStyle(
                        color: AppTheme.textColor.withValues(alpha: 0.45)),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: _notifications.length,
              separatorBuilder: (context, i) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final n = _notifications[index];
                final isUnread = !n.isRead;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
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
                      Icons.notifications_outlined,
                      size: 20,
                      color: isUnread
                          ? AppTheme.primary
                          : AppTheme.textColor.withValues(alpha: 0.4),
                    ),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight:
                          isUnread ? FontWeight.w600 : FontWeight.normal,
                      color: AppTheme.textColor,
                    ),
                  ),
                  subtitle: Text(
                    n.message,
                    style: TextStyle(
                        color: AppTheme.textColor.withValues(alpha: 0.6),
                        fontSize: 13),
                  ),
                  trailing: Text(
                    _formatTime(n.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () {
                    setState(() {
                      _notifications[index] = AppNotification(
                        id: n.id,
                        title: n.title,
                        message: n.message,
                        createdAt: n.createdAt,
                        isRead: true,
                      );
                    });
                  },
                );
              },
            ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}
