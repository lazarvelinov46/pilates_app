import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/session_model.dart';
import '../../services/session_service.dart';
import '../../theme.dart';
import '../../l10n/app_localizations.dart';
import 'admin_session_attendees_screen.dart';

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
        builder: (ctx, setSt) {
          final dl10n = AppLocalizations.of(ctx);
          return AlertDialog(
            title: Text(dl10n.createSessionTitle),
            content: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: capCtrl,
                  decoration: InputDecoration(labelText: dl10n.capacityLabel),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? dl10n.enterValidNumber : null,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: Text(startDT == null
                      ? dl10n.selectStartTime
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
                      startDT = DateTime(date.year, date.month, date.day,
                          time.hour, time.minute);
                      endDT = startDT!.add(const Duration(hours: 1));
                    });
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.access_time_filled),
                  label: Text(endDT == null
                      ? dl10n.selectEndTime
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
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(dl10n.cancelButton)),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate() ||
                      startDT == null ||
                      endDT == null) return;
                  if (!endDT!.isAfter(startDT!)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(dl10n.endTimeAfterStart)),
                    );
                    return;
                  }
                  try {
                    await _service.createSession(
                        startsAt: startDT!,
                        endsAt: endDT!,
                        capacity: int.parse(capCtrl.text));
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                              e.toString().replaceFirst('Exception: ', '')),
                          backgroundColor: AppTheme.errorRed,
                        ),
                      );
                    }
                  }
                },
                child: Text(dl10n.createButton),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createDefaultWeek(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final weekday = _selectedDate.weekday;
    final monday = _selectedDate.subtract(Duration(days: weekday - 1));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.createDefaultWeekTitle),
        content: Text(l10n.createDefaultWeekBody(
            DateFormat('dd MMM yyyy').format(monday))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancelButton)),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.createButton)),
        ],
      ),
    );
    if (confirmed != true) return;
    int skipped = 0;
    for (int d = 0; d < 5; d++) {
      final day = monday.add(Duration(days: d));
      for (int h = 9; h < 13; h++) {
        final s = DateTime(day.year, day.month, day.day, h);
        try {
          await _service.createSession(
              startsAt: s,
              endsAt: s.add(const Duration(hours: 1)),
              capacity: 6);
        } catch (_) {
          skipped++;
        }
      }
      for (int h = 17; h < 21; h++) {
        final s = DateTime(day.year, day.month, day.day, h);
        try {
          await _service.createSession(
              startsAt: s,
              endsAt: s.add(const Duration(hours: 1)),
              capacity: 6);
        } catch (_) {
          skipped++;
        }
      }
    }
    if (context.mounted) {
      final msg = skipped == 0
          ? l10n.defaultWeekCreated
          : l10n.defaultWeekSkipped(skipped);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _confirmDeactivate(BuildContext context, Session session) async {
    final l10n = AppLocalizations.of(context);
    final bookedCount = session.bookedCount;
    final hasBookings = bookedCount > 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.cancelSessionAdminTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sessionOnDate(
                  DateFormat('dd MMM • HH:mm').format(session.startsAt)),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (hasBookings) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrangeContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.warningOrange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.warningOrange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.usersWillBeRefunded(bookedCount),
                        style: const TextStyle(
                            color: AppTheme.warningOrange, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(l10n.thisActionCannotBeUndone),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.keepSessionButton)),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cancelSessionButton,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await _service.cancelSessionByAdmin(session.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasBookings
              ? l10n.sessionCancelledWithRefund(session.bookedCount)
              : l10n.sessionCancelledSimple),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            const Icon(Icons.expand_more, size: 16),
                          ],
                        ),
                      ),
                    ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Text(
                    l10n.sessionCount(todaysSessions.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(l10n.defaultWeekButton),
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
              Expanded(
                child: Center(
                  child: Text(l10n.noSessionsOnThisDate,
                      style: TextStyle(
                          color:
                              AppTheme.textColor.withValues(alpha: 0.45))),
                ),
              )
            else
              Expanded(
                child: NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (notification.direction == ScrollDirection.reverse) {
                      if (_calendarVisible)
                        setState(() => _calendarVisible = false);
                    } else if (notification.direction ==
                        ScrollDirection.forward) {
                      if (!_calendarVisible &&
                          _scrollController.offset < 20) {
                        setState(() => _calendarVisible = true);
                      }
                    }
                    return false;
                  },
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: todaysSessions.length,
                    separatorBuilder: (context, i) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = todaysSessions[i];
                      final isPast = s.startsAt.isBefore(DateTime.now());
                      final hasBookings = s.bookedCount > 0;
                      final cs = Theme.of(context).colorScheme;

                      Widget trailingWidget;
                      if (!s.active) {
                        trailingWidget = Chip(
                          label: Text(l10n.inactive),
                          backgroundColor: AppTheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textColor
                                  .withValues(alpha: 0.5)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        );
                      } else if (isPast) {
                        trailingWidget = Chip(
                          label: Text(l10n.completed),
                          backgroundColor: AppTheme.historySlateContainer,
                          labelStyle: TextStyle(
                              fontSize: 12,
                              color: AppTheme.historySlate),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        );
                      } else {
                        trailingWidget = IconButton(
                          icon: const Icon(Icons.block,
                              color: AppTheme.errorRed),
                          tooltip: l10n.cancelSessionTooltip,
                          onPressed: () =>
                              _confirmDeactivate(context, s),
                        );
                      }

                      return InkWell(
                        onTap: hasBookings
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AdminSessionAttendeesScreen(
                                            session: s),
                                  ),
                                )
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: s.active
                                    ? AppTheme.successGreenContainer
                                    : AppTheme.surfaceContainerHighest,
                                child: Text(
                                  DateFormat.Hm().format(s.startsAt),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${DateFormat.Hm().format(s.startsAt)} – ${DateFormat.Hm().format(s.endsAt)}',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          l10n.capacityBooked(
                                              s.capacity, s.bookedCount),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        if (hasBookings) ...[
                                          const SizedBox(width: 4),
                                          Icon(Icons.group,
                                              size: 13,
                                              color: cs.primary),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              trailingWidget,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ]),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showCreateDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

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
                ? AppTheme.primary
                : isToday
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
                  decoration: const BoxDecoration(
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
