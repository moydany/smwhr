import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/event.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/skeleton.dart';
import '../widgets/event_list_card.dart';
import '../widgets/featured_event_card.dart';

/// Pantalla 05 — Home feed.
///
/// Top bar (small wordmark + avatar dot) → "Upcoming" hero title →
/// FeaturedEventCard (the user's RSVP'd-to or featured anchor event) →
/// scrollable list of upcoming events. Pull-to-refresh re-runs the
/// repository query.
class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(_homeEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(_homeEventsProvider);
            await ref.read(_homeEventsProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              const SliverToBoxAdapter(child: _HomeTopBar()),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _Heading(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              eventsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: _LoadingSkeleton(),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: _ErrorBanner(message: e.toString()),
                ),
                data: (events) {
                  if (events.isEmpty) {
                    return const SliverToBoxAdapter(child: _EmptyState());
                  }
                  final featured = events.first;
                  final rest = events.skip(1).toList();
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    sliver: SliverList.builder(
                      itemCount: rest.length + 2,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return FeaturedEventCard(event: featured);
                        }
                        if (index == 1) {
                          return const SizedBox(height: AppSpacing.lg);
                        }
                        final ev = rest[index - 2];
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: EventListCard(event: ev),
                        );
                      },
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxl),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loads the upcoming events for the home feed. Sorts by startsAt asc,
/// drops past events.
final _homeEventsProvider = FutureProvider.autoDispose<List<Event>>(
  (ref) async {
    const tag = 'smwhr.home';
    final t0 = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[$tag] → listEvents(limit=30) start');
    try {
      final repo = ref.watch(eventsRepositoryProvider);
      final events = await repo.listEvents(limit: 30);
      final upcoming = events.where((e) => !e.isPast).toList();
      final ms = DateTime.now().millisecondsSinceEpoch - t0;
      debugPrint(
        '[$tag] ← listEvents ok: ${events.length} total, ${upcoming.length} upcoming · ${ms}ms',
      );
      return upcoming;
    } catch (e, st) {
      final ms = DateTime.now().millisecondsSinceEpoch - t0;
      debugPrint('[$tag] ✗ listEvents failed · ${ms}ms · $e');
      debugPrint('[$tag]   stack: $st');
      rethrow;
    }
  },
);

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          Text(
            'smwhr',
            style: AppTypography.displaySmall.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              GoRouter.of(context).push(AppRoutes.profileMe);
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF2D95), Color(0xFF6B1AFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming',
          style: AppTypography.displayLarge.copyWith(letterSpacing: -1),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Next somewheres for you.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const Icon(
            Icons.event_note_outlined,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No upcoming somewheres yet.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder shown while events load. Mirrors the real layout
/// (one big featured card + 3 list rows) so the page doesn't jolt when
/// data lands.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const Skeleton(height: 320, radius: AppSpacing.radiusCard),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 3; i++) ...[
            const Skeleton(height: 80, radius: AppSpacing.radiusButton),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        border: Border.all(color: AppColors.errorMuted),
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
      ),
      child: Text(
        message,
        style: AppTypography.bodySmall.copyWith(color: AppColors.error),
      ),
    );
  }
}
