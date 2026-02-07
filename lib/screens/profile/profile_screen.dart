import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/booking_model.dart';
import '../../services/booking_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final BookingService _bookingService = BookingService();

  List<Booking> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final bookings =
        await _bookingService.getActiveBookingsForUser(userId);

    setState(() {
      _bookings = bookings;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? const Center(child: Text('No active bookings'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookings.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final booking = _bookings[index];

                    return ListTile(
                      leading: const Icon(Icons.event),
                      title: Text(
                        booking.sessionId ?? 'Session',
                      ),
                      subtitle: Text(
                        booking.formattedDateTime,
                      ),
                    );
                  },
                ),
    );
  }
}
