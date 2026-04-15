import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/session_model.dart';
import '../../models/booking_model.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../services/session_service.dart';
import '../../services/booking_service.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';

import 'widgets/date_selector.dart';
import 'widgets/session_card.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final SessionService _sessionService = SessionService();
  final BookingService _bookingService = BookingService();
  final NotificationService _notificationService = NotificationService();
  final ScrollController _scrollController = ScrollController();

  DateTime selectedDate = DateTime.now();
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  late Stream<AppUser> _userStream;
  late Stream<List<Session>> _sessionsStream;
  late Stream<Set<String>> _activeBookingsStream;

  final Set<String> _cancelledSessionIds = {};

  Set<DateTime> _availableDates = {};
  bool _calendarVisible = true;

  @override
  void initState() {
    super.initState();
    _userStream = UserService().getUserStream(userId);
    _sessionsStream = _sessionService.streamSessionsForDate(selectedDate);
    _activeBookingsStream =
        _bookingService.getUserActiveBookingsStream(userId);
    _loadAvailableDates();

  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableDates() async {
    final dates = await _sessionService.getAvailableSessionDates();
    if (mounted) setState(() => _availableDates = dates);
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      selectedDate = date;
      _sessionsStream = _sessionService.streamSessionsForDate(date);
      _cancelledSessionIds.clear();
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Booking ───────────────────────────────────────────────────────────────

  Future<void> _confirmBooking(Session session) async {
    try {
      await _bookingService.bookSession(
        userId: userId,
        sessionId: session.id,
      );

      setState(() => _cancelledSessionIds.remove(session.id));

      await _notificationService.notifyBookingConfirmed(session);
      await _notificationService.scheduleSessionReminders(session);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Session booked for '
              '${DateFormat('EEE dd MMM • HH:mm').format(session.startsAt)}',
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Booking failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  // ── Cancellation ──────────────────────────────────────────────────────────

  Future<void> _cancelBookingForSession(
      Session session, Booking? booking) async {
    if (booking == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel session?'),
        content: Text(
          'Are you sure you want to cancel your session on '
          '${booking.formattedDateTime}?\n\n'
          '${booking.canCancel() ? 'Your session credit will be returned to your promotion.' : 'Note: cancellation is within 12 hours of the session — your credit will NOT be refunded.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _bookingService.cancelBooking(booking: booking);

      setState(() => _cancelledSessionIds.add(session.id));

      await _notificationService.cancelSessionReminders(session.id);

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
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book a Session')),
      body: Column(
        children: [
          // ── Collapsible calendar ────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: _calendarVisible
                ? DateSelector(
                    selectedDate: selectedDate,
                    onChanged: _onDateChanged,
                    availableDates: _availableDates,
                  )
                : const SizedBox.shrink(),
          ),

          // ── Collapsed date chip ─────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _calendarVisible
                ? const SizedBox.shrink()
                : GestureDetector(
                    key: const ValueKey('date-chip'),
                    onTap: () => _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 15, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE, dd MMMM yyyy')
                                .format(selectedDate),
                            style: const TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14),
                          ),
                          const Spacer(),
                          const Icon(Icons.expand_more,
                              size: 16, color: AppTheme.primary),
                        ],
                      ),
                    ),
                  ),
          ),

          // ── Sessions list (real-time) ────────────────────────────────────
          Expanded(
            child: StreamBuilder<AppUser>(
              stream: _userStream,
              builder: (context, userSnap) {
                final user = userSnap.data;
                return Column(
                  children: [
                    if (user != null && !user.hasActivePromotion)
                      _TrialStatusBanner(
                          trialSessionUsed: user.trialSessionUsed),
                    Expanded(
                      child: StreamBuilder<Set<String>>(
                        stream: _activeBookingsStream,
                        builder: (context, bookingsSnap) {
                          final activeBookingIds = bookingsSnap.data ?? {};
                          return StreamBuilder<List<Session>>(
                            stream: _sessionsStream,
                            builder: (context, sessionsSnap) {
                              if (sessionsSnap.connectionState ==
                                      ConnectionState.waiting &&
                                  !sessionsSnap.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              final sessions = sessionsSnap.data ?? [];

                              if (sessions.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.event_busy,
                                          size: 48,
                                          color: AppTheme.textColor
                                              .withValues(alpha: 0.3)),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No sessions on '
                                        '${DateFormat('dd MMM').format(selectedDate)}',
                                        style: TextStyle(
                                            color: AppTheme.textColor
                                                .withValues(alpha: 0.5)),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return NotificationListener<UserScrollNotification>(
                                onNotification: (notification) {
                                  if (notification.direction == ScrollDirection.reverse) {
                                    if (_calendarVisible) setState(() => _calendarVisible = false);
                                  } else if (notification.direction == ScrollDirection.forward) {
                                    if (!_calendarVisible && _scrollController.offset < 20) {
                                      setState(() => _calendarVisible = true);
                                    }
                                  }
                                  return false;
                                },
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  itemCount: sessions.length,
                                  itemBuilder: (context, index) {
                                    final session = sessions[index];
                                    final isCancelled =
                                        _cancelledSessionIds
                                            .contains(session.id);
                                    final alreadyBooked =
                                        activeBookingIds.contains(session.id);
                                    return SessionCard(
                                      session: session,
                                      alreadyBooked:
                                          alreadyBooked && !isCancelled,
                                      isCancelled: isCancelled,
                                      onBook: () => _confirmBooking(session),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrialStatusBanner extends StatelessWidget {
  final bool trialSessionUsed;
  const _TrialStatusBanner({required this.trialSessionUsed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.secondaryContainer.withValues(alpha: 0.45),
      child: Row(
        children: [
          Icon(
            trialSessionUsed
                ? Icons.check_circle_outline
                : Icons.card_giftcard_outlined,
            color: cs.secondary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              trialSessionUsed
                  ? 'Trial session booked — purchase a package to continue.'
                  : 'No active promotion. You can book 1 free trial session.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textColor.withValues(alpha: 0.8),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
