import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Provider for the GoRouter. In Session 3+ a redirect callback gets wired
/// in here to bounce the user between splash / onboarding / home based on
/// `authStateProvider`. For now every route is freely navigable so the
/// debug menu can drive end-to-end smoke tests.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Env.debugRoutesEnabled ? AppRoutes.debug : AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashAuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingIdentity,
        builder: (_, _) => const IdentityScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingInterests,
        builder: (_, _) => const InterestsScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingPermissions,
        builder: (_, _) => const PermissionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const HomeFeedScreen(),
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
        builder: (_, state) =>
            CameraScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/reveal/:badgeId',
        builder: (_, state) =>
            RevealScreen(badgeId: state.pathParameters['badgeId']!),
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
