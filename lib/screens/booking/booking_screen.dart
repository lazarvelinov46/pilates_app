import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/session_model.dart';
import '../../services/session_service.dart';
import '../../services/booking_service.dart';

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
  final ScrollController _scrollController = ScrollController();

  DateTime selectedDate = DateTime.now();
  String userId = FirebaseAuth.instance.currentUser!.uid;
  List<Session> availableSessions = [];
  Set<DateTime> _availableDates = {};
  bool isLoading = false;
  Set<String> _bookedSessionIds = {};
  bool _loadingBookings = true;
  bool _calendarVisible = true;

  @override
  void initState() {
    super.initState();
    _loadUserBookings();
    _loadAvailableDates();
    _loadSessions();

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

  Future<void> _loadUserBookings() async {
    final bookings = await _bookingService.getUserActiveBookings(userId);
    setState(() {
      _bookedSessionIds = bookings;
      _loadingBookings = false;
    });
  }

  Future<void> _loadAvailableDates() async {
    final dates = await _sessionService.getAvailableSessionDates();
    setState(() {
      _availableDates = dates;
    });
  }

  Future<void> _loadSessions() async {
    setState(() => isLoading = true);
    availableSessions = await _sessionService.getSessionsForDate(selectedDate);
    setState(() => isLoading = false);
  }

  void _onDateChanged(DateTime date) {
    setState(() => selectedDate = date);
    _loadSessions();
    // Scroll back to top so calendar is visible after selecting a new date
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _confirmBooking(Session session) async {
    try {
      await _bookingService.bookSession(
        userId: userId,
        sessionId: session.id,
      );

      setState(() {
        _bookedSessionIds.add(session.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Session booked for ${DateFormat('EEE dd MMM • HH:mm').format(session.startsAt)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingBookings) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Book a Session')),
      body: Column(
        children: [
          // Collapsible calendar — hides when user scrolls down
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

          // Small chip showing selected date when calendar is hidden
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _calendarVisible
                ? const SizedBox.shrink()
                : GestureDetector(
                    key: const ValueKey('date-chip'),
                    onTap: () {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    },
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
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          const Icon(Icons.expand_more, size: 16),
                        ],
                      ),
                    ),
                  ),
          ),

          // Sessions list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : availableSessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_busy,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'No sessions on ${DateFormat('dd MMM').format(selectedDate)}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: availableSessions.length,
                        itemBuilder: (context, index) {
                          final session = availableSessions[index];
                          return SessionCard(
                            session: session,
                            alreadyBooked:
                                _bookedSessionIds.contains(session.id),
                            onBook: () => _confirmBooking(session),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}