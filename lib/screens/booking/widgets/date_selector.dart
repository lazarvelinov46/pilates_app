import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class DateSelector extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  /// List of dates that have at least one active session
  final Set<DateTime> availableDates;

  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onChanged,
    required this.availableDates,
  });

  @override
  State<DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends State<DateSelector> {
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedDate;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  bool _isAvailable(DateTime day) {
    return widget.availableDates.any(
      (d) => _isSameDay(d, day),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime.now(),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) =>
          _isSameDay(day, widget.selectedDate),

      enabledDayPredicate: (day) {
        return _isAvailable(day);
      },

      onDaySelected: (selectedDay, focusedDay) {
        if (!_isAvailable(selectedDay)) return;

        setState(() {
          _focusedDay = focusedDay;
        });

        widget.onChanged(selectedDay);
      },

      calendarStyle: CalendarStyle(
        todayDecoration: const BoxDecoration(
          color: Colors.blueAccent,
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
        disabledTextStyle:
            TextStyle(color: Colors.grey.shade400),
      ),

      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
    );
  }
}
