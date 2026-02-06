import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/session_model.dart';


class TimeSlotGrid extends StatelessWidget {
  final List<Session> sessions;
  final Session? selectedSession;
  final Set<String> bookedSessionIds;
  final ValueChanged<Session> onSelect;

  const TimeSlotGrid({
    super.key,
    required this.sessions,
    required this.selectedSession,
    required this.bookedSessionIds,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Text("No available slots");
    }

    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
      ),
      itemCount: sessions.length,
      itemBuilder: (context, i) {
        final s = sessions[i];
        final selected = selectedSession?.id == s.id;
        final bool alreadyBooked = bookedSessionIds.contains(s.id);
        final bool isFull = s.bookedCount>=s.capacity;
        final bool canBook = !alreadyBooked && !isFull;
        return GestureDetector(
          onTap: canBook?() => onSelect(s):null,
          child: Card(
            color: !canBook
                ? Colors.grey.shade300
                : selected
                    ? Colors.green
                    : null,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.Hm().format(s.startsAt),
                    style: TextStyle(
                      color: !canBook ? Colors.grey : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.bookedCount}/${s.capacity}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  // 🔹 NEW: visual indicator for already booked session
                  if (alreadyBooked)
                    const Text(
                      'Booked',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
