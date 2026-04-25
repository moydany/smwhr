import 'package:dio/dio.dart';

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

    _instance = ApiClient._(dio);
    return _instance!;
  }
}
