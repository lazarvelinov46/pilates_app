import 'package:flutter/material.dart';
import '../models/notification_model.dart';

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
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _notifications.isEmpty
          ? const Center(child: Text('No notifications'))
          : ListView.separated(
              itemCount: _notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = _notifications[index];

                return ListTile(
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight:
                          n.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(n.message),
                  trailing: Text(
                    _formatTime(n.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () {
                    setState(() {
                      _notifications[index] =
                          AppNotification(
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
