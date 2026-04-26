import 'dart:async';

import 'package:dio/dio.dart';

import '../../shared/utils/handle_validator.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import 'api_client.dart';
import 'auth_token_store.dart';
import 'mappers.dart';

/// Phase 2 implementation backed by the NestJS API + Supabase Auth via the
/// `/auth/email/{request,verify}`, `/me`, `/me/onboarding` and
/// `/users/check-handle/:handle` endpoints. Apple/Google providers are
/// deferred until release — they currently emit AuthResultFailure with a
/// 'not configured yet' message.
class RealAuthRepository implements AuthRepository {
  RealAuthRepository(this._api, this._store) {
    _store.registerRefreshCallback(_refreshAccessToken);
    _hydrateFromStore();
  }

  final ApiClient _api;
  final AuthTokenStore _store;

  final StreamController<AuthState> _state =
      StreamController<AuthState>.broadcast();
  AuthState _currentState = const AuthSignedOut();

  void _hydrateFromStore() {
    final session = _store.session;
    if (session == null) {
      _emit(const AuthSignedOut());
      return;
    }
    final cached = _store.cachedUser;
    if (cached != null) {
      // Best UX path: show cached user immediately, refresh in
      // background so a stale profile or revoked session gets fixed
      // without blocking the first frame.
      _emit(AuthSignedIn(cached));
    } else {
      // Session exists but no cached user (rare — verify saved the
      // session then /me failed). Show authenticating until /me lands.
      _emit(const AuthAuthenticating());
    }
    unawaited(_refreshMe());
  }

  void _emit(AuthState s) {
    _currentState = s;
    _state.add(s);
  }

  @override
  AuthState get currentState => _currentState;

  @override
  Stream<AuthState> watchAuthState() async* {
    yield _currentState;
    yield* _state.stream;
  }

  // ── Email magic-link OTP ───────────────────────────────────────────────

  @override
  Future<AuthResult> requestEmailMagicLink(String email) async {
    _emit(const AuthAuthenticating());
    try {
      await _api.dio.post<Map<String, dynamic>>(
        '/auth/email/request',
        data: {'email': email.trim().toLowerCase()},
      );
      _emit(const AuthSignedOut());
      return AuthResultEmailSent(email);
    } on DioException catch (e) {
      _emit(const AuthSignedOut());
      return AuthResultFailure(_apiMessage(e));
    } catch (e) {
      _emit(const AuthSignedOut());
      return AuthResultFailure(e.toString());
    }
  }

  @override
  Future<AuthResult> verifyEmailMagicLink(String email, String code) async {
    _emit(const AuthAuthenticating());
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/email/verify',
        data: {'email': email.trim().toLowerCase(), 'token': code.trim()},
      );
      final body = res.data!;
      await _store.saveSession(AuthSession(
        userId: body['supabaseUserId'] as String,
        accessToken: body['accessToken'] as String,
        refreshToken: body['refreshToken'] as String?,
        issuedAt: DateTime.now(),
        expiresAt: _expiresFrom(body['expiresAt']),
      ));
      final user = await _fetchMe();
      await _store.saveCachedUser(user);
      _emit(AuthSignedIn(user));
      return user.hasCompletedOnboarding
          ? AuthResultReady(user)
          : AuthResultNeedsOnboarding(user);
    } on DioException catch (e) {
      _emit(const AuthSignedOut());
      return AuthResultFailure(_apiMessage(e));
    } catch (e) {
      _emit(const AuthSignedOut());
      return AuthResultFailure(e.toString());
    }
  }

  // ── Onboarding + handle availability ───────────────────────────────────

  @override
  Future<User> completeOnboarding({
    required String handle,
    required String displayName,
    required String city,
    required List<String> interests,
    required bool notificationsEnabled,
  }) async {
    final canonical = HandleValidator.normalize(handle);
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/me/onboarding',
      data: {
        'handle': canonical,
        'displayName': displayName,
        'city': city,
        'countryCode': 'MX',
        'interests': interests,
        'notificationsEnabled': notificationsEnabled,
      },
    );
    final user = userFromJson(res.data!);
    await _store.saveCachedUser(user);
    _emit(AuthSignedIn(user));
    return user;
  }

  @override
  Future<bool> checkHandleAvailable(String handle) async {
    final canonical = HandleValidator.normalize(handle);
    if (canonical.isEmpty) return false;
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/users/check-handle/$canonical',
    );
    return res.data?['available'] == true;
  }

  // ── Sign out ──────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    try {
      await _api.dio.post<void>('/auth/logout');
    } catch (_) {
      // Server-side is stateless; even if the call fails, drop local state.
    }
    await _store.clear();
    _emit(const AuthSignedOut());
  }

  // ── OAuth providers — release-time wiring ─────────────────────────────

  @override
  Future<AuthResult> signInWithApple() async => const AuthResultFailure(
        'Apple sign-in not configured yet',
      );

  @override
  Future<AuthResult> signInWithGoogle() async => const AuthResultFailure(
        'Google sign-in not configured yet',
      );

  // ── Internals ──────────────────────────────────────────────────────────

  Future<User> _fetchMe() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/me');
    return userFromJson(res.data!);
  }

  Future<void> _refreshMe() async {
    try {
      final user = await _fetchMe();
      await _store.saveCachedUser(user);
      _emit(AuthSignedIn(user));
    } on DioException catch (e) {
      // 401 → session is dead; clear and emit signed out so the splash flow
      // can pick the user back up cleanly.
      if (e.response?.statusCode == 401) {
        await _store.clear();
        _emit(const AuthSignedOut());
      }
      // Other transient failures: keep the cached user as-is.
    } catch (_) {
      // ignore; cached user remains visible
    }
  }

  /// Called by AuthTokenStore when a 401 fires. Returns the new access
  /// token (and persists the rotated session) or null if refresh is not
  /// possible — in which case the original 401 propagates.
  Future<String?> _refreshAccessToken() async {
    final refreshToken = _store.session?.refreshToken;
    if (refreshToken == null) return null;
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final body = res.data!;
      final session = AuthSession(
        userId: body['supabaseUserId'] as String,
        accessToken: body['accessToken'] as String,
        refreshToken: body['refreshToken'] as String?,
        issuedAt: DateTime.now(),
        expiresAt: _expiresFrom(body['expiresAt']),
      );
      await _store.saveSession(session);
      return session.accessToken;
    } catch (_) {
      await _store.clear();
      _emit(const AuthSignedOut());
      return null;
    }
  }
}

DateTime? _expiresFrom(Object? v) {
  if (v is num) {
    final secs = v.toInt();
    if (secs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(secs * 1000);
  }
  if (v is String) {
    return DateTime.tryParse(v);
  }
  return null;
}

String _apiMessage(DioException e) {
  final body = e.response?.data;
  if (body is Map && body['message'] is String) return body['message'] as String;
  if (body is Map && body['code'] is String) return body['code'] as String;
  return e.message ?? 'Network error';
}
