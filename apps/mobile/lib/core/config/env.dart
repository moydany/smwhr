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

  /// Opt-in to boot directly into the debug menu. Off by default so cold
  /// start always lands on the real splash/auth screen — both in mock and
  /// real mode. Only honoured when [debugRoutesEnabled] is true.
  ///
  ///     flutter run --dart-define=BOOT_AT_DEBUG=true
  static const bool bootAtDebug =
      bool.fromEnvironment('BOOT_AT_DEBUG', defaultValue: false);

  /// Override the cold-start route to any path. Used for per-screen
  /// screenshots and design QA. Empty string means "use default".
  ///
  ///     flutter run --dart-define=BOOT_AT=/onboarding/identity
  static const String bootAt =
      String.fromEnvironment('BOOT_AT', defaultValue: '');

  /// Quest tracker sync cadence (seconds). Production: 30 min (locked
  /// decision #4). For dev / smoke testing against the
  /// `prueba-tulancingo-hq` event with a 5-min dwell, drop to 15-30s
  /// so the bar visibly fills:
  ///
  ///     flutter run --dart-define=QUEST_SYNC_INTERVAL_SECONDS=15
  static const int questSyncIntervalSeconds = int.fromEnvironment(
    'QUEST_SYNC_INTERVAL_SECONDS',
    defaultValue: 1800,
  );

  /// Override the active-quest dwell threshold to a fixed number of
  /// seconds. `0` (default) means "use `event.dwellMinimumMin × 60`",
  /// i.e. honour the backend value. Useful for smoke testing the
  /// progress bar + Capture-CTA gate without sitting in the venue
  /// for 5 / 45 / 60 minutes:
  ///
  ///     flutter run --dart-define=QUEST_DWELL_SECONDS_OVERRIDE=30
  ///
  /// Drives a *local* clock: the active-quest screen counts seconds
  /// since the first GPS-verified status arrived from the backend.
  /// Production should always boot with this unset.
  static const int questDwellSecondsOverride = int.fromEnvironment(
    'QUEST_DWELL_SECONDS_OVERRIDE',
    defaultValue: 0,
  );
}
