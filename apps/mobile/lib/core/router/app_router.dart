import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../features/_debug/debug_menu_screen.dart';
import '../../features/auth/screens/splash_auth_screen.dart';
import '../../features/badges/screens/badge_detail_screen.dart';
import '../../features/badges/screens/reveal_screen.dart';
import '../../features/camera/screens/camera_screen.dart';
import '../../features/events/screens/event_detail_screen.dart';
import '../../features/events/screens/home_feed_screen.dart';
import '../../features/onboarding/screens/identity_screen.dart';
import '../../features/onboarding/screens/interests_screen.dart';
import '../../features/onboarding/screens/permissions_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/quest/screens/active_quest_screen.dart';
import '../../features/share/screens/share_screen.dart';
import '../config/env.dart';
import 'transitions.dart';

/// Named route paths. Strings live here so widgets don't sprinkle string
/// literals — and so the debug menu has a single source of truth.
class AppRoutes {
  AppRoutes._();
  static const splash = '/';
  static const onboardingIdentity = '/onboarding/identity';
  static const onboardingInterests = '/onboarding/interests';
  static const onboardingPermissions = '/onboarding/permissions';
  static const home = '/home';
  static String eventDetail(String slug) => '/events/$slug';
  static String activeQuest(String eventId) => '/quest/$eventId';
  static String camera(String eventId) => '/camera/$eventId';
  static String reveal(String badgeId) => '/reveal/$badgeId';
  static String badgeDetail(String badgeId) => '/badge/$badgeId';
  static const profileMe = '/profile';
  static String profileOf(String handle) => '/profile/$handle';
  static String share(String badgeId) => '/share/$badgeId';
  static const debug = '/_debug';
}

/// `Listenable` adapter that fires whenever `authStateProvider` emits a new
/// state, so go_router re-runs its redirect logic after sign-in / sign-out.
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(this._ref) {
    _sub = _ref.listen<AsyncValue<AuthState>>(
      authStateProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }
  final Ref _ref;
  late final ProviderSubscription<AsyncValue<AuthState>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// Provider for the GoRouter.
///
/// Redirect contract:
/// - The debug menu (`/_debug`) and onboarding routes are never redirected.
/// - Signed-out users hitting any post-auth route get bounced to `/`.
/// - Signed-in users hitting `/` are bounced to `/home` (or
///   `/onboarding/identity` if onboarding isn't complete).
final appRouterProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthStateListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: Env.bootAt.isNotEmpty
        ? Env.bootAt
        : (Env.debugRoutesEnabled && Env.bootAtDebug)
            ? AppRoutes.debug
            : AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: listenable,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Debug menu and onboarding screens bypass gating either way.
      if (loc == AppRoutes.debug || loc.startsWith('/onboarding/')) {
        return null;
      }
      // Design-QA mode (`--dart-define=BOOT_AT=...`) bypasses gating.
      if (Env.bootAt.isNotEmpty) return null;

      // Use the repo's synchronous getter — `authStateProvider` is a
      // StreamProvider and may be `loading` for a tick after cold start,
      // which would mis-classify signed-in users as signed-out.
      final auth = ref.read(authRepositoryProvider).currentState;

      if (auth is AuthSignedIn) {
        // Signed-in user landing on splash → bounce to where they
        // belong (home, or onboarding if it isn't finished yet).
        if (loc == AppRoutes.splash) {
          return auth.user.hasCompletedOnboarding
              ? AppRoutes.home
              : AppRoutes.onboardingIdentity;
        }
        return null;
      }

      // Not signed in. Splash is the destination.
      if (loc == AppRoutes.splash) return null;
      return AppRoutes.splash;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => fadeThrough(
          key: state.pageKey,
          child: const SplashAuthScreen(),
          duration: const Duration(milliseconds: 500),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingIdentity,
        pageBuilder: (context, state) => fadeThrough(
          key: state.pageKey,
          child: const IdentityScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingInterests,
        pageBuilder: (context, state) => fadeThrough(
          key: state.pageKey,
          child: const InterestsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingPermissions,
        pageBuilder: (context, state) => fadeThrough(
          key: state.pageKey,
          child: const PermissionsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => fadeThrough(
          key: state.pageKey,
          child: const HomeFeedScreen(),
          duration: const Duration(milliseconds: 420),
        ),
      ),
      GoRoute(
        path: '/events/:slug',
        builder: (_, state) =>
            EventDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/quest/:eventId',
        builder: (_, state) =>
            ActiveQuestScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/camera/:eventId',
        pageBuilder: (context, state) => slideUp(
          key: state.pageKey,
          child: CameraScreen(eventId: state.pathParameters['eventId']!),
        ),
      ),
      GoRoute(
        path: '/reveal/:badgeId',
        pageBuilder: (context, state) => fadeThrough(
          key: state.pageKey,
          child: RevealScreen(badgeId: state.pathParameters['badgeId']!),
          duration: const Duration(milliseconds: 500),
        ),
      ),
      GoRoute(
        path: '/badge/:badgeId',
        builder: (_, state) =>
            BadgeDetailScreen(badgeId: state.pathParameters['badgeId']!),
      ),
      GoRoute(
        path: AppRoutes.profileMe,
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/:handle',
        builder: (_, state) =>
            ProfileScreen(handle: state.pathParameters['handle']),
      ),
      GoRoute(
        path: '/share/:badgeId',
        builder: (_, state) =>
            ShareScreen(badgeId: state.pathParameters['badgeId']!),
      ),
      if (Env.debugRoutesEnabled)
        GoRoute(
          path: AppRoutes.debug,
          builder: (_, _) => const DebugMenuScreen(),
        ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '404: ${state.uri}',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ),
    ),
  );
});
