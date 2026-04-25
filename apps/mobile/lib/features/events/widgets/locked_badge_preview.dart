import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/event.dart';
import '../../../data/models/event_category.dart';
import 'event_artwork.dart';

/// Locked badge preview card shown on the event detail screen.
///
/// Square artwork on the left with a subtle "smwhr · LIVE MUSIC" overlay
/// stamp and a "VERIFIED ✓" pill at the bottom-left of the artwork.
/// On the right: title · city, category · "Collectible", issuance line
/// ("1 of ∞ until event ends"), and a uppercase footer
/// "LOCKED · BE THERE TO EARN".
class LockedBadgePreview extends StatelessWidget {
  final Event event;
  const LockedBadgePreview({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              children: [
                EventArtwork(
                  event: event,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Text(
                    'smwhr',
                    style: AppTypography.monoSmall.copyWith(
                      fontSize: 7,
                      letterSpacing: 0.4,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 5,
                  left: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bg.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.borderSoft,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'VERIFIED',
                          style: AppTypography.monoSmall.copyWith(
                            fontSize: 6,
                            letterSpacing: 0.6,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.check_rounded,
                          size: 7,
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event.title.split(' · ').first} · ${event.city}',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_categoryLabel(event.category)} · Collectible',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '1 of ∞ until event ends',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'LOCKED · BE THERE TO EARN',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _categoryLabel(EventCategory c) => switch (c) {
        EventCategory.music => 'Live music',
        EventCategory.sports => 'Sports',
        EventCategory.festivals => 'Festival',
        EventCategory.outdoor => 'Outdoor',
        EventCategory.culture => 'Culture & arts',
      };
}
