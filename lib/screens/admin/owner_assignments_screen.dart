import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/promotion_assignment_model.dart';
import '../../theme.dart';

class OwnerAssignmentsScreen extends StatefulWidget {
  const OwnerAssignmentsScreen({super.key});

  @override
  State<OwnerAssignmentsScreen> createState() => _OwnerAssignmentsScreenState();
}

class _OwnerAssignmentsScreenState extends State<OwnerAssignmentsScreen> {
  DateTime _selectedDate = DateTime.now();

  List<PromotionAssignment> _assignmentsForDate(
      List<PromotionAssignment> all, DateTime date) {
    return all
        .where((a) =>
            a.assignedAt.year == date.year &&
            a.assignedAt.month == date.month &&
            a.assignedAt.day == date.day)
        .toList()
      ..sort((a, b) => a.assignedAt.compareTo(b.assignedAt));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('promotion_assignments')
          .orderBy('assignedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final all = snapshot.hasData
            ? snapshot.data!.docs
                .map((d) => PromotionAssignment.fromFirestore(d))
                .toList()
            : <PromotionAssignment>[];

        final datesWithAssignments = all.map((a) {
          final d = a.assignedAt;
          return DateTime(d.year, d.month, d.day);
        }).toSet();

        final forDate = _assignmentsForDate(all, _selectedDate);
        final selectedHasAssignments =
            datesWithAssignments.contains(DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        ));

        return Scaffold(
          body: Column(children: [
            _OwnerCalendar(
              selectedDate: _selectedDate,
              datesWithAssignments: datesWithAssignments,
              onDateSelected: (date) => setState(() => _selectedDate = date),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(children: [
                Text(
                  selectedHasAssignments
                      ? '${forDate.length} assignment${forDate.length == 1 ? '' : 's'}'
                      : 'No assignments',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ]),
            ),
            const Divider(height: 1),
            if (snapshot.connectionState == ConnectionState.waiting && all.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (!selectedHasAssignments)
              Expanded(
                child: Center(
                  child: Text(
                    'No assignments on this date',
                    style: TextStyle(
                        color: AppTheme.textColor.withValues(alpha: 0.45)),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: forDate.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _AssignmentTile(assignment: forDate[i]),
                ),
              ),
          ]),
        );
      },
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  final PromotionAssignment assignment;
  const _AssignmentTile({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(assignment.assignedAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
          child: Text(
            timeStr,
            style: TextStyle(fontSize: 10, color: AppTheme.primary),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assignment.targetUserName,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                assignment.targetUserEmail,
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textColor.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.card_giftcard_outlined,
                    size: 13,
                    color: AppTheme.textColor.withValues(alpha: 0.55)),
                const SizedBox(width: 4),
                Text(
                  '${assignment.packageName} · ${assignment.numberOfSessions} sessions',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textColor.withValues(alpha: 0.55)),
                ),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.person_outline,
                    size: 13,
                    color: AppTheme.textColor.withValues(alpha: 0.45)),
                const SizedBox(width: 4),
                Text(
                  'By ${assignment.assignedByName}',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textColor.withValues(alpha: 0.45)),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _OwnerCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final Set<DateTime> datesWithAssignments;
  final ValueChanged<DateTime> onDateSelected;

  const _OwnerCalendar({
    required this.selectedDate,
    required this.datesWithAssignments,
    required this.onDateSelected,
  });

  @override
  State<_OwnerCalendar> createState() => _OwnerCalendarState();
}

class _OwnerCalendarState extends State<_OwnerCalendar> {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _displayMonth =
        DateTime(widget.selectedDate.year, widget.selectedDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateUtils.getDaysInMonth(_displayMonth.year, _displayMonth.month);
    final firstWeekday =
        DateTime(_displayMonth.year, _displayMonth.month, 1).weekday;
    final cells = <Widget>[];

    for (int i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayMonth.year, _displayMonth.month, day);
      final hasAssignments = widget.datesWithAssignments.contains(date);
      final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
      final isToday = DateUtils.isSameDay(date, DateTime.now());

      cells.add(GestureDetector(
        onTap: hasAssignments ? () => widget.onDateSelected(date) : null,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected && hasAssignments
                ? AppTheme.primary
                : isToday && hasAssignments
                    ? AppTheme.secondary
                    : null,
            shape: BoxShape.circle,
          ),
          child: Stack(alignment: Alignment.center, children: [
            Text(
              '$day',
              style: TextStyle(
                fontWeight:
                    isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                color: isSelected && hasAssignments
                    ? Colors.white
                    : hasAssignments
                        ? null
                        : AppTheme.textColor.withValues(alpha: 0.25),
                fontSize: 13,
              ),
            ),
            if (hasAssignments && !isSelected)
              Positioned(
                bottom: 2,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ]),
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(children: [
        Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _displayMonth =
                DateTime(_displayMonth.year, _displayMonth.month - 1)),
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(_displayMonth),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _displayMonth =
                DateTime(_displayMonth.year, _displayMonth.month + 1)),
          ),
        ]),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map((d) => Center(
                  child: Text(d,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textColor.withValues(alpha: 0.45)))))
              .toList(),
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
        ),
      ]),
    );
  }
}
