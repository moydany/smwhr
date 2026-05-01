import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
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
        ProfileAvatar(avatarUrl: user.avatarUrl, size: 96),
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

/// Circular avatar with the magenta→purple gradient fallback used across
/// smwhr. When [avatarUrl] is set we render the network image (cached);
/// otherwise the gradient acts as the user's "no-photo" identity.
///
/// Accepts `file://` URIs as well so the edit-profile preview can show a
/// just-uploaded image in mock mode. Rendered as a square via
/// `BoxFit.cover`, clipped to a circle, with the same magenta glow the
/// gradient version had.
class ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double size;
  const ProfileAvatar({super.key, required this.avatarUrl, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: avatarUrl == null
            ? const LinearGradient(
                colors: [Color(0xFFFF2D95), Color(0xFF6B1AFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.4),
            blurRadius: size / 3,
            spreadRadius: -4,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl == null
          ? null
          : (avatarUrl!.startsWith('file://')
              ? Image.file(
                  // Strip the "file://" prefix for `Image.file`.
                  File.fromUri(Uri.parse(avatarUrl!)),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                )
              : CachedNetworkImage(
                  imageUrl: avatarUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(
                    color: AppColors.surfaceElevated,
                  ),
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: AppColors.surfaceElevated,
                  ),
                )),
    );
  }
}

/// 3-column stats card: QUESTS / VENUES / ARTISTS.
///
/// `onQuestsTap` makes the QUESTS column tappable — used on the current
/// user's own profile to drill into quest history.
class ProfileStats extends StatelessWidget {
  final int quests;
  final int venues;
  final int artists;
  final VoidCallback? onQuestsTap;

  const ProfileStats({
    super.key,
    required this.quests,
    required this.venues,
    required this.artists,
    this.onQuestsTap,
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
          _Stat(value: quests, label: 'quests', onTap: onQuestsTap),
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
  final VoidCallback? onTap;
  const _Stat({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final column = Column(
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
    );
    return Expanded(
      child: onTap == null
          ? column
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: column,
                ),
              ),
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
