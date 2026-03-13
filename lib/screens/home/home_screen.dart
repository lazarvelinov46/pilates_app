import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../models/user_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/session_model.dart';
import '../../../models/rating_model.dart';
import '../../../models/promotion_model.dart';
import '../../../services/booking_service.dart';
import '../../../services/session_service.dart';
import '../../../services/user_service.dart';
import '../../../services/rating_service.dart';
import '../booking/widgets/session_card.dart';
import 'widgets/completed_sessions_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final UserService _userService = UserService();
  final BookingService _bookingService = BookingService();
  final SessionService _sessionService = SessionService();
  final RatingService _ratingService = RatingService();

  List<Session> _upcomingSessions = [];
  Set<String> _bookedSessionIds = {};
  List<Booking> _completedBookings = [];
  Map<String, SessionRating> _ratingsMap = {};
  bool _loadingQuickBook = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loadingQuickBook = true);

    final results = await Future.wait([
      _sessionService.getUpcomingSessions(limit: 3),
      _bookingService.getUserActiveBookings(userId),
      _bookingService.getCompletedBookingsForUser(userId),
      _ratingService.getUserRatingsMap(userId),
    ]);

    if (!mounted) return;
    setState(() {
      _upcomingSessions = results[0] as List<Session>;
      _bookedSessionIds = results[1] as Set<String>;
      _completedBookings = results[2] as List<Booking>;
      _ratingsMap = results[3] as Map<String, SessionRating>;
      _loadingQuickBook = false;
    });
  }

  void _onRatingSubmitted(SessionRating rating) {
    setState(() => _ratingsMap[rating.sessionId] = rating);
  }

  Future<void> _cancelBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel session?'),
        content: Text(
          'Are you sure you want to cancel your session on '
          '${booking.formattedDateTime}?\n\n'
          '${booking.canCancel() ? 'Your session credit will be returned to your promotion.' : 'Note: cancellation is within 12 hours of the session — your credit will NOT be refunded.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _bookingService.cancelBooking(booking: booking);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _quickBook(Session session) async {
    try {
      await _bookingService.bookSession(
        userId: userId,
        sessionId: session.id,
      );
      setState(() => _bookedSessionIds.add(session.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booked for ${DateFormat('EEE dd MMM • HH:mm').format(session.startsAt)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Booking failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Open completed sessions sheet ─────────────────────────────────────────

  void _openCompletedSessionsSheet(BuildContext context, AppUser user) {
    showCompletedSessionsSheet(
      context: context,
      completedBookings: _completedBookings,
      ratingsMap: _ratingsMap,
      user: user,
      onRatingSubmitted: _onRatingSubmitted,
    );
  }

  // ── Rate from last-session card ───────────────────────────────────────────

  Future<void> _openRateDialogForBooking(
      BuildContext context, Booking booking, AppUser user) async {
    final rating = await showRateSessionDialog(
      context: context,
      booking: booking,
      user: user,
    );
    if (rating != null) _onRatingSubmitted(rating);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: StreamBuilder<AppUser>(
        stream: _userService.getUserStream(userId),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = userSnap.data;
          if (user == null) {
            return const Center(child: Text('Unable to load profile'));
          }

          final promotion = user.promotion;

          return StreamBuilder<List<Booking>>(
            stream: _bookingService.getUpcomingBookingsStream(userId),
            builder: (context, bookingSnap) {
              final upcomingBookings = bookingSnap.data ?? [];

              return RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // ── Promotion / history card ────────────────────────
                    _buildPromotionSection(context, user),

                    // ── Last completed session ──────────────────────────
                    if (_completedBookings.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildLastCompletedSessionCard(context, user),
                    ],

                    const SizedBox(height: 24),

                    // ── Booking section ─────────────────────────────────
                    if (promotion == null ||
                        promotion.isExpired ||
                        promotion.remaining <= 0) ...[
                      _buildNoPromotionBanner(context, promotion),
                    ] else if (upcomingBookings.isNotEmpty) ...[
                      Text(
                        'Your upcoming sessions',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...upcomingBookings
                          .map((b) => _BookingTile(
                                booking: b,
                                onCancel: () => _cancelBooking(b),
                              ))
                          .toList(),
                    ] else ...[
                      Row(
                        children: [
                          Text(
                            'Quick book',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: const Text('Upcoming sessions'),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You have no sessions booked yet.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      if (_loadingQuickBook)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_upcomingSessions.isEmpty)
                        const _EmptySessionsCard()
                      else
                        ..._upcomingSessions
                            .map((s) => SessionCard(
                                  session: s,
                                  alreadyBooked:
                                      _bookedSessionIds.contains(s.id),
                                  isCancelled: false,
                                  onBook: () => _quickBook(s),
                                ))
                            .toList(),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Promotion section (current or last history) ───────────────────────────

  Widget _buildPromotionSection(BuildContext context, AppUser user) {
    final promotion = user.promotion;
    final hasCompleted = _completedBookings.isNotEmpty;

    if (promotion != null) {
      return _buildPromotionCard(
        context,
        promotion,
        onTap: hasCompleted
            ? () => _openCompletedSessionsSheet(context, user)
            : null,
        isHistory: false,
      );
    }

    if (user.promotionHistory.isNotEmpty) {
      final lastPromo = user.promotionHistory.last;
      return _buildPromotionCard(
        context,
        lastPromo,
        onTap: hasCompleted
            ? () => _openCompletedSessionsSheet(context, user)
            : null,
        isHistory: true,
      );
    }

    return _NoPromotionCard();
  }

  Widget _buildPromotionCard(
    BuildContext context,
    Promotion promotion, {
    VoidCallback? onTap,
    required bool isHistory,
  }) {
    final total = promotion.totalSessions;
    final booked = promotion.booked;
    final attended = promotion.attended;
    final used = booked + attended;
    final fillPercent = total > 0 ? used / total : 0.0;

    final colorScheme = Theme.of(context).colorScheme;
    final isExpired = promotion.isExpired;
    final isExhausted = promotion.remaining <= 0;
    final isInactive = isExpired || isExhausted || isHistory;

    final cardColor = isInactive
        ? Colors.grey.shade200
        : colorScheme.primaryContainer;

    final barColor =
        isInactive ? Colors.grey : colorScheme.primary;

    Widget card = Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: onTap != null
            ? Border.all(
                color: colorScheme.primary.withOpacity(0.4),
                width: 1.5,
              )
            : null,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  promotion.packageName,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (isHistory)
                _StatusBadge(label: 'Completed', color: Colors.blueGrey)
              else if (isExpired)
                _StatusBadge(label: 'Expired', color: Colors.red)
              else if (isExhausted)
                _StatusBadge(label: 'Used up', color: Colors.orange)
              else
                _StatusBadge(
                  label: '${promotion.remaining} left',
                  color: Colors.green,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Expires ${DateFormat('dd MMM yyyy').format(promotion.expiresAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: (!isHistory && isExpired)
                      ? Colors.red.shade700
                      : Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fillPercent.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.5),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$used / $total sessions used',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              if (onTap != null) ...[
                const Spacer(),
                Text(
                  'View sessions',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right,
                    size: 16, color: colorScheme.primary),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }

  // ── Last completed session card ───────────────────────────────────────────

  Widget _buildLastCompletedSessionCard(
      BuildContext context, AppUser user) {
    final last = _completedBookings.first; // sorted newest-first
    final existingRating = _ratingsMap[last.sessionId];
    final isRated = existingRating != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last session',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: isRated
                ? Colors.green.shade50
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRated
                  ? Colors.green.shade200
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isRated
                      ? Colors.green.shade100
                      : Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: isRated
                      ? Colors.green.shade700
                      : Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEE, dd MMM yyyy')
                          .format(last.sessionStartsAt),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      DateFormat('HH:mm').format(last.sessionStartsAt),
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600),
                    ),
                    if (isRated) ...[
                      const SizedBox(height: 4),
                      StarRow(rating: existingRating.rating, size: 14),
                    ],
                  ],
                ),
              ),
              if (isRated)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Rated',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.star_outline, size: 16),
                  label: const Text('Rate'),
                  onPressed: () =>
                      _openRateDialogForBooking(context, last, user),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── No-promotion banner ───────────────────────────────────────────────────

  Widget _buildNoPromotionBanner(
      BuildContext context, Promotion? promotion) {
    final msg = promotion == null
        ? 'You have no active promotion.'
        : promotion.isExpired
            ? 'Your promotion has expired.'
            : 'You have used all sessions in your promotion.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sessions',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.local_activity_outlined,
                    size: 40, color: Colors.grey),
                const SizedBox(height: 12),
                Text(msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                const Text('Contact us to get a new promotion.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _NoPromotionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.local_activity_outlined,
              size: 36, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No active promotion',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 4),
                const Text('Contact us to purchase a session package.',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Booking booking;
  final VoidCallback onCancel;

  const _BookingTile({required this.booking, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final canCancel = booking.canCancel();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.fitness_center,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.formattedDateTime,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    canCancel
                        ? 'Cancellable until 12h before'
                        : 'Cancellation window has passed',
                    style: TextStyle(
                      fontSize: 12,
                      color: canCancel
                          ? Colors.grey.shade600
                          : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: canCancel ? onCancel : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                disabledForegroundColor: Colors.grey,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySessionsCard extends StatelessWidget {
  const _EmptySessionsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'No upcoming sessions available right now.',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}