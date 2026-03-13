import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/booking_model.dart';
import '../../../models/rating_model.dart';
import '../../../models/user_model.dart';
import '../../../services/rating_service.dart';

// ─── Public entry-point ───────────────────────────────────────────────────────

Future<void> showCompletedSessionsSheet({
  required BuildContext context,
  required List<Booking> completedBookings,
  required Map<String, SessionRating> ratingsMap,
  required AppUser user,
  required void Function(SessionRating) onRatingSubmitted,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CompletedSessionsSheet(
      completedBookings: completedBookings,
      initialRatingsMap: ratingsMap,
      user: user,
      onRatingSubmitted: onRatingSubmitted,
    ),
  );
}

// ─── Sheet widget ─────────────────────────────────────────────────────────────

class _CompletedSessionsSheet extends StatefulWidget {
  final List<Booking> completedBookings;
  final Map<String, SessionRating> initialRatingsMap;
  final AppUser user;
  final void Function(SessionRating) onRatingSubmitted;

  const _CompletedSessionsSheet({
    required this.completedBookings,
    required this.initialRatingsMap,
    required this.user,
    required this.onRatingSubmitted,
  });

  @override
  State<_CompletedSessionsSheet> createState() =>
      _CompletedSessionsSheetState();
}

class _CompletedSessionsSheetState extends State<_CompletedSessionsSheet> {
  late Map<String, SessionRating> _ratingsMap;

  @override
  void initState() {
    super.initState();
    _ratingsMap = Map.from(widget.initialRatingsMap);
  }

  Future<void> _openRateDialog(Booking booking) async {
    final rating = await showRateSessionDialog(
      context: context,
      booking: booking,
      user: widget.user,
    );
    if (rating != null) {
      setState(() => _ratingsMap[booking.sessionId] = rating);
      widget.onRatingSubmitted(rating);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Text(
                  'Completed Sessions',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: widget.completedBookings.isEmpty
                ? const Center(
                    child: Text(
                      'No completed sessions yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: widget.completedBookings.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final booking = widget.completedBookings[i];
                      final existingRating =
                          _ratingsMap[booking.sessionId];
                      return _SessionHistoryTile(
                        booking: booking,
                        existingRating: existingRating,
                        onRate: () => _openRateDialog(booking),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Individual tile ──────────────────────────────────────────────────────────

class _SessionHistoryTile extends StatelessWidget {
  final Booking booking;
  final SessionRating? existingRating;
  final VoidCallback onRate;

  const _SessionHistoryTile({
    required this.booking,
    required this.existingRating,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final isRated = existingRating != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isRated
            ? Colors.green.shade50
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRated
              ? Colors.green.shade200
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          // Date column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEE, dd MMM yyyy')
                    .format(booking.sessionStartsAt),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('HH:mm').format(booking.sessionStartsAt),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              if (isRated) ...[
                const SizedBox(height: 4),
                _StarRow(rating: existingRating!.rating, size: 14),
                if (existingRating!.comment.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      existingRating!.comment,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ],
          ),
          const Spacer(),
          // Action
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
              onPressed: onRate,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Rating dialog ────────────────────────────────────────────────────────────

Future<SessionRating?> showRateSessionDialog({
  required BuildContext context,
  required Booking booking,
  required AppUser user,
}) {
  return showDialog<SessionRating>(
    context: context,
    builder: (_) => _RateSessionDialog(booking: booking, user: user),
  );
}

class _RateSessionDialog extends StatefulWidget {
  final Booking booking;
  final AppUser user;

  const _RateSessionDialog({
    required this.booking,
    required this.user,
  });

  @override
  State<_RateSessionDialog> createState() => _RateSessionDialogState();
}

class _RateSessionDialogState extends State<_RateSessionDialog> {
  int _selectedStars = 0;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final service = RatingService();
      await service.submitRating(
        sessionId: widget.booking.sessionId,
        bookingId: widget.booking.id,
        userId: widget.user.uid,
        userName: '${widget.user.name} ${widget.user.surname}'.trim(),
        userEmail: widget.user.email,
        rating: _selectedStars,
        comment: _commentCtrl.text.trim(),
        sessionStartsAt: widget.booking.sessionStartsAt,
      );

      // Return the newly created rating to the caller.
      final rating = SessionRating(
        id: '${widget.user.uid}_${widget.booking.sessionId}',
        sessionId: widget.booking.sessionId,
        bookingId: widget.booking.id,
        userId: widget.user.uid,
        userName:
            '${widget.user.name} ${widget.user.surname}'.trim(),
        userEmail: widget.user.email,
        rating: _selectedStars,
        comment: _commentCtrl.text.trim(),
        sessionStartsAt: widget.booking.sessionStartsAt,
        createdAt: DateTime.now(),
      );

      if (mounted) Navigator.pop(context, rating);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate your session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('EEEE, dd MMM yyyy • HH:mm')
                .format(widget.booking.sessionStartsAt),
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Star selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => setState(() => _selectedStars = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < _selectedStars ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 38,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedStars == 0
                ? 'Tap a star to rate'
                : _starLabel(_selectedStars),
            style: TextStyle(
              fontSize: 13,
              color: _selectedStars == 0
                  ? Colors.grey
                  : Colors.amber.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              hintText: 'How was the session?',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }

  String _starLabel(int stars) {
    switch (stars) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Great';
      case 5:
        return 'Excellent!';
      default:
        return '';
    }
  }
}

// ─── Shared star-row widget ───────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  final int rating;
  final double size;

  const _StarRow({required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        ),
      ),
    );
  }
}

// Make _StarRow accessible from other files in the same package.
class StarRow extends StatelessWidget {
  final int rating;
  final double size;

  const StarRow({super.key, required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        ),
      ),
    );
  }
}