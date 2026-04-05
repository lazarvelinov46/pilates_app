import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/session_model.dart';
import '../../../theme.dart';

class SessionCard extends StatelessWidget {
  final Session session;
  final bool alreadyBooked;

  /// True when the user had a booking for this session but cancelled it.
  final bool isCancelled;

  final VoidCallback onBook;

  const SessionCard({
    super.key,
    required this.session,
    required this.alreadyBooked,
    required this.isCancelled,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double fillPercent = session.bookedCount / session.capacity;
    final bool isFull = session.bookedCount >= session.capacity;

    // Derive the button label and whether it is enabled.
    final String buttonLabel;
    final bool buttonEnabled;
    final VoidCallback? buttonAction;

    if (isCancelled) {
      buttonLabel = 'Cancelled';
      buttonEnabled = false;
      buttonAction = null;
    } else if (alreadyBooked) {
      buttonLabel = 'Already Booked';
      buttonEnabled = false;
      buttonAction = null;
    } else if (isFull) {
      buttonLabel = 'Full';
      buttonEnabled = false;
      buttonAction = null;
    } else {
      buttonLabel = 'Book Session';
      buttonEnabled = true;
      buttonAction = onBook;
    }

    // Card styling based on state
    final Color cardColor = isCancelled
        ? AppTheme.errorRedContainer.withValues(alpha: 0.5)
        : colorScheme.surfaceContainerLowest;

    final Color borderColor = isCancelled
        ? AppTheme.errorRed.withValues(alpha: 0.3)
        : colorScheme.outlineVariant;

    final Color barColor = isFull
        ? AppTheme.errorRed.withValues(alpha: 0.6)
        : AppTheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: isCancelled
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date & time row ───────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? AppTheme.errorRedContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 18,
                    color: isCancelled
                        ? AppTheme.errorRed
                        : colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMMd().format(session.startsAt),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${DateFormat.Hm().format(session.startsAt)} – '
                        '${DateFormat.Hm().format(session.endsAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Capacity badge
                _CapacityBadge(
                  booked: session.bookedCount,
                  capacity: session.capacity,
                  isFull: isFull,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Progress bar ───────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fillPercent.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: AppTheme.outlineVariant,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),

            const SizedBox(height: 14),

            // ── Action button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: isCancelled
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: BorderSide(
                            color: AppTheme.errorRed.withValues(alpha: 0.4)),
                        disabledForegroundColor:
                            AppTheme.errorRed.withValues(alpha: 0.7),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancelled'),
                    )
                  : FilledButton(
                      onPressed: buttonEnabled ? buttonAction : null,
                      style: buttonEnabled
                          ? null
                          : FilledButton.styleFrom(
                              backgroundColor: colorScheme.surfaceContainerHigh,
                              foregroundColor: colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                              disabledBackgroundColor:
                                  colorScheme.surfaceContainerHigh,
                              disabledForegroundColor: colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                      child: Text(buttonLabel),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapacityBadge extends StatelessWidget {
  final int booked;
  final int capacity;
  final bool isFull;

  const _CapacityBadge({
    required this.booked,
    required this.capacity,
    required this.isFull,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isFull
        ? AppTheme.errorRedContainer
        : AppTheme.secondary;
    final Color fg = isFull
        ? AppTheme.errorRed
        : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$booked/$capacity',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
