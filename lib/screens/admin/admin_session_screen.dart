import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/session_model.dart';
import '../../services/session_service.dart';

class AdminSessionsScreen extends StatelessWidget {
  const AdminSessionsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _AdminSessionsBody();
}

class _AdminSessionsBody extends StatefulWidget {
  const _AdminSessionsBody();
  @override
  State<_AdminSessionsBody> createState() => _AdminSessionsBodyState();
}

class _AdminSessionsBodyState extends State<_AdminSessionsBody> {
  final SessionService _service = SessionService();
  final ScrollController _scrollController = ScrollController();
  DateTime _selectedDate = DateTime.now();
  bool _calendarVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final shouldShow = _scrollController.offset < 20;
      if (shouldShow != _calendarVisible) {
        setState(() => _calendarVisible = shouldShow);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Session> _sessionsForDate(List<Session> all) {
    return all
        .where((s) =>
            s.startsAt.year == _selectedDate.year &&
            s.startsAt.month == _selectedDate.month &&
            s.startsAt.day == _selectedDate.day)
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  void _showCreateDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    DateTime? startDT;
    DateTime? endDT;
    final capCtrl = TextEditingController(text: '6');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Create Session'),
          content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: capCtrl,
                decoration: const InputDecoration(labelText: 'Capacity'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Enter valid number' : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time),
                label: Text(startDT == null
                    ? 'Select Start Time'
                    : DateFormat('dd MMM HH:mm').format(startDT!)),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: _selectedDate,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (time == null) return;
                  setSt(() {
                    startDT = DateTime(
                        date.year, date.month, date.day, time.hour, time.minute);
                    endDT = startDT!.add(const Duration(hours: 1));
                  });
                },
              ),
              if (startDT != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.access_time_filled),
                  label: Text(endDT == null
                      ? 'Select End Time'
                      : DateFormat('HH:mm').format(endDT!)),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(
                          hour: endDT?.hour ?? startDT!.hour + 1, minute: 0),
                    );
                    if (time == null) return;
                    setSt(() => endDT = DateTime(startDT!.year,
                        startDT!.month, startDT!.day, time.hour, time.minute));
                  },
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate() ||
                    startDT == null ||
                    endDT == null) return;
                await _service.createSession(
                    startsAt: startDT!,
                    endsAt: endDT!,
                    capacity: int.parse(capCtrl.text));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDefaultWeek(BuildContext context) async {
    final weekday = _selectedDate.weekday;
    final monday = _selectedDate.subtract(Duration(days: weekday - 1));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Default Week Sessions'),
        content: Text(
            'Creates 8 sessions/day Mon-Fri for week of ${DateFormat('dd MMM yyyy').format(monday)}.\n\nMorning: 09:00–13:00\nEvening: 17:00–21:00\nCapacity: 6'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (confirmed != true) return;
    for (int d = 0; d < 5; d++) {
      final day = monday.add(Duration(days: d));
      for (int h = 9; h < 13; h++) {
        final s = DateTime(day.year, day.month, day.day, h);
        await _service.createSession(
            startsAt: s, endsAt: s.add(const Duration(hours: 1)), capacity: 6);
      }
      for (int h = 17; h < 21; h++) {
        final s = DateTime(day.year, day.month, day.day, h);
        await _service.createSession(
            startsAt: s, endsAt: s.add(const Duration(hours: 1)), capacity: 6);
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default week sessions created!')));
    }
  }

  /// Shows a confirmation dialog before deactivating a session.
  /// Clearly states that booked users will be notified and credited.
  Future<void> _confirmDeactivate(BuildContext context, Session session) async {
    final bookedCount = session.bookedCount;
    final hasBookings = bookedCount > 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Session?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session on ${DateFormat('dd MMM • HH:mm').format(session.startsAt)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (hasBookings) ...[
              // Warn admin clearly — this action affects real users.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$bookedCount user${bookedCount == 1 ? '' : 's'} '
                        'will be notified and their session credit will be '
                        'automatically refunded.',
                        style: TextStyle(
                            color: Colors.orange.shade800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text('This action cannot be undone.'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Session')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Session',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await _service.deactivateSession(session.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasBookings
              ? 'Session cancelled. ${session.bookedCount} user${session.bookedCount == 1 ? '' : 's'} will be notified.'
              : 'Session cancelled.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .orderBy('startsAt')
          .snapshots(),
      builder: (context, snapshot) {
        final allSessions = snapshot.hasData
            ? snapshot.data!.docs
                .map((d) => Session.fromFirestore(d))
                .toList()
            : <Session>[];

        final todaysSessions = _sessionsForDate(allSessions);

        final datesWithSessions = allSessions.map((s) {
          final d = s.startsAt;
          return DateTime(d.year, d.month, d.day);
        }).toSet();

        return Scaffold(
          body: Column(children: [
            // Collapsible calendar
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: _calendarVisible
                  ? _AdminCalendar(
                      selectedDate: _selectedDate,
                      datesWithSessions: datesWithSessions,
                      onDateSelected: (date) {
                        setState(() => _selectedDate = date);
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut);
                        }
                      },
                    )
                  : const SizedBox.shrink(),
            ),

            // Collapsed date bar
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _calendarVisible
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      key: const ValueKey('admin-date-chip'),
                      onTap: () {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy')
                                  .format(_selectedDate),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            const Icon(Icons.expand_more, size: 16),
                          ],
                        ),
                      ),
                    ),
            ),

            // Action bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Text(
                    '${todaysSessions.length} session${todaysSessions.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Default week'),
                    onPressed: () => _createDefaultWeek(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            if (snapshot.connectionState == ConnectionState.waiting &&
                allSessions.isEmpty)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (todaysSessions.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No sessions on this date',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: todaysSessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = todaysSessions[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: s.active
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        child: Text(DateFormat.Hm().format(s.startsAt),
                            style: const TextStyle(fontSize: 11)),
                      ),
                      title: Text(
                          '${DateFormat.Hm().format(s.startsAt)} – ${DateFormat.Hm().format(s.endsAt)}'),
                      subtitle: Text(
                          'Capacity: ${s.capacity}  |  Booked: ${s.bookedCount}'),
                      trailing: !s.active
                          ? const Chip(
                              label: Text('Inactive'),
                              backgroundColor: Colors.black12)
                          : s.startsAt.isBefore(DateTime.now())
                              ? const Chip(
                                  label: Text('Completed'),
                                  backgroundColor: Colors.black12)
                              : IconButton(
                                  icon: const Icon(Icons.block, color: Colors.red),
                                  tooltip: 'Cancel session',
                                  onPressed: () => _confirmDeactivate(context, s)),
                    );
                  },
                ),
              ),
          ]),
          floatingActionButton: FloatingActionButton(
              onPressed: () => _showCreateDialog(context),
              child: const Icon(Icons.add)),
        );
      },
    );
  }
}

// ─── Custom inline calendar widget ───────────────────────────────────────────

class _AdminCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final Set<DateTime> datesWithSessions;
  final ValueChanged<DateTime> onDateSelected;

  const _AdminCalendar({
    required this.selectedDate,
    required this.datesWithSessions,
    required this.onDateSelected,
  });

  @override
  State<_AdminCalendar> createState() => _AdminCalendarState();
}

class _AdminCalendarState extends State<_AdminCalendar> {
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
    for (int i = 1; i < firstWeekday; i++) cells.add(const SizedBox());
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayMonth.year, _displayMonth.month, day);
      final hasSessions = widget.datesWithSessions.contains(date);
      final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
      final isToday = DateUtils.isSameDay(date, DateTime.now());
      cells.add(GestureDetector(
        onTap: () => widget.onDateSelected(date),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor
                : isToday
                    ? Theme.of(context).primaryColor.withOpacity(0.15)
                    : null,
            shape: BoxShape.circle,
          ),
          child: Stack(alignment: Alignment.center, children: [
            Text(
              '$day',
              style: TextStyle(
                fontWeight:
                    isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : null,
                fontSize: 13,
              ),
            ),
            if (hasSessions && !isSelected)
              Positioned(
                bottom: 2,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
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
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey))))
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