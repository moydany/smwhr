import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive — used for the mock auth session (Session 2), the real auth
  // token store (Phase 2 cutover), and the dual-track tracking_db
  // (Session 7). Adapters get registered alongside the trackers.
  await Hive.initFlutter();

  // Force the dark status bar at cold start (avoids the iOS default white flash).
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ),
  );

  // R0.1 is portrait-only.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  // Pre-warm the auth boxes so go_router redirects don't crash on first
  // frame trying to read the session before Hive is open. Mock and real
  // modes use different boxes; we open whichever one this build needs.
  final container = ProviderContainer();
  if (Env.useMocks) {
    await container.read(mockAuthRepositoryProvider.future);
  } else {
    await container.read(authTokenStoreProvider.future);
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SmwhrApp(),
    ),
  );
}

class SmwhrApp extends ConsumerWidget {
  const SmwhrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'smwhr',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
