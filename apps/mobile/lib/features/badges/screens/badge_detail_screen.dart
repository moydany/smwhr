import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/badge.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/smwhr_ambient_background.dart';
import '../../../shared/widgets/smwhr_button.dart';
import '../widgets/badge_card.dart';

/// Pantalla 09b — Badge detail (post-reveal).
///
/// Static surface for an issued badge: the BadgeCard hero, four
/// metadata stats (date / venue / verification score / serial), and a
/// Share CTA. Reached from the reveal screen's "Save to collection"
/// or from the profile collection grid.
class BadgeDetailScreen extends ConsumerWidget {
  final String badgeId;
  const BadgeDetailScreen({super.key, required this.badgeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeAsync = ref.watch(_badgeProvider(badgeId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: SmwhrAmbientBackground(
              pingCenter: Offset(0.5, 0.35),
              starCount: 40,
              pingRings: 4,
              showSweep: false,
            ),
          ),
          SafeArea(
            child: badgeAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (e, _) => Center(
                child: Text(
                  e.toString(),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
              data: (badge) {
                if (badge == null) {
                  return const Center(child: Text('Badge not found'));
                }
                return _Body(badge: badge);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Badge badge;
  const _Body({required this.badge});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopBar(),
          const SizedBox(height: AppSpacing.lg),
          BadgeCard(badge: badge),
          const SizedBox(height: AppSpacing.lg),
          _Stats(badge: badge),
          const SizedBox(height: AppSpacing.xl),
          SmwhrButton(
            label: 'Share',
            variant: SmwhrButtonVariant.primary,
            leading: const Padding(
              padding: EdgeInsets.only(left: AppSpacing.md),
              child: Icon(Icons.ios_share_rounded, size: 20),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              GoRouter.of(context).push(AppRoutes.share(badge.id));
            },
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (GoRouter.of(context).canPop())
          SizedBox(
            width: 40,
            height: 40,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                },
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  final Badge badge;
  const _Stats({required this.badge});

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
      child: Column(
        children: [
          _StatRow(
            label: 'Issued',
            value: _formatDate(badge.issuedAt),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatRow(
            label: 'Verification',
            value:
                '${(badge.verificationScore * 100).toStringAsFixed(0)}%',
            highlight: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatRow(label: 'Venue', value: badge.venueName),
          const SizedBox(height: AppSpacing.sm),
          _StatRow(
            label: 'Serial',
            value: badge.serialLabel,
            mono: true,
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool mono;

  const _StatRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: (mono ? AppTypography.monoSmall : AppTypography.bodyMedium)
                .copyWith(
              color: highlight
                  ? AppColors.accent
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

final _badgeProvider =
    FutureProvider.autoDispose.family<Badge?, String>((ref, id) async {
  final repo = ref.watch(badgesRepositoryProvider);
  return repo.getBadge(id);
});
