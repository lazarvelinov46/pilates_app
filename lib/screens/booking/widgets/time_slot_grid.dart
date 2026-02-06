import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/session_model.dart';


class TimeSlotGrid extends StatelessWidget {
  final List<Session> sessions;
  final Session? selectedSession;
  final ValueChanged<Session> onSelect;

  const TimeSlotGrid({
    super.key,
    required this.sessions,
    required this.selectedSession,
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

        return GestureDetector(
          onTap: () => onSelect(s),
          child: Card(
            color: selected ? Colors.green : null,
            child: Center(
              child: Text(
                DateFormat.Hm().format(s.startsAt),
              ),
            ),
          ),
        );
      },
    );
  }
}
