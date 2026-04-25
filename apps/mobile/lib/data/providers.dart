import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/env.dart';
import 'mock/mock_auth_repository.dart';
import 'mock/mock_badges_repository.dart';
import 'mock/mock_events_repository.dart';
import 'mock/mock_quests_repository.dart';
import 'mock/mock_users_repository.dart';
import 'remote/api_client.dart';
import 'remote/auth_interceptor.dart';
import 'remote/real_auth_repository.dart';
import 'remote/real_badges_repository.dart';
import 'remote/real_events_repository.dart';
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

/// AuthTokenSource adapter for the real Dio interceptor. In Phase 2 this
/// reads from the same Hive `mock_auth` box (renamed to `auth_session`)
/// or a Supabase session bridge — until then it always returns null so
/// the interceptor short-circuits.
class _NullAuthTokenSource implements AuthTokenSource {
  const _NullAuthTokenSource();
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<String?> tryRefresh() async => null;
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.create(tokens: const _NullAuthTokenSource());
});

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
  return RealAuthRepository(ref.watch(apiClientProvider));
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
  return RealEventsRepository(ref.watch(apiClientProvider));
});

final questsRepositoryProvider = Provider<QuestsRepository>((ref) {
  if (ref.read(useMocksProvider)) {
    final repo = MockQuestsRepository();
    ref.onDispose(repo.dispose);
    return repo;
  }
  return RealQuestsRepository(ref.watch(apiClientProvider));
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
