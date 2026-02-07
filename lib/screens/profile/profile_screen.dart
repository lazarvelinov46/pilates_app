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

  Future<void> _cancel(Booking booking) async {
    await _bookingService.cancelBooking(booking: booking);
    _loadBookings(); // refresh after cancel
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _bookings.isEmpty
          ? const Center(child: Text('No active bookings'))
          : ListView.builder(
              itemCount: _bookings.length,
              itemBuilder: (context, i) {
                final b = _bookings[i];

                return Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    title: Text(b.formattedDateTime),
                    trailing: TextButton(
                      onPressed: b.canCancel() ? () => _cancel(b) : null,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: b.canCancel() ? Colors.red : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
