import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/session_model.dart';

class SessionCard extends StatelessWidget {
  final Session session;
  final bool alreadyBooked;
  final VoidCallback onBook;

  const SessionCard({
    super.key,
    required this.session,
    required this.alreadyBooked,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final double fillPercent =
        session.bookedCount / session.capacity;

    final bool isFull =
        session.bookedCount >= session.capacity;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Date
            Text(
              DateFormat.yMMMMd().format(session.startsAt),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            /// Time
            Text(
              "${DateFormat.Hm().format(session.startsAt)} - "
              "${DateFormat.Hm().format(session.endsAt)}",
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 12),

            /// Capacity Info
            Text(
              "${session.bookedCount}/${session.capacity} spots booked",
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 8),

            /// Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fillPercent.clamp(0, 1),
                minHeight: 8,
                backgroundColor: Colors.grey.shade300,
              ),
            ),

            const SizedBox(height: 16),

            /// Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isFull || alreadyBooked)
                    ? null
                    : onBook,
                child: Text(
                  isFull
                      ? "Full"
                      : alreadyBooked
                          ? "Already Booked"
                          : "Book Session",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}