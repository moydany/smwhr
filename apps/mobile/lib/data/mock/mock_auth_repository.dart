import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/user.dart';
import '../repositories/auth_repository.dart';
import 'mock_latency.dart';
import 'mock_users.dart';

/// Mock auth repository.
///
/// - Persists the active session in a Hive box (`mock_auth`) so cold restart
///   restores the logged-in user.
/// - Simulates 800–1200 ms latency on every method.
/// - Treats every signIn provider as success → returns @moi as the user (or
///   `mockNewUser` if you want to test the post-OAuth-pre-onboarding path,
///   triggered by signing in with email "new@smwhr.dev").
class MockAuthRepository implements AuthRepository {
  static const String _boxName = 'mock_auth';
  static const String _sessionKey = 'session';
  static const String _userIdKey = 'userId';

  final Box<dynamic> _box;
  final StreamController<AuthState> _stateController =
      StreamController<AuthState>.broadcast();

  AuthState _currentState = const AuthSignedOut();

  MockAuthRepository._(this._box) {
    _hydrateFromHive();
  }

  /// Async factory — opens the Hive box and rehydrates the persisted
  /// session if present.
  static Future<MockAuthRepository> create() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    return MockAuthRepository._(box);
  }

  void _hydrateFromHive() {
    final userId = _box.get(_userIdKey) as String?;
    if (userId == null) {
      _emit(const AuthSignedOut());
      return;
    }
    final user = mockUsersById[userId];
    if (user == null) {
      // Session pointed to a user the seed no longer knows about — log out.
      _box.delete(_userIdKey);
      _box.delete(_sessionKey);
      _emit(const AuthSignedOut());
      return;
    }
    _emit(AuthSignedIn(user));
  }

  void _emit(AuthState s) {
    _currentState = s;
    _stateController.add(s);
  }

  @override
  Stream<AuthState> watchAuthState() async* {
    yield _currentState;
    yield* _stateController.stream;
  }

  @override
  AuthState get currentState => _currentState;

  @override
  Future<AuthResult> signInWithApple() => _signInGeneric();

  @override
  Future<AuthResult> signInWithGoogle() => _signInGeneric();

  Future<AuthResult> _signInGeneric() async {
    _emit(const AuthAuthenticating());
    await MockLatency.simulate();
    final user = mockCurrentUser;
    await _persistSession(user);
    _emit(AuthSignedIn(user));
    return user.hasCompletedOnboarding
        ? AuthResultReady(user)
        : AuthResultNeedsOnboarding(user);
  }

  @override
  Future<AuthResult> requestEmailMagicLink(String email) async {
    _emit(const AuthAuthenticating());
    await MockLatency.simulate();
    // No state change yet — the actual login happens on verifyEmailMagicLink.
    _emit(const AuthSignedOut());
    return AuthResultEmailSent(email);
  }

  @override
  Future<AuthResult> verifyEmailMagicLink(String email, String code) async {
    _emit(const AuthAuthenticating());
    await MockLatency.simulate();
    // "new@smwhr.dev" → simulate a brand new user that needs onboarding.
    if (email.toLowerCase() == 'new@smwhr.dev') {
      final user = mockNewUser;
      await _persistSession(user);
      _emit(AuthSignedIn(user));
      return AuthResultNeedsOnboarding(user);
    }
    final user = mockCurrentUser;
    await _persistSession(user);
    _emit(AuthSignedIn(user));
    return user.hasCompletedOnboarding
        ? AuthResultReady(user)
        : AuthResultNeedsOnboarding(user);
  }

  @override
  Future<User> completeOnboarding({
    required String handle,
    required String displayName,
    required String city,
    required List<String> interests,
    required bool notificationsEnabled,
  }) async {
    await MockLatency.simulate();
    final base = switch (_currentState) {
      AuthSignedIn(:final user) => user,
      _ => mockNewUser,
    };
    final updated = base.copyWith(
      handle: handle,
      displayName: displayName,
      city: city,
      interests: interests,
      onboardingCompletedAt: DateTime.now(),
    );
    await _persistSession(updated);
    _emit(AuthSignedIn(updated));
    return updated;
  }

  @override
  Future<bool> checkHandleAvailable(String handle) async {
    await MockLatency.shortDelay();
    final normalized = handle.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (reservedHandles.contains(normalized)) return false;
    if (mockUsersByHandle.containsKey(normalized)) return false;
    return true;
  }

  @override
  Future<void> signOut() async {
    await MockLatency.shortDelay();
    await _box.delete(_userIdKey);
    await _box.delete(_sessionKey);
    _emit(const AuthSignedOut());
  }

  Future<void> _persistSession(User user) async {
    await _box.put(_userIdKey, user.id);
    final session = AuthSession(
      userId: user.id,
      accessToken: 'mock-token-${user.id}',
      issuedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
    await _box.put(_sessionKey, session.toJson());
  }

  void dispose() {
    _stateController.close();
  }
}
