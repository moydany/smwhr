import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/env.dart';
import 'mock/mock_auth_repository.dart';
import 'mock/mock_badges_repository.dart';
import 'mock/mock_events_repository.dart';
import 'mock/mock_quests_repository.dart';
import 'mock/mock_users_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/badges_repository.dart';
import 'repositories/events_repository.dart';
import 'repositories/quests_repository.dart';
import 'repositories/users_repository.dart';

/// Toggle that decides which repository implementation a provider hands out.
/// Sourced from `Env.useMocks` (compile-time `--dart-define`). Exposed as a
/// provider so tests can override it without rebuilding the app.
final useMocksProvider = Provider<bool>((_) => Env.useMocks);

/// `MockAuthRepository` is async-constructed (opens a Hive box). The
/// FutureProvider blocks the rest of the dependency graph until it's ready;
/// `main.dart` awaits it on cold start so the splash never sees a
/// half-initialised tree.
final mockAuthRepositoryProvider =
    FutureProvider<MockAuthRepository>((ref) async {
  return MockAuthRepository.create();
});

/// Public `AuthRepository` provider. Reads the future-resolved mock impl;
/// throws if accessed before `mockAuthRepositoryProvider` settles.
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
  throw UnimplementedError('Real AuthRepository lands in Phase 2.');
});

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  if (ref.read(useMocksProvider)) {
    final auth = ref.watch(authRepositoryProvider) as MockAuthRepository;
    return MockUsersRepository(auth);
  }
  throw UnimplementedError('Real UsersRepository lands in Phase 2.');
});

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  if (ref.read(useMocksProvider)) {
    final auth = ref.watch(authRepositoryProvider) as MockAuthRepository;
    final repo = MockEventsRepository(auth);
    ref.onDispose(repo.dispose);
    return repo;
  }
  throw UnimplementedError('Real EventsRepository lands in Phase 2.');
});

final questsRepositoryProvider = Provider<QuestsRepository>((ref) {
  if (ref.read(useMocksProvider)) {
    final repo = MockQuestsRepository();
    ref.onDispose(repo.dispose);
    return repo;
  }
  throw UnimplementedError('Real QuestsRepository lands in Phase 2.');
});

final badgesRepositoryProvider = Provider<BadgesRepository>((ref) {
  if (ref.read(useMocksProvider)) {
    final auth = ref.watch(authRepositoryProvider) as MockAuthRepository;
    return MockBadgesRepository(auth);
  }
  throw UnimplementedError('Real BadgesRepository lands in Phase 2.');
});

/// Convenience: emits `AuthState` for the rest of the app (splash redirect,
/// router guards, profile screen). Subscribes to the auth repo's stream.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.watchAuthState();
});
