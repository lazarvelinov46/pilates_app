import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/session_model.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';

class _AttendeeInfo {
  final Booking booking;
  final String name;
  final String surname;
  final String email;

  _AttendeeInfo({
    required this.booking,
    required this.name,
    required this.surname,
    required this.email,
  });

  String get fullName => '$name $surname';
  String get initials =>
      '${name.isNotEmpty ? name[0] : ''}${surname.isNotEmpty ? surname[0] : ''}'
          .toUpperCase();
}

class AdminSessionAttendeesScreen extends StatefulWidget {
  final Session session;

  const AdminSessionAttendeesScreen({super.key, required this.session});

  @override
  State<AdminSessionAttendeesScreen> createState() =>
      _AdminSessionAttendeesScreenState();
}

class _AdminSessionAttendeesScreenState
    extends State<AdminSessionAttendeesScreen> {
  final BookingService _bookingService = BookingService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<List<Booking>>? _bookingsSub;
  List<_AttendeeInfo> _attendees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bookingsSub = _bookingService
        .getBookingsForSession(widget.session.id)
        .listen(_onBookingsUpdated);
  }

  Future<void> _onBookingsUpdated(List<Booking> bookings) async {
    if (!mounted) return;

    if (bookings.isEmpty) {
      setState(() {
        _attendees = [];
        _loading = false;
      });
      return;
    }

    // Fetch all user docs in parallel.
    final userFutures = bookings.map((b) async {
      try {
        final doc = await _db.collection('users').doc(b.userId).get();
        final data = doc.data();
        if (data == null) return null;
        return _AttendeeInfo(
          booking: b,
          name: data['name'] ?? '',
          surname: data['surname'] ?? '',
          email: data['email'] ?? '',
        );
      } catch (_) {
        return null;
      }
    });

    final results = await Future.wait(userFutures);
    if (!mounted) return;

    setState(() {
      _attendees = results.whereType<_AttendeeInfo>().toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      _loading = false;
    });
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final session = widget.session;
    final isPast = session.startsAt.isBefore(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEE, dd MMM yyyy').format(session.startsAt),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              '${DateFormat.Hm().format(session.startsAt)} – ${DateFormat.Hm().format(session.endsAt)}',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Summary banner ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: cs.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(Icons.group_outlined, color: cs.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  _loading
                      ? 'Loading attendees…'
                      : '${_attendees.length} of ${session.capacity} '
                          '${_attendees.length == 1 ? 'attendee' : 'attendees'} booked',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (isPast) ...[
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.outline.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Completed',
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Attendees list ───────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _attendees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group_off_outlined,
                                size: 56,
                                color: cs.onSurface.withOpacity(0.25)),
                            const SizedBox(height: 12),
                            Text(
                              'No bookings for this session',
                              style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _attendees.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _AttendeeCard(attendee: _attendees[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _AttendeeCard extends StatelessWidget {
  final _AttendeeInfo attendee;
  const _AttendeeCard({required this.attendee});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Initials avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: cs.primaryContainer,
              child: Text(
                attendee.initials,
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Name + email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attendee.fullName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attendee.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Booking time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 16, color: cs.primary),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM').format(attendee.booking.createdAt),
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurface.withOpacity(0.45)),
                ),
                Text(
                  DateFormat('HH:mm').format(attendee.booking.createdAt),
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurface.withOpacity(0.45)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}