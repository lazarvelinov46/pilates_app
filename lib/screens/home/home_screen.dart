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
import '../../../services/notification_service.dart';
import '../../../services/session_service.dart';
import '../../../services/user_service.dart';
import '../../../services/rating_service.dart';
import '../../../theme.dart';
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
  final NotificationService _notificationService = NotificationService();
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

    await _userService.syncAttendedSessions(userId);

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
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
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
            backgroundColor: AppTheme.errorRed,
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
      await _notificationService.notifyBookingConfirmed(session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booked for ${DateFormat('EEE dd MMM • HH:mm').format(session.startsAt)}',
            ),
            backgroundColor: AppTheme.successGreen,
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
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _openCompletedSessionsSheet(BuildContext context, AppUser user, Promotion promotion) {
    final promoMs = promotion.createdAt.millisecondsSinceEpoch;
    final isLegacyPromo = promotion.createdAt == DateTime(2000);

    final filtered = _completedBookings.where((b) {
      if (b.promotionCreatedAt != null) {
        return b.promotionCreatedAt!.millisecondsSinceEpoch == promoMs;
      }
      return isLegacyPromo;
    }).toList();

    showCompletedSessionsSheet(
      context: context,
      completedBookings: filtered,
      ratingsMap: _ratingsMap,
      user: user,
      onRatingSubmitted: _onRatingSubmitted,
    );
  }

  Future<void> _openRateDialogForBooking(
      BuildContext context, Booking booking, AppUser user) async {
    final rating = await showRateSessionDialog(
      context: context,
      booking: booking,
      user: user,
    );
    if (rating != null) _onRatingSubmitted(rating);
  }

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
          return StreamBuilder<List<Booking>>(
            stream: _bookingService.getUpcomingBookingsStream(userId),
            builder: (context, activeSnap) {
              return StreamBuilder<List<Booking>>(
                stream: _bookingService.getAdminCancelledUpcomingStream(userId),
                builder: (context, cancelledSnap) {
                  final activeBookings    = activeSnap.data ?? [];
                  final cancelledBookings = cancelledSnap.data ?? [];

                  final upcomingBookings = [...activeBookings, ...cancelledBookings]
                    ..sort((a, b) => a.sessionStartsAt.compareTo(b.sessionStartsAt));

                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        _buildPromotionSection(context, user),

                        if (_completedBookings.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildLastCompletedSessionCard(context, user),
                        ],

                        const SizedBox(height: 24),

                        if (upcomingBookings.isNotEmpty) ...[
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
                                    onCancel: b.status == BookingStatus.active
                                        ? () => _cancelBooking(b)
                                        : null,
                                  ))
                              .toList(),
                        ] else if (!user.hasActivePromotion && user.trialSessionUsed) ...[
                          _buildNoPromotionBanner(context, user),
                        ] else ...[
                          if (!user.hasActivePromotion) ...[
                            const _TrialBookingBanner(),
                            const SizedBox(height: 12),
                          ],
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
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You have no sessions booked yet.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall,
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
                                      alreadyBooked: _bookedSessionIds.contains(s.id),
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
          );
        },
      ),
    );
  }

  // ── Promotion section ─────────────────────────────────────────────────────

  Widget _buildPromotionSection(BuildContext context, AppUser user) {
    final activePromos = user.sortedPromotions.where((p) => p.attended < p.totalSessions).toList();

    final inactivePromos = user.sortedPromotions
        .where((p) => p.attended >= p.totalSessions)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final legacyHistory = user.promotionHistory;

    if (activePromos.isNotEmpty) {
      return Column(
        children: activePromos.map((promo) {
          final promoMs = promo.createdAt.millisecondsSinceEpoch;
          final hasCompletedForThisPromo =
              promo.attended > 0 ||
              _completedBookings.any((b) =>
                  b.promotionCreatedAt != null &&
                  b.promotionCreatedAt!.millisecondsSinceEpoch == promoMs);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPromotionCard(
              context,
              promo,
              onTap: hasCompletedForThisPromo
                  ? () => _openCompletedSessionsSheet(context, user, promo)
                  : null,
              isHistory: false,
            ),
          );
        }).toList(),
      );
    }

    if (user.trialSessionUsed) {
      return _TrialSessionCard();
    }

    Promotion? fallback;
    if (inactivePromos.isNotEmpty) {
      fallback = inactivePromos.first;
    } else if (legacyHistory.isNotEmpty) {
      fallback = legacyHistory.last;
    }

    if (fallback != null) {
      return _buildPromotionCard(
        context,
        fallback,
        onTap: null,
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
        ? AppTheme.surfaceContainerHigh
        : colorScheme.primaryContainer;

    final barColor = isInactive
        ? AppTheme.outline
        : colorScheme.primary;

    Widget card = Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: onTap != null
            ? Border.all(
                color: colorScheme.primary.withValues(alpha: 0.35),
                width: 1.5,
              )
            : Border.all(color: AppTheme.outlineVariant),
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
                _StatusBadge(
                    label: 'Completed',
                    color: AppTheme.historySlate,
                    bgColor: AppTheme.historySlateContainer)
              else if (isExpired)
                _StatusBadge(
                    label: 'Expired',
                    color: AppTheme.errorRed,
                    bgColor: AppTheme.errorRedContainer)
              else if (isExhausted)
                _StatusBadge(
                    label: 'Used up',
                    color: AppTheme.warningOrange,
                    bgColor: AppTheme.warningOrangeContainer)
              else
                _StatusBadge(
                  label: '${promotion.remaining} left',
                  color: AppTheme.successGreen,
                  bgColor: AppTheme.successGreenContainer,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Expires ${DateFormat('dd MMM yyyy').format(promotion.expiresAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: (!isHistory && isExpired)
                      ? AppTheme.errorRed
                      : AppTheme.textColor.withValues(alpha: 0.55),
                ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fillPercent.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppTheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$used / $total sessions used',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (!isInactive)
                Text(
                  '$attended attended · $booked upcoming',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                          color: AppTheme.textColor.withValues(alpha: 0.55)),
                ),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }

    return card;
  }

  // ── Last completed session card ───────────────────────────────────────────

  Widget _buildLastCompletedSessionCard(BuildContext context, AppUser user) {
    final last = _completedBookings.first;
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
                ? AppTheme.successGreenContainer
                : Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRated
                  ? AppTheme.successGreen.withValues(alpha: 0.35)
                  : AppTheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isRated
                      ? AppTheme.successGreen.withValues(alpha: 0.15)
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: isRated
                      ? AppTheme.successGreen
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
                          fontSize: 13,
                          color: AppTheme.textColor.withValues(alpha: 0.55)),
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
                    color: AppTheme.successGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Rated',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successGreen,
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

  Widget _buildNoPromotionBanner(BuildContext context, AppUser user) {
    if (user.hasActivePromotion) return const SizedBox.shrink();

    final msg = user.promotions.isNotEmpty
        ? user.promotions.any((p) => p.isExpired && p.remaining > 0)
            ? 'Your promotion has expired.'
            : 'You have used all sessions in your promotions.'
        : 'You have no active promotion.';

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
            color: AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.local_activity_outlined,
                    size: 40,
                    color: AppTheme.textColor.withValues(alpha: 0.35)),
                const SizedBox(height: 12),
                Text(msg,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textColor.withValues(alpha: 0.55))),
                const SizedBox(height: 4),
                Text('Contact us to get a new promotion.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textColor.withValues(alpha: 0.4),
                        fontSize: 12)),
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
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.local_activity_outlined,
              size: 36,
              color: AppTheme.textColor.withValues(alpha: 0.35)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No active promotion',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor.withValues(alpha: 0.55))),
                const SizedBox(height: 4),
                Text('Contact us to purchase a session package.',
                    style: TextStyle(
                        color: AppTheme.textColor.withValues(alpha: 0.5),
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrialSessionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.secondary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.card_giftcard_outlined,
                color: cs.secondary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trial session booked',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.secondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Contact the studio to purchase a package — '
                  'your trial session will be counted as the first one.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                          color: AppTheme.textColor.withValues(alpha: 0.65)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrialBookingBanner extends StatelessWidget {
  const _TrialBookingBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cs.secondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No active promotion — you can book 1 free trial session.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textColor.withValues(alpha: 0.8),
                  ),
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
  final Color bgColor;
  const _StatusBadge(
      {required this.label, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onCancel;

  const _BookingTile({required this.booking, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final isCancelledByAdmin =
        booking.status == BookingStatus.cancelledByAdmin;
    final canCancel = booking.canCancel();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCancelledByAdmin
            ? AppTheme.errorRedContainer.withValues(alpha: 0.5)
            : Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCancelledByAdmin
              ? AppTheme.errorRed.withValues(alpha: 0.25)
              : AppTheme.outlineVariant,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(
          isCancelledByAdmin
              ? Icons.cancel_outlined
              : Icons.fitness_center_rounded,
          color: isCancelledByAdmin
              ? AppTheme.errorRed
              : AppTheme.primary,
        ),
        title: Text(
          booking.formattedDateTime,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isCancelledByAdmin ? AppTheme.errorRed : null,
          ),
        ),
        subtitle: Text(
          isCancelledByAdmin
              ? 'Cancelled by studio — credit refunded'
              : canCancel
                  ? 'Cancel up to 12h before'
                  : 'Cancellation window passed',
          style: TextStyle(
            fontSize: 12,
            color: isCancelledByAdmin
                ? AppTheme.errorRed.withValues(alpha: 0.7)
                : AppTheme.textColor.withValues(alpha: 0.5),
          ),
        ),
        trailing: isCancelledByAdmin
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.errorRedContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Cancelled',
                  style: TextStyle(
                      color: AppTheme.errorRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              )
            : canCancel
                ? TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorRed),
                    child: const Text('Cancel'),
                  )
                : Text('Locked',
                    style: TextStyle(
                        color: AppTheme.textColor.withValues(alpha: 0.4),
                        fontSize: 13)),
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
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          'No upcoming sessions available right now.',
          style: TextStyle(
              color: AppTheme.textColor.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
