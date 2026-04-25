import 'package:flutter/material.dart' hide Badge;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/badge.dart';
import '../../../features/badges/widgets/badge_card.dart';

/// 1080×1920-ready share card. Composes the BadgeCard with the
/// "I was somewhere." caption + "@smwhr" handle + smwhr.quest footer
/// inside a fixed-aspect container we can later capture as an image
/// with RepaintBoundary + dart:ui in Phase 2.
class ShareCard extends StatelessWidget {
  final Badge badge;
  final GlobalKey? boundaryKey;

  const ShareCard({super.key, required this.badge, this.boundaryKey});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          BadgeCard(badge: badge),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'I was somewhere.',
            style: AppTypography.displayLarge.copyWith(
              fontSize: 26,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@SMWHR',
            style: AppTypography.monoSmall.copyWith(
              fontSize: 11,
              letterSpacing: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'SMWHR.QUEST',
            style: AppTypography.monoSmall.copyWith(
              fontSize: 9,
              letterSpacing: 2.4,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );

    return boundaryKey == null
        ? card
        : RepaintBoundary(key: boundaryKey, child: card);
  }
}
