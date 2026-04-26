import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/env.dart';
import '../features/quest/services/boot_drain.dart';
import '../features/quest/services/geolocator_tracker.dart';
import '../features/quest/services/locus_tracker.dart';
import '../features/quest/services/permission_flow.dart';
import '../features/quest/services/quest_tracker.dart';
import '../features/quest/services/tracking_sync.dart';
import 'local/event_cache.dart';
import 'local/tracking_db.dart';
import 'mock/mock_auth_repository.dart';
import 'mock/mock_badges_repository.dart';
import 'mock/mock_events_repository.dart';
import 'mock/mock_quests_repository.dart';
import 'mock/mock_users_repository.dart';
import 'remote/api_client.dart';
import 'remote/auth_interceptor.dart';
import 'remote/auth_token_store.dart';
import 'remote/real_auth_repository.dart';
import 'remote/real_badges_repository.dart';
import 'remote/real_events_repository.dart';
import 'remote/quest_payloads.dart';
import 'remote/real_quests_repository.dart';
import 'remote/real_users_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/badges_repository.dart';
import 'repositories/events_repository.dart';
import 'repositories/quests_repository.dart';
import 'repositories/users_repository.dart';

/// Toggle that decides which repository implementation a provider hands out.
/// Sourced from `Env.useMocks` (compile-time `--dart-define`). Exposed as a
/// provider so tests can override it without rebuilding the app.
final useMocksProvider = Provider<bool>((_) => Env.useMocks);

// ── Mock-mode bootstrap ────────────────────────────────────────────────

/// `MockAuthRepository` is async-constructed (opens a Hive box). The
/// FutureProvider blocks the rest of the dependency graph until it's ready;
/// `main.dart` awaits it on cold start so the splash never sees a
/// half-initialised tree.
final mockAuthRepositoryProvider =
    FutureProvider<MockAuthRepository>((ref) async {
  return MockAuthRepository.create();
});

// ── Real-mode bootstrap ────────────────────────────────────────────────

/// AuthTokenStore is async-constructed (opens the `auth_session` Hive box)
/// and is the [AuthTokenSource] for the Dio interceptor. Pre-warmed in
/// `main.dart` so the splash never reads it before it's open.
final authTokenStoreProvider =
    FutureProvider<AuthTokenStore>((ref) async => AuthTokenStore.create());

final apiClientProvider = Provider<ApiClient>((ref) {
  if (ref.read(useMocksProvider)) {
    return ApiClient.create(tokens: const _NullAuthTokenSource());
  }
  final asyncStore = ref.watch(authTokenStoreProvider);
  return asyncStore.maybeWhen(
    data: (store) => ApiClient.create(tokens: store),
    orElse: () => throw StateError(
      'ApiClient accessed before authTokenStoreProvider resolved. '
      'Await `ref.read(authTokenStoreProvider.future)` in main() first.',
    ),
  );
});

class _NullAuthTokenSource implements AuthTokenSource {
  const _NullAuthTokenSource();
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<String?> tryRefresh() async => null;
}

// ── Public providers ───────────────────────────────────────────────────

/// Public `AuthRepository` provider. Switches between Mock + Real on the
/// `useMocksProvider` flag. Mock impl is async-resolved so accessing this
/// before `mockAuthRepositoryProvider` settles raises a clear error.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.read(useMocksProvider)) {
    final asyncMock = ref.watch(mockAuthRepositoryProvider);
    return asyncMock.maybeWhen(
      data: (impl) => impl,
      orElse: () => throw StateError(
        'AuthRepository accessed before mockAuthRepositoryProvider resolved. '
        'Await `ref.read(mockAuthRepositoryProvider.future)` in main() first.',
      ),
    );
  }
  final asyncStore = ref.watch(authTokenStoreProvider);
  final store = asyncStore.maybeWhen(
    data: (s) => s,
    orElse: () => throw StateError(
      'RealAuthRepository accessed before authTokenStoreProvider resolved. '
      'Await `ref.read(authTokenStoreProvider.future)` in main() first.',
    ),
  );
  return RealAuthRepository(ref.watch(apiClientProvider), store);
});

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  if (ref.read(useMocksProvider)) {
    final auth = ref.watch(authRepositoryProvider) as MockAuthRepository;
    return MockUsersRepository(auth);
  }
  return RealUsersRepository(ref.watch(apiClientProvider));
});

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  if (ref.read(useMocksProvider)) {
    final auth = ref.watch(authRepositoryProvider) as MockAuthRepository;
    final repo = MockEventsRepository(auth);
    ref.onDispose(repo.dispose);
    return repo;
  }
  return RealEventsRepository(
    ref.watch(apiClientProvider),
    cache: ref.watch(eventCacheProvider),
  );
});

/// On-device cache of events the user has interacted with. Lets the
/// dual-track quest start at the venue without a network round-trip.
final eventCacheProvider = Provider<EventCache>((ref) {
  final cache = EventCache();
  ref.onDispose(cache.close);
  return cache;
});

final questsRepositoryProvider = Provider<QuestsRepository>((ref) {
  if (ref.read(useMocksProvider)) {
    final repo = MockQuestsRepository();
    ref.onDispose(repo.dispose);
    return repo;
  }
  return RealQuestsRepository(
    ref.watch(apiClientProvider),
    questTracker: ref.watch(questTrackerProvider),
  );
});

// ── Quest dual-track wiring (real mode only) ───────────────────────────

/// On-device Hive store for the dual-track tracker. Singleton per app
/// session — opened/closed per active quest by `QuestTracker`.
final trackingDbProvider = Provider<TrackingDb>((ref) => TrackingDb());

/// Periodic batch uploader. Pulled out so [BootDrainService] can use the
/// same instance to flush data left over from a previous session.
///
/// The sync closure HTTP-POSTs via `apiClientProvider` directly rather
/// than calling `RealQuestsRepository.syncTrackingBatch` — that would
/// close the cycle
/// `questsRepositoryProvider → questTrackerProvider → trackingSyncProvider → questsRepositoryProvider`.
final trackingSyncProvider = Provider<TrackingSync>((ref) {
  final api = ref.watch(apiClientProvider);
  final db = ref.watch(trackingDbProvider);
  return TrackingSync(
    db: db,
    syncFn: ({
      required String eventId,
      required locusEvents,
      required geolocatorPings,
    }) async {
      await api.dio.post<Map<String, dynamic>>(
        '/quests/$eventId/sync',
        data: {
          'locusEvents':
              locusEvents.map((e) => locusEventToJson(e)).toList(),
          'geolocatorPings':
              geolocatorPings.map((p) => geolocatorPingToJson(p)).toList(),
          'clientTimestamp': DateTime.now().toIso8601String(),
        },
      );
    },
  );
});

/// Lifecycle-owning orchestrator. Constructed even in mock mode so the
/// provider graph is consistent; the mock `QuestsRepository` ignores it.
final questTrackerProvider = Provider<QuestTracker>((ref) {
  return QuestTracker(
    permissionFlow: const PermissionFlow(),
    locusTracker: LocusTracker(),
    geolocatorTracker: GeolocatorTracker(),
    trackingDb: ref.watch(trackingDbProvider),
    trackingSync: ref.watch(trackingSyncProvider),
    eventsRepository: ref.watch(eventsRepositoryProvider),
  );
});

/// One-shot drain service for tracker rows left over from a quest that
/// ended without a network connection. Fired by `main.dart` after the
/// auth token is loaded; runs in the background, never blocks boot.
final bootDrainServiceProvider = Provider<BootDrainService>((ref) {
  return BootDrainService(
    db: ref.watch(trackingDbProvider),
    sync: ref.watch(trackingSyncProvider),
  );
});

final badgesRepositoryProvider = Provider<BadgesRepository>((ref) {
  if (ref.read(useMocksProvider)) {
    final auth = ref.watch(authRepositoryProvider) as MockAuthRepository;
    return MockBadgesRepository(auth);
  }
  return RealBadgesRepository(ref.watch(apiClientProvider));
});

/// Convenience: emits `AuthState` for the rest of the app (splash redirect,
/// router guards, profile screen). Subscribes to the auth repo's stream.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.watchAuthState();
});
