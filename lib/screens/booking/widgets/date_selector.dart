import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final date = DateTime.now().add(Duration(days: i));

        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(date),
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: date.day == selectedDate.day
                    ? Colors.blue
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text("${date.day}"),
                  Text(DateFormat.E().format(date)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
