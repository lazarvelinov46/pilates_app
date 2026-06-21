import 'package:flutter/material.dart';
import '../../models/booking_model.dart';
import '../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final bool canCancel = booking.canCancel();

    return Card(
      child: ListTile(
        title: Text(booking.formattedDateTime),
        subtitle: Text(
          canCancel
              ? l10n.cancelUntil12h
              : l10n.cancellationWindowPassed,
        ),
        trailing: canCancel
            ? TextButton(
                onPressed: onCancel,
                child: Text(
                  l10n.cancelButton,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : Text(
                l10n.lockedLabel,
                style: const TextStyle(color: Colors.grey),
              ),
      ),
    );
  }
}
