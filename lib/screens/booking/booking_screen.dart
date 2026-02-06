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
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
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

    await _bookingService.bookSession(
      userId: userId,
      sessionId: selectedSession!.id,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Book a Session")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DateSelector(
              selectedDate: selectedDate,
              onChanged: _onDateChanged,
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const CircularProgressIndicator()
            else
              TimeSlotGrid(
                sessions: availableSessions,
                selectedSession: selectedSession,
                onSelect: (s) => setState(() => selectedSession = s),
              ),
            const Spacer(),
            ConfirmButton(
              enabled: selectedSession != null,
              onPressed: _confirmBooking,
            ),
          ],
        ),
      ),
    );
  }
}
