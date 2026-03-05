import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/session_model.dart';
import '../../models/booking_model.dart';
import '../../services/session_service.dart';
import '../../services/booking_service.dart';
import '../../services/notification_service.dart';

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

  // ── Real-time streams ─────────────────────────────────────────────────────

  // Sessions for the currently selected date — rebuilt when date changes.
  late Stream<List<Session>> _sessionsStream;

  // All session IDs the user currently has an active booking for.
  late Stream<Set<String>> _activeBookingsStream;

  // ── Local optimistic state ────────────────────────────────────────────────

  // Tracks sessions the user cancelled during this session so we can show
  // the "Cancelled" state immediately without waiting for Firestore to
  // propagate the removal from _activeBookingsStream.
  final Set<String> _cancelledSessionIds = {};

  // ── Other state ───────────────────────────────────────────────────────────

  Set<DateTime> _availableDates = {};
  bool _calendarVisible = true;

  @override
  void initState() {
    super.initState();
    _sessionsStream = _sessionService.streamSessionsForDate(selectedDate);
    _activeBookingsStream =
        _bookingService.getUserActiveBookingsStream(userId);
    _loadAvailableDates();

    _scrollController.addListener(() {
      final shouldShow = _scrollController.offset < 20;
      if (shouldShow != _calendarVisible) {
        setState(() => _calendarVisible = shouldShow);
      }
    });
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
      // Rebuild the sessions stream for the new date.
      _sessionsStream = _sessionService.streamSessionsForDate(date);
      // Clear local cancelled state — it's per-day context.
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

      // Remove from cancelled set in case the user is re-booking after cancel.
      // (Only relevant if re-book support is enabled in SessionCard.)
      setState(() => _cancelledSessionIds.remove(session.id));

      // Send immediate confirmation notification + schedule reminders.
      await _notificationService.notifyBookingConfirmed(session);
      await _notificationService.scheduleSessionReminders(session);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Session booked for '
              '${DateFormat('EEE dd MMM • HH:mm').format(session.startsAt)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _bookingService.cancelBooking(booking: booking);

      // Mark locally as cancelled so the card updates immediately.
      setState(() => _cancelledSessionIds.add(session.id));

      // Cancel the pending 24h and 1h reminders for this session.
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
            backgroundColor: Colors.red,
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
                          horizontal: 16, vertical: 8),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE, dd MMMM yyyy')
                                .format(selectedDate),
                            style: const TextStyle(
                                fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          const Icon(Icons.expand_more, size: 16),
                        ],
                      ),
                    ),
                  ),
          ),

          // ── Sessions list (real-time) ────────────────────────────────────
          Expanded(
            child: StreamBuilder<Set<String>>(
              stream: _activeBookingsStream,
              builder: (context, bookingsSnap) {
                // Active booking IDs from Firestore (live).
                final activeBookingIds = bookingsSnap.data ?? {};

                return StreamBuilder<List<Session>>(
                  stream: _sessionsStream,
                  builder: (context, sessionsSnap) {
                    // Show spinner only on first load, not on updates.
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
                            const Icon(Icons.event_busy,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'No sessions on '
                              '${DateFormat('dd MMM').format(selectedDate)}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];

                        // A session is "cancelled" when:
                        //   • The user explicitly cancelled it this session
                        //     (optimistic local state), OR
                        //   • It's no longer in the active bookings stream
                        //     but was already in _cancelledSessionIds.
                        final isCancelled =
                            _cancelledSessionIds.contains(session.id);

                        final alreadyBooked =
                            activeBookingIds.contains(session.id);

                        return SessionCard(
                          session: session,
                          alreadyBooked: alreadyBooked && !isCancelled,
                          isCancelled: isCancelled,
                          onBook: () => _confirmBooking(session),

                          // -----------------------------------------------
                          // Re-book support: to let users re-book a session
                          // they cancelled, pass an onBookAgain callback.
                          // Steps:
                          //   1. Uncomment the onBookAgain field in
                          //      SessionCard and its usage in the button logic.
                          //   2. Uncomment the line below.
                          // -----------------------------------------------
                          // onBookAgain: isCancelled
                          //     ? () => _confirmBooking(session)
                          //     : null,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}