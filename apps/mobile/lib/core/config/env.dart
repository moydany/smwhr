/// Runtime configuration flags for smwhr.
///
/// Defaults are tuned for TestFlight builds against the static ngrok
/// tunnel. To override at build/run time:
///
///     flutter run --dart-define=USE_MOCKS=true        # mock-mode
///     flutter run --dart-define=API_BASE_URL=https://other-host
class Env {
  Env._();

  /// Mock-mode flag. Defaults to false so cold-launch hits the real
  /// backend; pass `--dart-define=USE_MOCKS=true` for design-QA / unit
  /// flows that don't need a network round-trip.
  static const bool useMocks =
      bool.fromEnvironment('USE_MOCKS', defaultValue: false);

  /// Base URL for the NestJS API. Pointing at the Railway production
  /// service so TestFlight builds work without an active local
  /// tunnel. Replace with `api.smwhr.dev` (or whatever the eventual
  /// pretty domain is) once DNS is set up.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-production-7e5a.up.railway.app',
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

  /// Quest tracker sync cadence (seconds). Default 15s for the
  /// TestFlight soft-launch — keeps the verification UI snappy and
  /// gives `syncFn`'s tail-call to `/finalize` plenty of chances to
  /// land the badge mid-event. Bump to `1800` (30 min, locked
  /// decision #4) for the broad-rollout build to cut traffic ~120×.
  ///
  ///     flutter run --dart-define=QUEST_SYNC_INTERVAL_SECONDS=1800
  static const int questSyncIntervalSeconds = int.fromEnvironment(
    'QUEST_SYNC_INTERVAL_SECONDS',
    defaultValue: 15,
  );

  /// Override the active-quest dwell threshold to a fixed number of
  /// seconds. `0` means "use `event.dwellMinimumMin × 60`", i.e.
  /// honour the backend value.
  ///
  /// Default 30s for the TestFlight soft-launch so testers can run
  /// the full quest flow in under a minute without sitting in the
  /// venue for 5+ minutes. Set to `0` for the broad-rollout build:
  ///
  ///     flutter run --dart-define=QUEST_DWELL_SECONDS_OVERRIDE=0
  ///
  /// Drives a *local* clock: the active-quest screen counts seconds
  /// since the first GPS-verified status arrived from the backend.
  static const int questDwellSecondsOverride = int.fromEnvironment(
    'QUEST_DWELL_SECONDS_OVERRIDE',
    defaultValue: 30,
  );
}
