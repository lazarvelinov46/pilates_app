import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../theme.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

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
        todayDecoration: BoxDecoration(
          color: AppTheme.secondary,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primary, width: 1.5),
        ),
        todayTextStyle: TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w600,
        ),
        selectedDecoration: const BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        disabledTextStyle: TextStyle(
          color: AppTheme.outline.withValues(alpha: 0.5),
        ),
        defaultTextStyle: TextStyle(color: AppTheme.textColor),
        weekendTextStyle: TextStyle(
          color: AppTheme.textColor.withValues(alpha: 0.75),
        ),
        outsideTextStyle: TextStyle(
          color: AppTheme.textColor.withValues(alpha: 0.3),
        ),
        markerDecoration: const BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
        ),
      ),

      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          color: AppTheme.textColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        leftChevronIcon: const Icon(
          Icons.chevron_left,
          color: AppTheme.primary,
        ),
        rightChevronIcon: const Icon(
          Icons.chevron_right,
          color: AppTheme.primary,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
        ),
      ),

      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: AppTheme.textColor.withValues(alpha: 0.55),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        weekendStyle: TextStyle(
          color: AppTheme.textColor.withValues(alpha: 0.45),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
