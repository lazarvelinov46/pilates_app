import 'package:flutter/material.dart';
import '../../models/booking_model.dart';

class UpcomingBookingTile extends StatelessWidget {
  final Booking booking;
  final VoidCallback onCancel;

  const UpcomingBookingTile({
    super.key,
    required this.booking,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final bool canCancel = booking.canCancel();

    return Card(
      child: ListTile(
        title: Text(booking.formattedDateTime),
        subtitle: Text(
          canCancel
              ? 'You can cancel until 12h before'
              : 'Cancellation window passed',
        ),
        trailing: canCancel
            ? TextButton(
                onPressed: onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red),
                ),
              )
            : const Text(
                'Locked',
                style: TextStyle(color: Colors.grey),
              ),
      ),
    );
  }
}
