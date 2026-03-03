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
  DateTime _selectedDate = DateTime.now();

  List<Session> _sessionsForDate(List<Session> all) {
    return all.where((s) =>
      s.startsAt.year == _selectedDate.year &&
      s.startsAt.month == _selectedDate.month &&
      s.startsAt.day == _selectedDate.day
    ).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
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
              TextFormField(controller: capCtrl, decoration: const InputDecoration(labelText: 'Capacity'), keyboardType: TextInputType.number, validator: (v) => int.tryParse(v ?? '') == null ? 'Enter valid number' : null),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time),
                label: Text(startDT == null ? 'Select Start Time' : DateFormat('dd MMM HH:mm').format(startDT!)),
                onPressed: () async {
                  final date = await showDatePicker(context: ctx, initialDate: _selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (date == null) return;
                  final time = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 9, minute: 0));
                  if (time == null) return;
                  setSt(() {
                    startDT = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                    endDT = startDT!.add(const Duration(hours: 1));
                  });
                },
              ),
              if (startDT != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.access_time_filled),
                  label: Text(endDT == null ? 'Select End Time' : DateFormat('HH:mm').format(endDT!)),
                  onPressed: () async {
                    final time = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: endDT?.hour ?? startDT!.hour + 1, minute: 0));
                    if (time == null) return;
                    setSt(() => endDT = DateTime(startDT!.year, startDT!.month, startDT!.day, time.hour, time.minute));
                  },
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate() || startDT == null || endDT == null) return;
                await _service.createSession(startsAt: startDT!, endsAt: endDT!, capacity: int.parse(capCtrl.text));
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
        content: Text('Creates 8 sessions/day Mon-Fri for week of ${DateFormat('dd MMM yyyy').format(monday)}.\n\nMorning: 09:00–13:00\nEvening: 17:00–21:00\nCapacity: 6'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (confirmed != true) return;
    for (int d = 0; d < 5; d++) {
      final day = monday.add(Duration(days: d));
      for (int h = 9; h < 13; h++) {
        final s = DateTime(day.year, day.month, day.day, h);
        await _service.createSession(startsAt: s, endsAt: s.add(const Duration(hours: 1)), capacity: 6);
      }
      for (int h = 17; h < 21; h++) {
        final s = DateTime(day.year, day.month, day.day, h);
        await _service.createSession(startsAt: s, endsAt: s.add(const Duration(hours: 1)), capacity: 6);
      }
    }
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Default week sessions created!')));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sessions').orderBy('startsAt').snapshots(),
      builder: (context, snapshot) {
        final allSessions = <Session>[];
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            try { allSessions.add(Session.fromFirestore(doc)); } catch (_) {}
          }
        }
        final liveDates = <DateTime>{};
        for (final s in allSessions) {
          if (s.active) liveDates.add(DateTime(s.startsAt.year, s.startsAt.month, s.startsAt.day));
        }
        final todaysSessions = _sessionsForDate(allSessions);

        return Scaffold(
          body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                const Text('Sessions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Default Week'),
                  onPressed: () => _createDefaultWeek(context),
                ),
              ]),
            ),
            _AdminCalendar(
              selectedDate: _selectedDate,
              datesWithSessions: liveDates,
              onDateSelected: (d) => setState(() => _selectedDate = d),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(DateFormat('EEEE, dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            if (!snapshot.hasData)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (todaysSessions.isEmpty)
              const Expanded(child: Center(child: Text('No sessions on this day.', style: TextStyle(color: Colors.grey))))
            else Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                itemCount: todaysSessions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = todaysSessions[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: s.active ? Colors.green.shade100 : Colors.grey.shade200,
                      child: Text(DateFormat.Hm().format(s.startsAt), style: const TextStyle(fontSize: 11)),
                    ),
                    title: Text('${DateFormat.Hm().format(s.startsAt)} – ${DateFormat.Hm().format(s.endsAt)}'),
                    subtitle: Text('Capacity: ${s.capacity}  |  Booked: ${s.bookedCount}'),
                    trailing: s.active
                        ? IconButton(icon: const Icon(Icons.block, color: Colors.red), tooltip: 'Deactivate', onPressed: () => _service.deactivateSession(s.id))
                        : const Chip(label: Text('Inactive'), backgroundColor: Colors.black12),
                  );
                },
              ),
            ),
          ]),
          floatingActionButton: FloatingActionButton(onPressed: () => _showCreateDialog(context), child: const Icon(Icons.add)),
        );
      },
    );
  }
}

class _AdminCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final Set<DateTime> datesWithSessions;
  final ValueChanged<DateTime> onDateSelected;
  const _AdminCalendar({required this.selectedDate, required this.datesWithSessions, required this.onDateSelected});
  @override
  State<_AdminCalendar> createState() => _AdminCalendarState();
}

class _AdminCalendarState extends State<_AdminCalendar> {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _displayMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_displayMonth.year, _displayMonth.month);
    final firstWeekday = DateTime(_displayMonth.year, _displayMonth.month, 1).weekday;
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
            color: isSelected ? Theme.of(context).primaryColor : isToday ? Theme.of(context).primaryColor.withOpacity(0.15) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day', style: TextStyle(
              color: isSelected ? Colors.white : hasSessions ? Colors.black87 : Colors.grey.shade400,
              fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            )),
            if (hasSessions) Container(width: 5, height: 5, decoration: BoxDecoration(color: isSelected ? Colors.white70 : Colors.green, shape: BoxShape.circle)),
          ]),
        ),
      ));
    }
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1))),
        Text(DateFormat('MMMM yyyy').format(_displayMonth), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1))),
      ]),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          children: ['M','T','W','T','F','S','S'].map((d) => Center(child: Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)))).toList()),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.1, children: cells),
      ),
    ]);
  }
}