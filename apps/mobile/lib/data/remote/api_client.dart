import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../../core/config/env.dart';
import 'auth_interceptor.dart';

/// Dio singleton used by every Real* repository in Phase 2.
///
/// Reads `Env.apiBaseUrl` at construction time. Logs are off by default
/// — flip to `LogInterceptor` while integrating against the live API.
class ApiClient {
  ApiClient._(this._dio);

  final Dio _dio;
  Dio get dio => _dio;

  static ApiClient? _instance;

  /// Lazy singleton. Call once from `main()` (or the FutureProvider that
  /// owns it) and reuse the same Dio for the lifetime of the app.
  factory ApiClient.create({String? baseUrl, AuthTokenSource? tokens}) {
    if (_instance != null) return _instance!;
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: const {
        'accept': 'application/json',
        'content-type': 'application/json',
      },
    ));

    if (tokens != null) {
      dio.interceptors.add(AuthInterceptor(tokens));
    }

    // Diagnostic: one-line per request in debug builds. Sits AFTER the
    // auth interceptor so it sees the final request that actually
    // hits the wire (including the resolved Authorization header
    // length, which is the cheap way to confirm a token attached
    // without leaking the token itself).
    if (kDebugMode) {
      dio.interceptors.add(_DiagInterceptor());
    }

    _instance = ApiClient._(dio);
    return _instance!;
  }
}

/// Compact request/response logger. Uses `debugPrint` so the lines
/// land in the `flutter run` stdout reliably across iOS / Android /
/// simulator / physical device.
class _DiagInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final auth = options.headers['authorization'] as String?;
    final authTag = auth == null ? 'no-auth' : 'bearer(${auth.length})';
    options.extra['_t0'] = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[smwhr.api] → ${options.method} ${options.uri} · $authTag');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final t0 = response.requestOptions.extra['_t0'] as int? ??
        DateTime.now().millisecondsSinceEpoch;
    final ms = DateTime.now().millisecondsSinceEpoch - t0;
    final size = response.data is List
        ? '${(response.data as List).length} items'
        : '${response.data?.toString().length ?? 0}B';
    debugPrint(
      '[smwhr.api] ← ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.uri} · ${ms}ms · $size',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final t0 = err.requestOptions.extra['_t0'] as int? ??
        DateTime.now().millisecondsSinceEpoch;
    final ms = DateTime.now().millisecondsSinceEpoch - t0;
    final code = err.response?.statusCode;
    debugPrint(
      '[smwhr.api] ✗ ${code ?? err.type.name} ${err.requestOptions.method} '
      '${err.requestOptions.uri} · ${ms}ms · ${err.message ?? ""}',
    );
    handler.next(err);
  }
}
