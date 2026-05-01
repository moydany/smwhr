import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_flutter/hive_flutter.dart';

import '../models/user.dart';
import 'auth_interceptor.dart';
import 'mappers.dart';

/// Single source of truth for the live AuthSession + cached User. Owns the
/// Hive box `auth_session`, exposes both fields synchronously, and acts as
/// the [AuthTokenSource] for the Dio interceptor — that's how the API
/// client reaches the bearer token without a circular dep through the
/// repository.
///
/// `RealAuthRepository` is the only writer; tests can construct a store
/// directly with [create] and inject it.
class AuthTokenStore implements AuthTokenSource {
  AuthTokenStore._(this._box);

  static const String boxName = 'auth_session';
  static const String _sessionKey = 'session';
  static const String _userKey = 'user';

  /// Proactive refresh fires when the access token is within this window of
  /// expiring. Picked to be larger than typical request latency on flaky
  /// networks (ngrok, mobile data) so a request never goes out with a token
  /// that will expire mid-flight.
  static const Duration _proactiveRefreshWindow = Duration(seconds: 60);

  final Box<dynamic> _box;
  Future<String?> Function()? _refreshCallback;

  AuthSession? _session;
  User? _cachedUser;

  /// Coalesces concurrent refresh attempts. When several requests fire at
  /// once after a long idle, all of them observe the expiring token and
  /// would each call the refresh endpoint — Supabase rotates refresh
  /// tokens on every use, so the second call would invalidate the first.
  /// We share a single in-flight Future across callers instead.
  Future<String?>? _inflightRefresh;

  static Future<AuthTokenStore> create() async {
    const tag = 'smwhr.auth';
    final box = await Hive.openBox<dynamic>(boxName);
    final store = AuthTokenStore._(box);
    final rawSession = box.get(_sessionKey);
    if (rawSession is Map) {
      try {
        store._session = AuthSession.fromJson(rawSession);
      } catch (e) {
        debugPrint('[$tag] store: session JSON corrupt, dropping ($e)');
        await box.delete(_sessionKey);
      }
    }
    final rawUser = box.get(_userKey);
    if (rawUser is Map) {
      try {
        store._cachedUser = userFromJson(rawUser.cast<String, dynamic>());
      } catch (e) {
        debugPrint('[$tag] store: user JSON corrupt, dropping ($e)');
        await box.delete(_userKey);
      }
    }
    final s = store._session;
    if (s == null) {
      debugPrint('[$tag] store: opened, NO SESSION');
    } else {
      final exp = s.expiresAt;
      final now = DateTime.now();
      final delta = exp == null
          ? '(no expiry)'
          : '(expires ${exp.toIso8601String()}, '
              '${exp.isBefore(now) ? "EXPIRED ${now.difference(exp).inMinutes}min ago" : "in ${exp.difference(now).inMinutes}min"})';
      debugPrint(
        '[$tag] store: opened, session userId=${s.userId} '
        'access(${s.accessToken.length}B) refresh=${s.refreshToken == null ? "null" : "${s.refreshToken!.length}B"} $delta',
      );
    }
    return store;
  }

  AuthSession? get session => _session;
  User? get cachedUser => _cachedUser;

  Future<void> saveSession(AuthSession session) async {
    _session = session;
    await _box.put(_sessionKey, session.toJson());
  }

  Future<void> saveCachedUser(User user) async {
    _cachedUser = user;
    await _box.put(_userKey, userToJson(user));
  }

  Future<void> clear() async {
    _session = null;
    _cachedUser = null;
    await _box.delete(_sessionKey);
    await _box.delete(_userKey);
  }

  /// Repository registers an /auth/refresh closure here so tryRefresh()
  /// can swap a 401 for a fresh access token without coupling the store
  /// to the API client.
  void registerRefreshCallback(Future<String?> Function() refresh) {
    _refreshCallback = refresh;
  }

  @override
  Future<String?> readAccessToken() async {
    final session = _session;
    if (session == null) return null;
    // Skip the proactive path while a refresh is already running — the
    // refresh request itself reads the token via this same method, and we
    // don't want to recurse. The refresh endpoint is @Public on the API
    // side, so handing it the about-to-expire token is harmless.
    //
    // Also skip when no callback is registered yet (early boot, before
    // RealAuthRepository finishes constructing). There's no one to
    // refresh against — surfacing the cached token avoids a noisy log
    // line every cold start.
    if (_inflightRefresh == null &&
        _refreshCallback != null &&
        session.expiresWithin(_proactiveRefreshWindow)) {
      debugPrint(
        '[smwhr.auth] store.readAccessToken: token expiring soon → proactive refresh',
      );
      final refreshed = await tryRefresh();
      if (refreshed != null) return refreshed;
    }
    return _session?.accessToken;
  }

  @override
  Future<String?> tryRefresh() async {
    final inflight = _inflightRefresh;
    if (inflight != null) {
      debugPrint('[smwhr.auth] store.tryRefresh: joining inflight');
      return inflight;
    }
    final cb = _refreshCallback;
    if (cb == null) {
      debugPrint('[smwhr.auth] store.tryRefresh: NO CALLBACK registered (race?)');
      return null;
    }
    debugPrint('[smwhr.auth] store.tryRefresh: calling /auth/refresh');
    final future = cb();
    _inflightRefresh = future;
    try {
      final result = await future;
      debugPrint(
        '[smwhr.auth] store.tryRefresh: ${result == null ? "FAILED (null)" : "ok new token(${result.length}B)"}',
      );
      return result;
    } finally {
      _inflightRefresh = null;
    }
  }
}
