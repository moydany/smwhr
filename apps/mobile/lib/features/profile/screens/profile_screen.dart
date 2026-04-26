import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/badge.dart';
import '../../../data/models/user.dart';
import '../../../data/providers.dart';
import '../widgets/collection_badge_tile.dart';
import '../widgets/profile_top.dart';

/// Pantalla 10 — Profile + collection.
///
/// Hero: avatar + handle + bio + stats. Tab strip with Collection /
/// Wanted / Friends; Collection is the only tab populated for R0.1.
/// 2-column grid of CollectionBadgeTile pulled from
/// UsersRepository.getUserBadges.
class ProfileScreen extends ConsumerWidget {
  /// Null = current user. Otherwise look up the handle.
  final String? handle;
  const ProfileScreen({super.key, this.handle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = handle == null
        ? ref.watch(_meProvider)
        : ref.watch(_userByHandleProvider(handle!));
    final badgesAsync = ref.watch(
      _userBadgesProvider(handle ?? '@me'),
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: userAsync.when(
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
          data: (user) {
            if (user == null) {
              return const Center(child: Text('User not found'));
            }
            return _Body(user: user, badgesAsync: badgesAsync);
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final User user;
  final AsyncValue<List<Badge>> badgesAsync;
  const _Body({required this.user, required this.badgesAsync});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                _TopBar(),
                const SizedBox(height: AppSpacing.lg),
                ProfileTop(user: user),
                const SizedBox(height: AppSpacing.lg),
                ProfileStats(
                  quests: user.questsCount,
                  venues: user.venuesCount,
                  artists: user.artistsCount,
                ),
                const SizedBox(height: AppSpacing.lg),
                _Tabs(badgeCount: badgesAsync.value?.length ?? 0),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
        badgesAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                e.toString(),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ),
          data: (badges) {
            if (badges.isEmpty) {
              return const SliverToBoxAdapter(child: _EmptyCollection());
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              sliver: SliverGrid.builder(
                itemCount: badges.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  // Tile = artwork (square) + 2 monos headers + footer
                  // caption row. Taller than wide to fit it all.
                  childAspectRatio: 0.66,
                ),
                itemBuilder: (context, i) =>
                    CollectionBadgeTile(badge: badges[i]),
              ),
            );
          },
        ),
      ],
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
        const Spacer(),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  final int badgeCount;
  const _Tabs({required this.badgeCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _TabLabel(label: 'Collection', active: true),
        const SizedBox(width: AppSpacing.lg),
        const _TabLabel(label: 'Wanted'),
        const SizedBox(width: AppSpacing.lg),
        const _TabLabel(label: 'Friends'),
        const Spacer(),
        Text(
          badgeCount.toString(),
          style: AppTypography.monoSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final bool active;
  const _TabLabel({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color:
                active ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: 2,
          color: active ? AppColors.accent : Colors.transparent,
        ),
      ],
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Text(
          'No badges yet — your first quest is waiting.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Providers ──────────────────────────────────────────────────────

final _meProvider = FutureProvider.autoDispose<User?>((ref) async {
  final repo = ref.watch(usersRepositoryProvider);
  return repo.getMe();
});

final _userByHandleProvider =
    FutureProvider.autoDispose.family<User?, String>((ref, handle) async {
  final repo = ref.watch(usersRepositoryProvider);
  return repo.getUserByHandle(handle);
});

final _userBadgesProvider =
    FutureProvider.autoDispose.family<List<Badge>, String>(
        (ref, key) async {
  // Own profile uses the backend's dedicated /me/badges endpoint — no
  // handle round-trip, and works during the post-auth / pre-onboarding
  // window when the placeholder handle wouldn't resolve through
  // /users/:handle/badges anyway.
  if (key == '@me') {
    return ref.watch(badgesRepositoryProvider).listMyBadges();
  }
  return ref.watch(usersRepositoryProvider).getUserBadges(key);
});
