import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/env.dart';
import '../features/quest/services/auto_start_live_quests.dart';
import '../features/quest/services/boot_drain.dart';
import '../features/quest/services/geolocator_tracker.dart';
import '../features/quest/services/quest_reminder.dart';
import '../features/quest/services/locus_tracker.dart';
import '../features/quest/services/permission_flow.dart';
import '../features/quest/services/quest_tracker.dart';
import '../features/quest/services/tracking_sync.dart';
import 'local/event_cache.dart';
import 'local/photo_queue.dart';
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
import 'models/user.dart';
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

/// PhotoQueue opens its Hive box once and stays open for the app
/// session. `main.dart` warms this in parallel with the auth store so
/// the camera + tracking-sync providers can read it synchronously.
final photoQueueAsyncProvider =
    FutureProvider<PhotoQueue>((ref) async => PhotoQueue.open());

/// Synchronous accessor — pulls from [photoQueueAsyncProvider]. Throws
/// if accessed before the future resolved (mirrors the auth-token-store
/// pattern); `main.dart` awaits before returning.
final photoQueueProvider = Provider<PhotoQueue>((ref) {
  final async = ref.watch(photoQueueAsyncProvider);
  return async.maybeWhen(
    data: (q) => q,
    orElse: () => throw StateError(
      'PhotoQueue accessed before photoQueueAsyncProvider resolved. '
      'Await `ref.read(photoQueueAsyncProvider.future)` in main() first.',
    ),
  );
});

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

/// Current user (`/me`). Public so screens that mutate the profile can
/// `ref.invalidate(meProvider)` to force a refetch after a successful save.
final meProvider = FutureProvider<User?>((ref) async {
  return ref.watch(usersRepositoryProvider).getMe();
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
    reminders: ref.watch(questReminderServiceProvider),
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
    trackingDb: ref.watch(trackingDbProvider),
    photoQueue: ref.watch(photoQueueProvider),
    eventsRepository: ref.watch(eventsRepositoryProvider),
  );
});

// ── Quest dual-track wiring (real mode only) ───────────────────────────

/// On-device Hive store for the dual-track tracker. Singleton per app
/// session — opened/closed per active quest by `QuestTracker`.
final trackingDbProvider = Provider<TrackingDb>((ref) => TrackingDb());

/// Singleton [PermissionFlow] for the camera screen + QuestTracker. The
/// flow is stateless; reusing the same instance just keeps the provider
/// graph tidy.
final permissionFlowProvider =
    Provider<PermissionFlow>((ref) => const PermissionFlow());

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
  final useMocks = ref.read(useMocksProvider);
  // Photo drainer is real-mode only; mocks have no upload endpoint.
  final photoQueue = useMocks ? null : ref.watch(photoQueueProvider);
  return TrackingSync(
    db: db,
    defaultInterval: Duration(seconds: Env.questSyncIntervalSeconds),
    photoQueue: photoQueue,
    photoUploadFn: photoQueue == null
        ? null
        : ({required String eventId, required photo}) async {
            // Multipart contract mirrors `RealQuestsRepository.uploadPhoto`
            // — pinning content-type to image/jpeg keeps Supabase happy.
            final form = FormData.fromMap({
              'file': await MultipartFile.fromFile(
                photo.filePath,
                contentType: DioMediaType('image', 'jpeg'),
              ),
              if (photo.metadata.exifTimestamp != null)
                'exifTimestamp':
                    photo.metadata.exifTimestamp!.toIso8601String(),
              if (photo.metadata.exifLatitude != null)
                'exifLatitude': photo.metadata.exifLatitude!.toString(),
              if (photo.metadata.exifLongitude != null)
                'exifLongitude': photo.metadata.exifLongitude!.toString(),
            });
            final res = await api.dio.post<Map<String, dynamic>>(
              '/quests/$eventId/photo',
              data: form,
              options: Options(
                contentType: 'multipart/form-data',
                sendTimeout: const Duration(seconds: 60),
                receiveTimeout: const Duration(seconds: 60),
              ),
            );
            // First photo of the event → kick the finalize/badge
            // pipeline immediately so the badge is live the moment the
            // user opens their profile, instead of waiting for the
            // hourly cron. Subsequent photos already passed the gate
            // and don't change the score, so we skip. Errors are
            // swallowed: the cron will retry the next time it runs.
            final isAdditional =
                res.data?['isAdditionalPhoto'] == true;
            if (!isAdditional) {
              try {
                await api.dio
                    .post<Map<String, dynamic>>('/quests/$eventId/finalize');
              } catch (_) {/* drainer retries on next tick */}
            }
          },
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
      // Tail every successful sync with an idempotent finalize attempt.
      // Without this, a transient failure of the finalize call inside
      // the photo drainer (after the photo upload itself succeeds)
      // leaves the user permanently stuck with a green checklist and
      // no badge — the queue clears on upload success, so the post-
      // upload finalize is never retried. Hitting finalize on every
      // sync tick gives the verifier a fresh chance the moment the
      // gates pass. Errors are swallowed: next tick retries.
      try {
        await api.dio
            .post<Map<String, dynamic>>('/quests/$eventId/finalize');
      } catch (_) {/* sync tick retries */}
    },
  );
});

/// Lifecycle-owning orchestrator. Constructed even in mock mode so the
/// provider graph is consistent; the mock `QuestsRepository` ignores it.
final questTrackerProvider = Provider<QuestTracker>((ref) {
  return QuestTracker(
    permissionFlow: ref.watch(permissionFlowProvider),
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

/// Sweeps `/me/quests` for live entries with intent and starts the
/// tracker for the first one. Called from `main.dart` post-boot and
/// from `didChangeAppLifecycleState` on resume so the user doesn't
/// have to navigate to event_detail to kick the quest off — being
/// foregrounded during the live window is enough.
final autoStartLiveQuestsServiceProvider =
    Provider<AutoStartLiveQuestsService>((ref) {
  return AutoStartLiveQuestsService(
    repository: ref.watch(questsRepositoryProvider),
    eventCache: ref.watch(eventCacheProvider),
  );
});

/// Schedules local notifications at event start so the user gets a
/// nudge to open the app — the auto-start service then engages the
/// tracker on resume. Singleton so the plugin instance + permission
/// state are shared across `setIntent` / `removeIntent` calls.
final questReminderServiceProvider =
    Provider<QuestReminderService>((_) => QuestReminderService());

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
