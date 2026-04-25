import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/event.dart';
import 'event_artwork.dart';

/// Compact horizontal card used in the home feed list. Square thumbnail
/// on the left, title/venue/date stacked in the middle, count + chevron
/// on the right.
class EventListCard extends StatelessWidget {
  final Event event;
  const EventListCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(AppRoutes.eventDetail(event.slug));
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: EventArtwork(
                event: event,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusSmall),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.venueName,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatShortDate(event.startsAt),
                    style: AppTypography.monoSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _compactCount(event.intentCount),
                  style: AppTypography.monoSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
      ),
    );
  }

  static String _compactCount(int n) {
    if (n >= 1000) {
      final k = (n / 1000);
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return n.toString();
  }

  static String _formatShortDate(DateTime d) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    final mon = months[d.month - 1];
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '$mon ${d.day.toString().padLeft(2, '0')} · $hour:$mm $ampm';
  }
}
