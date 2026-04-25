import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/user.dart';

/// Profile header: avatar circle (magenta→purple gradient until real
/// avatars land in Phase 2), "@handle" big display, single-line
/// `city · Collecting somewheres since YEAR` subtitle.
class ProfileTop extends StatelessWidget {
  final User user;
  const ProfileTop({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF2D95), Color(0xFF6B1AFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4),
                blurRadius: 32,
                spreadRadius: -4,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '@${user.handle}',
          style: AppTypography.displayLarge.copyWith(
            letterSpacing: -1,
            fontSize: 32,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${user.city} · Collecting somewheres since '
          '${user.createdAt.year}',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// 3-column stats card: QUESTS / VENUES / ARTISTS.
class ProfileStats extends StatelessWidget {
  final int quests;
  final int venues;
  final int artists;

  const ProfileStats({
    super.key,
    required this.quests,
    required this.venues,
    required this.artists,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          _Stat(value: quests, label: 'quests'),
          const _Divider(),
          _Stat(value: venues, label: 'venues'),
          const _Divider(),
          _Stat(value: artists, label: 'artists'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: AppTypography.displayLarge.copyWith(
              fontSize: 28,
              letterSpacing: -1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: AppColors.borderSoft);
}
