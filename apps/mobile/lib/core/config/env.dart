/// Runtime configuration flags for smwhr.
///
/// Override via `--dart-define` at build/run time:
///
///     flutter run --dart-define=USE_MOCKS=false
///     flutter run --dart-define=API_BASE_URL=https://api.smwhr.dev
class Env {
  Env._();

  /// True until Phase 2 wires real backends. Toggling to false makes every
  /// Riverpod repository provider switch from `MockX` to `RealX` (which
  /// throws `UnimplementedError` until those are written).
  static const bool useMocks =
      bool.fromEnvironment('USE_MOCKS', defaultValue: true);

  /// Base URL for the NestJS API. Unused while [useMocks] is true.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.smwhr.dev',
  );

  /// Supabase project URL. Unused while [useMocks] is true.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anon key. Unused while [useMocks] is true.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True only on local dev / mock builds — gates the `/_debug` route.
  static bool get debugRoutesEnabled => useMocks;
}
