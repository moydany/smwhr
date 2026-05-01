import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/local/adapters/geolocator_ping_adapter.dart';
import 'data/local/adapters/locus_event_adapter.dart';
import 'data/providers.dart';
import 'data/remote/auth_token_store.dart';
import 'features/quest/providers/quest_state_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Boot banner — first thing in stdout. If you don't see this in the
  // `flutter run` console, the new binary didn't load (hot reload
  // doesn't pick up main.dart edits — full restart is required).
  debugPrint(
    '[smwhr.boot] starting · mocks=${Env.useMocks} · '
    'apiBase=${Env.apiBaseUrl} · '
    'syncIntervalSec=${Env.questSyncIntervalSeconds} · '
    'dwellOverrideSec=${Env.questDwellSecondsOverride}',
  );

  // Hive — used for the mock auth session (Session 2), the real auth
  // token store (Phase 2 cutover), and the dual-track tracking_db
  // (Session 7). Adapters get registered alongside the trackers.
  await Hive.initFlutter();

  // Tracking adapters are only needed when we're actually pumping events
  // into the dual-track DB (i.e. in real mode against the NestJS backend).
  // Mock mode never touches Hive boxes typed against these models.
  if (!Env.useMocks) {
    Hive.registerAdapter(LocusEventAdapter());
    Hive.registerAdapter(GeolocatorPingAdapter());
  }

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
    // Hive boxes the real-mode tree depends on. Both async opens run
    // in parallel — they're independent.
    final results = await Future.wait([
      container.read(authTokenStoreProvider.future),
      container.read(photoQueueAsyncProvider.future),
    ]);
    final tokens = results[0] as AuthTokenStore;
    // Best-effort flush of tracker rows from a quest that ended before
    // the network came back. Only meaningful if we have a session to
    // auth the POST with — otherwise the drain would just no-op
    // against 401s. We probe the cached session synchronously instead
    // of calling `readAccessToken()` here because the latter triggers
    // proactive refresh, and the `RealAuthRepository` (which owns the
    // refresh callback) hasn't been instantiated yet at this boot
    // point — the call would log a "NO CALLBACK registered" warning
    // and skip the refresh anyway. Fire-and-forget: never block the
    // splash on it.
    if (tokens.session != null) {
      unawaited(container.read(bootDrainServiceProvider).run());
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SmwhrApp(),
    ),
  );
}

class SmwhrApp extends ConsumerStatefulWidget {
  const SmwhrApp({super.key});

  @override
  ConsumerState<SmwhrApp> createState() => _SmwhrAppState();
}

class _SmwhrAppState extends ConsumerState<SmwhrApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Resume hook — runs every time the app comes back to foreground.
  ///
  /// While backgrounded, the dual trackers keep appending pings to
  /// Hive (Locus runs in its plugin's background runtime; Geolocator
  /// streams via `allowBackgroundLocationUpdates`). What DOESN'T keep
  /// firing reliably is the in-process `Timer.periodic` that runs the
  /// `TrackingSync.syncBatch` POSTs — iOS can throttle or skip timer
  /// callbacks when the app is suspended. So when we come back, we
  /// (a) drain the queued pings immediately and (b) invalidate the
  /// quest-status provider so the UI rerenders with fresh task state
  /// instead of the cached snapshot from before backgrounding.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (Env.useMocks) return;
    final tracker = ref.read(questTrackerProvider);
    final eventId = tracker.activeEventId;
    if (eventId == null) return;
    final sync = ref.read(trackingSyncProvider);
    sync.syncBatch(eventId);
    sync.drainPendingPhoto(eventId);
    ref.invalidate(questStatusProvider(eventId));
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'smwhr',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
