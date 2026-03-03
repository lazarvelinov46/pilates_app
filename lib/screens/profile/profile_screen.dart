import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final BookingService _bookingService = BookingService();
  final AuthService _authService = AuthService();
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
  
  Future<void> _logout() async {
    await _authService.signOut();
  }

 Widget build(BuildContext context) {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  return Scaffold(
    appBar: AppBar(
      title: const Text('Profile'),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await _logout();
            }
          },
        ),
      ],
    ),
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