import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/event_category.dart';
import '../../../data/models/quest.dart';
import '../../../data/providers.dart';

/// Pantalla — Mis quests.
///
/// Lista cronológica (más reciente primero) de todas las quests del usuario
/// (intents marcados), independientemente de si terminaron verificadas o no.
/// Cada fila muestra fecha + estado + evento/artista/venue y enruta al
/// BadgeDetail (si verificada) o al EventDetail (cualquier otro estado).
class QuestHistoryScreen extends ConsumerWidget {
  const QuestHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(_myQuestsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TopBar(),
            Expanded(
              child: questsAsync.when(
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
                data: (entries) {
                  if (entries.isEmpty) {
                    return const _Empty();
                  }
                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) =>
                        _QuestRow(entry: entries[i]),
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
            'Mis quests',
            style: AppTypography.displaySmall,
          ),
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  final MyQuestEntry entry;
  const _QuestRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final ambient = _ambient(entry.event.category);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        onTap: () {
          HapticFeedback.lightImpact();
          // Verified rows deep-link to the badge reveal; everything
          // else routes to event-detail, which already handles the
          // post-event claim button + the live status banner from
          // the prior bug-fix.
          if (entry.status == MyQuestStatus.verified &&
              entry.badge != null) {
            context.push(AppRoutes.badgeDetail(entry.badge!.id));
          } else {
            context.push(AppRoutes.eventDetail(entry.event.slug));
          }
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
              _DateBlock(date: entry.event.startsAt, ambient: ambient),
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
                          _categoryLabel(entry.event.category),
                          style: AppTypography.monoSmall.copyWith(
                            fontSize: 9,
                            letterSpacing: 1.4,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const Spacer(),
                        _StatusPill(status: entry.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.event.title,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.event.artistName != null &&
                        entry.event.artistName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.event.artistName!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${entry.event.venueName} · ${entry.event.city}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.badge != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '#${entry.badge!.serialNumber.toString().padLeft(5, '0')}',
                            style: AppTypography.monoSmall.copyWith(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (entry.verification != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Score ${entry.verification!.verificationScore.toStringAsFixed(0)}',
                              style: AppTypography.monoSmall.copyWith(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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

class _StatusPill extends StatelessWidget {
  final MyQuestStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = _configFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cfg.label,
            style: AppTypography.monoSmall.copyWith(
              fontSize: 9,
              letterSpacing: 1.2,
              color: cfg.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (cfg.icon != null) ...[
            const SizedBox(width: 2),
            Icon(cfg.icon, size: 11, color: cfg.fg),
          ],
        ],
      ),
    );
  }

  static _PillConfig _configFor(MyQuestStatus s) {
    switch (s) {
      case MyQuestStatus.verified:
        return const _PillConfig(
          label: 'VERIFIED',
          bg: AppColors.accentGlow,
          fg: AppColors.accent,
          icon: Icons.check_rounded,
        );
      case MyQuestStatus.live:
        return const _PillConfig(
          label: 'EN CURSO',
          bg: AppColors.accent,
          fg: AppColors.textPrimary,
          icon: null,
        );
      case MyQuestStatus.upcoming:
        return const _PillConfig(
          label: 'PRÓXIMO',
          bg: AppColors.surfaceElevated,
          fg: AppColors.textSecondary,
          icon: null,
        );
      case MyQuestStatus.unverified:
        return const _PillConfig(
          label: 'SIN VERIFICAR',
          bg: AppColors.surfaceElevated,
          fg: AppColors.textTertiary,
          icon: null,
        );
    }
  }
}

class _PillConfig {
  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  const _PillConfig({
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
  });
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'Aún no marcaste intent en ningún evento — explora el feed.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

final _myQuestsProvider = FutureProvider.autoDispose<List<MyQuestEntry>>((ref) {
  return ref.watch(questsRepositoryProvider).listMyQuests();
});
