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
    try {
      await _bookingService.cancelBooking(booking: booking);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

 Widget build(BuildContext context) {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  return Scaffold(
    appBar: AppBar(title: const Text('Profile')),
    body: StreamBuilder<List<Booking>>(
      stream: _bookingService.getActiveBookingsForUserStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return const Center(child: Text('No active bookings'));
        }

        return ListView.builder(
          itemCount: bookings.length,
          itemBuilder: (context, i) {
            final b = bookings[i];
            return Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                title: Text(b.formattedDateTime),
                trailing: TextButton(
                  onPressed: b.canCancel()
                      ? () async {
                          await _bookingService.cancelBooking(booking: b);
                        }
                      : null,
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
        );
      },
    ),
  );
}
}