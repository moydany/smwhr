import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/badge.dart';
import '../../../data/models/event.dart';
import '../../../data/models/event_category.dart';
import '../../../data/models/lat_lng.dart';
import '../../../features/events/widgets/event_artwork.dart';

/// Compact badge tile rendered in the profile collection grid. Smaller
/// than the full BadgeCard — drops the venue/date footer to a single
/// `MMM DD` + category label below the artwork.
class CollectionBadgeTile extends StatelessWidget {
  final Badge badge;
  const CollectionBadgeTile({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    final color = _ambient(badge.category);

    final event = Event(
      id: badge.eventId,
      slug: badge.eventId,
      title: badge.eventTitle,
      artistName: badge.artistName,
      venueName: badge.venueName,
      city: badge.city,
      countryCode: badge.countryCode,
      startsAt: badge.eventDate,
      description: '',
      category: badge.category,
      geofencePolygon: const <LatLng>[],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(AppRoutes.badgeDetail(badge.id));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              border: Border.all(
                color: color.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xxs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SMWHR',
                        style: AppTypography.monoSmall.copyWith(
                          fontSize: 8,
                          letterSpacing: 1.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _categoryHeader(badge.category),
                        style: AppTypography.monoSmall.copyWith(
                          fontSize: 8,
                          letterSpacing: 1.2,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: EventArtwork(event: event, large: true),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '#${badge.serial.toString().padLeft(5, '0')}',
                        style: AppTypography.monoSmall.copyWith(
                          fontSize: 8,
                          letterSpacing: 1.0,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'VERIFIED',
                            style: AppTypography.monoSmall.copyWith(
                              fontSize: 8,
                              letterSpacing: 1.2,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.check_rounded,
                            size: 9,
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatShortDate(badge.eventDate),
                  style: AppTypography.monoSmall.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  _categoryShortLabel(badge.category).toUpperCase(),
                  style: AppTypography.monoSmall.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _categoryHeader(EventCategory c) => switch (c) {
        EventCategory.music => 'LIVE MUSIC',
        EventCategory.sports => 'LIVE SPORTS',
        EventCategory.festivals => 'FESTIVAL',
        EventCategory.outdoor => 'OUTDOOR',
        EventCategory.culture => 'CULTURE',
      };

  static String _categoryShortLabel(EventCategory c) => switch (c) {
        EventCategory.music => 'Music',
        EventCategory.sports => 'Sports',
        EventCategory.festivals => 'Festival',
        EventCategory.outdoor => 'Outdoor',
        EventCategory.culture => 'Culture',
      };

  static Color _ambient(EventCategory c) => switch (c) {
        EventCategory.music => AppColors.musicAmbient,
        EventCategory.sports => AppColors.sportsAmbient,
        EventCategory.festivals => AppColors.festivalsAmbient,
        EventCategory.outdoor => AppColors.outdoorAmbient,
        EventCategory.culture => AppColors.cultureAmbient,
      };

  static String _formatShortDate(DateTime d) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
  }
}
