import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';


import '../../models/session_model.dart';
import '../../services/session_service.dart';
import '../../services/booking_service.dart';

import 'widgets/date_selector.dart';
import 'widgets/time_slot_grid.dart';
import 'widgets/confirm_button.dart';


class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final SessionService _sessionService=SessionService();
  final BookingService _bookingService=BookingService();
  DateTime selectedDate = DateTime.now();
  Session? selectedSession;
  String userId = FirebaseAuth.instance.currentUser!.uid;
  List<Session> availableSessions = [];
  Set<DateTime> _availableDates = {};
  bool isLoading = false;

  Set<String> _bookedSessionIds = {};
  bool _loadingBookings = true;

  bool _bookingInProgress = false;


  @override
  void initState() {
    super.initState();
    _loadUserBookings();
    _loadAvailableDates();
    _loadSessions();
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

    availableSessions =
        await _sessionService.getSessionsForDate(selectedDate);

    setState(() => isLoading = false);
  }

  void _onDateChanged(DateTime date) {
    selectedDate = date;
    selectedSession = null;
    _loadSessions();
  }

  Future<void> _confirmBooking() async {
    if (selectedSession == null) return;

    setState(() => _bookingInProgress = true);

    try {
      await _bookingService.bookSession(
        userId: userId,
        sessionId: selectedSession!.id,
      );

      setState(() {
        _bookedSessionIds.add(selectedSession!.id);
        selectedSession = null;
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }finally{
      setState(() => _bookingInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingBookings) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool isFull =
    selectedSession != null &&
    selectedSession!.bookedCount >= selectedSession!.capacity;

    final bool alreadyBooked =
        selectedSession != null &&
        _bookedSessionIds.contains(selectedSession!.id);

    final bool canBook =
        selectedSession != null && !isFull && !alreadyBooked;
    return Scaffold(
      appBar: AppBar(title: const Text("Book a Session")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DateSelector(
              selectedDate: selectedDate,
              onChanged: _onDateChanged,
              availableDates: _availableDates,
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const CircularProgressIndicator()
            else
              TimeSlotGrid(
                sessions: availableSessions,
                selectedSession: selectedSession,
                bookedSessionIds: _bookedSessionIds, // 🔹 pass down
                onSelect: (s) {
                  if (_bookedSessionIds.contains(s.id)) return;
                  setState(() => selectedSession = s);
                },
              ),
            
            const Spacer(),
            ConfirmButton(
              enabled: canBook,
              onPressed: _confirmBooking,
              isLoading: _bookingInProgress,
              isFull: isFull,
              alreadyBooked: alreadyBooked,
            ),
          ],
        ),
      ),
    );
  }
}
