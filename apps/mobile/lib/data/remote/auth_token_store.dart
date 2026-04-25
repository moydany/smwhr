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

  final Box<dynamic> _box;
  Future<String?> Function()? _refreshCallback;

  AuthSession? _session;
  User? _cachedUser;

  static Future<AuthTokenStore> create() async {
    final box = await Hive.openBox<dynamic>(boxName);
    final store = AuthTokenStore._(box);
    final rawSession = box.get(_sessionKey);
    if (rawSession is Map) {
      try {
        store._session = AuthSession.fromJson(rawSession);
      } catch (_) {
        await box.delete(_sessionKey);
      }
    }
    final rawUser = box.get(_userKey);
    if (rawUser is Map) {
      try {
        store._cachedUser = userFromJson(rawUser.cast<String, dynamic>());
      } catch (_) {
        await box.delete(_userKey);
      }
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
  Future<String?> readAccessToken() async => _session?.accessToken;

  @override
  Future<String?> tryRefresh() async {
    final cb = _refreshCallback;
    if (cb == null) return null;
    return cb();
  }
}
