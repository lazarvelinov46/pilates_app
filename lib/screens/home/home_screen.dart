import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../models/user_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/session_model.dart';
import '../../../services/booking_service.dart';
import '../../../services/session_service.dart';
import '../../../services/user_service.dart';
import '../booking/widgets/session_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final UserService _userService = UserService();
  final BookingService _bookingService = BookingService();
  final SessionService _sessionService = SessionService();

  List<Session> _upcomingSessions = [];
  Set<String> _bookedSessionIds = {};
  bool _loadingQuickBook = false;

  @override
  void initState() {
    super.initState();
    _loadQuickBookData();
  }

  Future<void> _loadQuickBookData() async {
    setState(() => _loadingQuickBook = true);
    final sessions = await _sessionService.getUpcomingSessions(limit: 3);
    final booked = await _bookingService.getUserActiveBookings(userId);
    setState(() {
      _upcomingSessions = sessions;
      _bookedSessionIds = booked;
      _loadingQuickBook = false;
    });
  }

  Future<void> _cancelBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel session?'),
        content: Text(
          'Are you sure you want to cancel your session on ${booking.formattedDateTime}?\n\n'
          '${booking.canCancel() ? 'Your session credit will be returned to your promotion.' : 'Note: cancellation is within 12 hours of the session — your credit will NOT be refunded.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _bookingService.cancelBooking(booking: booking);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _quickBook(Session session) async {
    try {
      await _bookingService.bookSession(
        userId: userId,
        sessionId: session.id,
      );
      setState(() => _bookedSessionIds.add(session.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booked for ${DateFormat('EEE dd MMM • HH:mm').format(session.startsAt)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadQuickBookData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Booking failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: StreamBuilder<AppUser>(
        stream: _userService.getUserStream(userId),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = userSnap.data;
          final promotion = user?.promotion;

          return StreamBuilder<List<Booking>>(
            stream: _bookingService.getUpcomingBookingsStream(userId),
            builder: (context, bookingSnap) {
              final upcomingBookings = bookingSnap.data ?? [];

              return RefreshIndicator(
                onRefresh: _loadQuickBookData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // ── Promotion Card ────────────────────────────────────
                    _buildPromotionCard(context, promotion),

                    const SizedBox(height: 24),

                    // ── Upcoming Bookings or Quick-Book ───────────────────
                    if (promotion == null || promotion.isExpired || promotion.remaining <= 0) ...[
                      _buildNoPromotionBanner(context, promotion),
                    ] else if (upcomingBookings.isNotEmpty) ...[
                      Text(
                        'Your upcoming sessions',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ...upcomingBookings
                          .map((b) => _BookingTile(
                                booking: b,
                                onCancel: () => _cancelBooking(b),
                              ))
                          .toList(),
                    ] else ...[
                      // No bookings but has active promo → quick book
                      Row(
                        children: [
                          Text(
                            'Quick book',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: const Text('Upcoming sessions'),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You have no sessions booked yet.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      if (_loadingQuickBook)
                        const Center(
                            child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ))
                      else if (_upcomingSessions.isEmpty)
                        const _EmptySessionsCard()
                      else
                        ..._upcomingSessions
                            .map((s) => SessionCard(
                                  session: s,
                                  alreadyBooked:
                                      _bookedSessionIds.contains(s.id),
                                  onBook: () => _quickBook(s),
                                ))
                            .toList(),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPromotionCard(BuildContext context, promotion) {
    if (promotion == null) {
      return _NoPromotionCard();
    }

    final total = promotion.totalSessions as int;
    final booked = promotion.booked as int;
    final attended = promotion.attended as int;
    final used = booked + attended;
    final fillPercent = total > 0 ? used / total : 0.0;

    final colorScheme = Theme.of(context).colorScheme;
    final isExpired = promotion.isExpired;
    final isExhausted = promotion.remaining <= 0;

    Color cardColor = isExpired || isExhausted
        ? Colors.grey.shade200
        : colorScheme.primaryContainer;

    Color barColor = isExpired || isExhausted ? Colors.grey : colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  promotion.packageName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              if (isExpired)
                _StatusBadge(label: 'Expired', color: Colors.red)
              else if (isExhausted)
                _StatusBadge(label: 'Used up', color: Colors.orange)
              else
                _StatusBadge(
                    label: '${promotion.remaining} left',
                    color: Colors.green),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Expires ${DateFormat('dd MMM yyyy').format(promotion.expiresAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isExpired ? Colors.red.shade700 : Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fillPercent.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.5),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$used / $total sessions used',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPromotionBanner(BuildContext context, promotion) {
    final msg = promotion == null
        ? 'You have no active promotion.'
        : promotion.isExpired
            ? 'Your promotion has expired.'
            : 'You have used all sessions in your promotion.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sessions',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.local_activity_outlined,
                    size: 40, color: Colors.grey),
                const SizedBox(height: 12),
                Text(msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                const Text('Contact us to get a new promotion.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _NoPromotionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.local_activity_outlined,
              size: 36, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No active promotion',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 4),
                const Text('Contact us to purchase a session package.',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Booking booking;
  final VoidCallback onCancel;

  const _BookingTile({required this.booking, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final canCancel = booking.canCancel();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.fitness_center,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.formattedDateTime,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    canCancel
                        ? 'Cancellable until 12h before'
                        : 'Cancellation window has passed',
                    style: TextStyle(
                      fontSize: 12,
                      color: canCancel
                          ? Colors.grey.shade600
                          : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: canCancel ? onCancel : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                disabledForegroundColor: Colors.grey,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySessionsCard extends StatelessWidget {
  const _EmptySessionsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'No upcoming sessions available right now.',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}