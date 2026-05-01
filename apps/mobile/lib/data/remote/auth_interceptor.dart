import 'package:dio/dio.dart';

/// Pluggable token source so the interceptor doesn't tie itself to Hive
/// or Supabase directly. The mock auth repo can implement this with the
/// same Hive box it already owns; in Phase 2 the Supabase session bridge
/// implements it.
abstract class AuthTokenSource {
  Future<String?> readAccessToken();

  /// Optional. Only invoked on a 401. Implementations can swap a refresh
  /// token for a fresh access token here. Return null to give up — the
  /// original 401 propagates.
  Future<String?> tryRefresh() async => null;
}

/// Adds `Authorization: Bearer <token>` to every outbound request when a
/// token is present, and on 401 attempts a single refresh + retry.
///
/// Uses plain [Interceptor] (not [QueuedInterceptor]) on purpose: the
/// proactive refresh path inside [AuthTokenSource.readAccessToken] re-
/// enters `onRequest` for the `/auth/refresh` POST itself, and a
/// queued interceptor would deadlock the outer request waiting on the
/// inner one. Concurrent refreshes are coalesced inside the token
/// source via a single in-flight future, so we don't need the queue.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens);

  final AuthTokenSource _tokens;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }
    final refreshed = await _tokens.tryRefresh();
    if (refreshed == null) return handler.next(err);

    // Retry the original request with the new token.
    final retried = err.requestOptions.copyWith(
      headers: {
        ...err.requestOptions.headers,
        'authorization': 'Bearer $refreshed',
      },
    );
    try {
      // ignore: avoid_dynamic_calls
      final dio = Dio(); // request-scoped retry; baseUrl carries through
      final response = await dio.fetch(retried);
      handler.resolve(response);
    } catch (e) {
      handler.next(err);
    }
  }
}
