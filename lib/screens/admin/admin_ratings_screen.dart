import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/rating_model.dart';
import '../../services/rating_service.dart';
import '../../theme.dart';

class AdminRatingsScreen extends StatelessWidget {
  const AdminRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = RatingService();

    return StreamBuilder<List<SessionRating>>(
      stream: service.streamAllRatings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final ratings = snapshot.data ?? [];

        final double avg = ratings.isEmpty
            ? 0.0
            : ratings.map((r) => r.rating).reduce((a, b) => a + b) /
                ratings.length;

        return Scaffold(
          body: Column(
            children: [
              // ── Summary card ─────────────────────────────────────────
              _SummaryCard(average: avg, totalCount: ratings.length),

              const Divider(height: 1),

              // ── Ratings list ─────────────────────────────────────────
              if (ratings.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_outline,
                            size: 48, color: AppTheme.textColor.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'No ratings yet.',
                          style: TextStyle(color: AppTheme.textColor.withValues(alpha: 0.45)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: ratings.length,
                    separatorBuilder: (context, i) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _RatingTile(rating: ratings[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double average;
  final int totalCount;

  const _SummaryCard({required this.average, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      color: AppTheme.secondary.withValues(alpha: 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big star + number
          Column(
            children: [
              Text(
                average == 0 ? '—' : average.toStringAsFixed(1),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 6),
              _StarRowDisplay(rating: average),
              const SizedBox(height: 4),
              Text(
                '$totalCount rating${totalCount == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textColor.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarRowDisplay extends StatelessWidget {
  final double rating;
  const _StarRowDisplay({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i + 1 <= rating;
        final half = !filled && i < rating;
        return Icon(
          half
              ? Icons.star_half
              : filled
                  ? Icons.star
                  : Icons.star_border,
          color: Colors.amber,
          size: 22,
        );
      }),
    );
  }
}

// ─── Individual rating tile ───────────────────────────────────────────────────

class _RatingTile extends StatelessWidget {
  final SessionRating rating;
  const _RatingTile({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── User info + stars row ────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  rating.userName.isNotEmpty
                      ? rating.userName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.userName.isNotEmpty
                          ? rating.userName
                          : '—',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      rating.userEmail,
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textColor.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              // Stars
              _StarRowSmall(rating: rating.rating),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Session date + rating date ───────────────────────────────
          Row(
            children: [
              Icon(Icons.fitness_center,
                  size: 14, color: AppTheme.textColor.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Text(
                'Session: ${DateFormat('EEE dd MMM yyyy • HH:mm').format(rating.sessionStartsAt)}',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textColor.withValues(alpha: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: AppTheme.textColor.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Text(
                'Rated: ${DateFormat('dd MMM yyyy').format(rating.createdAt)}',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textColor.withValues(alpha: 0.5)),
              ),
            ],
          ),

          // ── Comment ─────────────────────────────────────────────────
          if (rating.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${rating.comment}"',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textColor.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StarRowSmall extends StatelessWidget {
  final int rating;
  const _StarRowSmall({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        ),
      ),
    );
  }
}