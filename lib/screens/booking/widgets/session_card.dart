import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/session_model.dart';

class SessionCard extends StatelessWidget {
  final Session session;
  final bool alreadyBooked;

  /// True when the user had a booking for this session but cancelled it.
  final bool isCancelled;

  final VoidCallback onBook;

  // ---------------------------------------------------------------------------
  // Optional callback to allow re-booking a cancelled session.
  // Uncomment [onBookAgain] and its usage below if you decide to let users
  // re-book sessions they previously cancelled.
  // ---------------------------------------------------------------------------
  // final VoidCallback? onBookAgain;

  const SessionCard({
    super.key,
    required this.session,
    required this.alreadyBooked,
    required this.isCancelled,
    required this.onBook,
    // this.onBookAgain,   // ← uncomment for re-book support
  });

  @override
  Widget build(BuildContext context) {
    final double fillPercent =
        session.bookedCount / session.capacity;

    final bool isFull = session.bookedCount >= session.capacity;

    // Derive the button label and whether it is enabled.
    final String buttonLabel;
    final bool buttonEnabled;
    final VoidCallback? buttonAction;

    if (isCancelled) {
      buttonLabel = 'Cancelled';
      buttonEnabled = false;
      buttonAction = null;

      // ---------------------------------------------------------------------------
      // Re-book support: replace the three lines above with the block below.
      // ---------------------------------------------------------------------------
      // buttonLabel   = onBookAgain != null ? 'Book Again' : 'Cancelled';
      // buttonEnabled = onBookAgain != null && !isFull;
      // buttonAction  = (onBookAgain != null && !isFull) ? onBookAgain : null;
      // ---------------------------------------------------------------------------
    } else if (alreadyBooked) {
      buttonLabel = 'Already Booked';
      buttonEnabled = false;
      buttonAction = null;
    } else if (isFull) {
      buttonLabel = 'Full';
      buttonEnabled = false;
      buttonAction = null;
    } else {
      buttonLabel = 'Book Session';
      buttonEnabled = true;
      buttonAction = onBook;
    }

    // Card accent colour reflects state.
    Color? cardColor;
    if (isCancelled) cardColor = Colors.red.shade50;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCancelled
            ? BorderSide(color: Colors.red.shade200)
            : BorderSide.none,
      ),
      color: cardColor,
      elevation: isCancelled ? 0 : 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date ──────────────────────────────────────────────────────
            Text(
              DateFormat.yMMMMd().format(session.startsAt),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            // ── Time ──────────────────────────────────────────────────────
            Text(
              '${DateFormat.Hm().format(session.startsAt)} – '
              '${DateFormat.Hm().format(session.endsAt)}',
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 12),

            // ── Capacity info ──────────────────────────────────────────────
            Text(
              '${session.bookedCount}/${session.capacity} spots booked',
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 8),

            // ── Progress bar ───────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fillPercent.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isFull ? Colors.red.shade300 : Colors.blue,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Action button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: buttonEnabled ? buttonAction : null,
                style: isCancelled
                    ? ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade700,
                        disabledBackgroundColor: Colors.red.shade100,
                        disabledForegroundColor: Colors.red.shade400,
                      )
                    : null,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}