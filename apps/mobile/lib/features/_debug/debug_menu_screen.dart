import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/mock/mock_events.dart';
import '../../data/providers.dart';
import '../../data/repositories/auth_repository.dart';

/// Dev-only menu reachable at `/_debug`. Lists every route in the app so we
/// can navigate everywhere without the real flow being wired up. Removed
/// from the build when `Env.useMocks` is false (Phase 2).
class DebugMenuScreen extends ConsumerWidget {
  const DebugMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final firstSlug = mockEvents.first.slug;
    final firstEventId = mockEvents.first.id;

    final routes = <_DebugRoute>[
      const _DebugRoute('/', 'Splash / Auth (S03)'),
      const _DebugRoute('/onboarding/identity', 'Onboarding · Identity (S04)'),
      const _DebugRoute(
          '/onboarding/interests', 'Onboarding · Interests (S04)'),
      const _DebugRoute(
          '/onboarding/permissions', 'Onboarding · Permissions (S04)'),
      const _DebugRoute('/home', 'Home feed (S05)'),
      _DebugRoute('/events/$firstSlug', 'Event detail · BTS N1 (S06)'),
      _DebugRoute('/quest/$firstEventId', 'Active quest · BTS N1 (S07)'),
      _DebugRoute('/camera/$firstEventId', 'Camera · BTS N1 (S08)'),
      const _DebugRoute('/reveal/bdg-001', 'Reveal · Rosalía 2025 (S09)'),
      const _DebugRoute('/badge/bdg-001', 'Badge detail · Rosalía 2025 (S09)'),
      const _DebugRoute('/profile', 'Profile · me (S10)'),
      const _DebugRoute('/profile/sofia', 'Profile · @sofia (S10)'),
      const _DebugRoute('/share/bdg-001', 'Share · Rosalía 2025 (S11)'),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('debug menu', style: AppTypography.monoSmall),
        actions: [
          authState.maybeWhen(
            data: (state) => state is AuthSignedIn
                ? IconButton(
                    icon: const Icon(Icons.logout, size: 20),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await ref.read(authRepositoryProvider).signOut();
                    },
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        itemCount: routes.length + 2,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SessionHeader(
              authState: authState,
            );
          }
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Text('ROUTES', style: AppTypography.labelSmall),
            );
          }
          final route = routes[index - 2];
          return _DebugRouteTile(route: route);
        },
      ),
    );
  }
}

class _DebugRoute {
  final String path;
  final String label;
  const _DebugRoute(this.path, this.label);
}

class _SessionHeader extends StatelessWidget {
  final AsyncValue<AuthState> authState;
  const _SessionHeader({required this.authState});

  @override
  Widget build(BuildContext context) {
    final stateText = authState.maybeWhen(
      data: (s) => switch (s) {
        AuthSignedIn(:final user) => 'signed in as @${user.handle}',
        AuthSignedOut() => 'signed out',
        AuthAuthenticating() => 'authenticating…',
        AuthError(:final message) => 'error: $message',
      },
      orElse: () => 'loading…',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'session 02',
          style: AppTypography.labelSmall.copyWith(color: AppColors.accent),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('router + repos + mocks', style: AppTypography.displayMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(stateText, style: AppTypography.bodySmall),
      ],
    );
  }
}

class _DebugRouteTile extends StatelessWidget {
  final _DebugRoute route;
  const _DebugRouteTile({required this.route});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(route.path);
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusBadge),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusBadge),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(route.label, style: AppTypography.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    route.path,
                    style: AppTypography.monoSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
