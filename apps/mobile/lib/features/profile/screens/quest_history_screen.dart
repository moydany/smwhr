import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/badge.dart';
import '../../../data/models/event_category.dart';
import '../../../data/providers.dart';

/// Pantalla — Quest history.
///
/// Lista cronológica (más reciente primero) de las quests verificadas del
/// usuario actual. Cada fila muestra fecha + estado + evento/artista/venue
/// y enlaza al BadgeDetail correspondiente. Reutiliza la lista de badges
/// del usuario porque hoy quest-completada == badge-emitido; cuando el
/// backend distinga estados (failed / expired / abandoned) se incorporan
/// aquí sin tocar el resto de la app.
class QuestHistoryScreen extends ConsumerWidget {
  const QuestHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(_myBadgesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TopBar(),
            Expanded(
              child: badgesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      e.toString(),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
                data: (badges) {
                  if (badges.isEmpty) {
                    return const _Empty();
                  }
                  final sorted = [...badges]
                    ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) =>
                        _QuestRow(badge: sorted[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
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
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Quest history',
            style: AppTypography.displaySmall,
          ),
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  final Badge badge;
  const _QuestRow({required this.badge});

  @override
  Widget build(BuildContext context) {
    final ambient = _ambient(badge.category);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(AppRoutes.badgeDetail(badge.id));
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBlock(date: badge.eventDate, ambient: ambient),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CategoryDot(color: ambient),
                        const SizedBox(width: 6),
                        Text(
                          _categoryLabel(badge.category),
                          style: AppTypography.monoSmall.copyWith(
                            fontSize: 9,
                            letterSpacing: 1.4,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const Spacer(),
                        const _VerifiedPill(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge.eventTitle,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (badge.artistName != null &&
                        badge.artistName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        badge.artistName!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${badge.venueName} · ${badge.city}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '#${badge.serial.toString().padLeft(5, '0')}',
                          style: AppTypography.monoSmall.copyWith(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Score ${(badge.verificationScore * 100).toStringAsFixed(0)}',
                          style: AppTypography.monoSmall.copyWith(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _ambient(EventCategory c) => switch (c) {
        EventCategory.music => AppColors.musicAmbient,
        EventCategory.sports => AppColors.sportsAmbient,
        EventCategory.festivals => AppColors.festivalsAmbient,
        EventCategory.outdoor => AppColors.outdoorAmbient,
        EventCategory.culture => AppColors.cultureAmbient,
      };

  static String _categoryLabel(EventCategory c) => switch (c) {
        EventCategory.music => 'LIVE MUSIC',
        EventCategory.sports => 'SPORTS',
        EventCategory.festivals => 'FESTIVAL',
        EventCategory.outdoor => 'OUTDOOR',
        EventCategory.culture => 'CULTURE',
      };
}

class _DateBlock extends StatelessWidget {
  final DateTime date;
  final Color ambient;
  const _DateBlock({required this.date, required this.ambient});

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: ambient.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            _months[date.month - 1],
            style: AppTypography.monoSmall.copyWith(
              fontSize: 10,
              letterSpacing: 1.4,
              color: ambient,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date.day.toString().padLeft(2, '0'),
            style: AppTypography.displayMedium.copyWith(
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date.year.toString(),
            style: AppTypography.monoSmall.copyWith(
              fontSize: 9,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDot extends StatelessWidget {
  final Color color;
  const _CategoryDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentGlow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VERIFIED',
            style: AppTypography.monoSmall.copyWith(
              fontSize: 9,
              letterSpacing: 1.2,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.check_rounded,
            size: 11,
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'No quests yet — your first one is waiting.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

final _myBadgesProvider = FutureProvider.autoDispose<List<Badge>>((ref) {
  return ref.watch(badgesRepositoryProvider).listMyBadges();
});
