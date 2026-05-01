import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../../../data/models/lat_lng.dart';
import '../../../data/models/quest.dart';

/// Shadow / spot-check tracker. Independent from Locus on purpose — if
/// the primary tracker is silently broken (OS killed it, plugin bug,
/// geofence never fired), our reads still feed the backend
/// reconciliation engine and the verification-task UI.
///
/// Two modes:
///
///   - **Fixed cadence** ([start]) — the legacy 5-min periodic mode,
///     kept for tests + back-compat.
///   - **Randomized** ([startRandomized]) — picks `targetCount` random
///     timestamps within the remaining event window, with a minimum
///     spacing so they don't bunch up. This is what production runs:
///     unpredictable timing makes spoofing more expensive (an attacker
///     would have to fake GPS continuously, not just at known cadence
///     points) and powers the "spot-checks N/M" task on the active
///     quest screen.
///
/// Each fire:
///   1. Request the current position (high accuracy, 10 s timeout).
///   2. Ray-cast the position against the event polygon → `isInsidePolygon`.
///   3. Hand a [GeolocatorPing] to [onPing].
///
/// Battery-saver guard (locked decision #3): we'd skip the ping when
/// battery < 5%, but `battery_plus` isn't in pubspec yet — defaulting to
/// "always ping" until it lands. The default is documented in the plan.
class GeolocatorTracker {
  Timer? _timer;
  Timer? _nextRandomTimer;
  StreamSubscription<Position>? _bgStream;
  Position? _latestPosition;
  bool _running = false;

  /// Default ping interval. Override in tests via [start]'s `interval`.
  static const Duration defaultInterval = Duration(minutes: 5);

  /// Default per-position timeout from `Geolocator.getCurrentPosition`.
  /// Tight enough that a single bad fix doesn't hold up the next tick.
  static const Duration positionTimeout = Duration(seconds: 10);

  /// Minimum spacing between two consecutive randomized fires. Keeps
  /// the spot-checks visibly spread out across the event window even
  /// when the random draw clusters a few near each other.
  static const Duration minRandomSpacing = Duration(minutes: 5);

  bool get isRunning => _running;

  Future<void> start({
    required String eventId,
    required List<LatLng> polygon,
    required void Function(GeolocatorPing) onPing,
    Duration interval = defaultInterval,
    String Function() idGenerator = _defaultId,
  }) async {
    if (_running) {
      throw StateError('GeolocatorTracker already running. Call stop() first.');
    }
    _running = true;
    _timer = Timer.periodic(interval, (_) async {
      await _tick(
        eventId: eventId,
        polygon: polygon,
        onPing: onPing,
        idGenerator: idGenerator,
      );
    });
  }

  /// Random spot-check mode.
  ///
  /// Picks [targetCount] firing timestamps spread across `[now,
  /// eventEndsAt]`, schedules each as a one-shot [Timer], and tears
  /// itself down once the last one fires (or when [stop] is called).
  /// Falls back to [start] with [defaultInterval] if the event window
  /// has already closed or is shorter than [minRandomSpacing] — better
  /// to ping on cadence than not at all.
  Future<void> startRandomized({
    required String eventId,
    required List<LatLng> polygon,
    required DateTime eventEndsAt,
    required int targetCount,
    required void Function(GeolocatorPing) onPing,
    String Function() idGenerator = _defaultId,
    math.Random? rng,
  }) async {
    if (_running) {
      throw StateError('GeolocatorTracker already running. Call stop() first.');
    }
    final now = DateTime.now();
    final remaining = eventEndsAt.difference(now);
    // Only fall back to fixed-cadence mode for genuinely-degenerate
    // windows (≤1 min). Short-but-usable windows (5–30 min smoke
    // tests) still go through the randomized scheduler — the slot
    // calculation in `_pickRandomFirings` adapts spacing to the
    // window, so a 5-min event still gets 3 well-distributed fires.
    if (remaining < const Duration(minutes: 1) || targetCount < 1) {
      return start(
        eventId: eventId,
        polygon: polygon,
        onPing: onPing,
        idGenerator: idGenerator,
      );
    }
    _running = true;

    // Background-capable continuous position stream. Two purposes:
    //
    //   1. **Keeps the app alive in background** on iOS — without
    //      `allowBackgroundLocationUpdates: true` paired with the
    //      `UIBackgroundModes: location` Info.plist entry, iOS
    //      suspends the app within ~30s of going to the home screen
    //      and our spot-check `Timer`s + `TrackingSync.schedulePeriodic`
    //      stop firing. This stream is the lifeline that lets the dwell
    //      counter keep ticking when the user switches apps.
    //   2. **Caches the latest position** so each scheduled spot-check
    //      doesn't have to wait on a fresh `getCurrentPosition` round
    //      trip — we sample what the OS already delivered.
    //
    // We subscribe but ignore most updates; the only state we keep is
    // the latest position. Locus owns the high-fidelity track.
    try {
      _bgStream = Geolocator.getPositionStream(
        locationSettings: _backgroundSettings(),
      ).listen(
        (pos) => _latestPosition = pos,
        onError: (_) {
          // Tolerate transient stream errors; the spot-check fallback
          // path retries `getCurrentPosition` directly when the cache
          // is empty.
        },
      );
    } catch (_) {
      // Tests / simulators without a position provider — drop the
      // background stream, the random scheduler still falls back to
      // `getCurrentPosition` per fire.
    }

    final firings = _pickRandomFirings(
      from: now,
      until: eventEndsAt,
      count: targetCount,
      minSpacing: minRandomSpacing,
      rng: rng ?? math.Random(),
    );
    _scheduleNextRandomized(
      remaining: firings,
      eventId: eventId,
      polygon: polygon,
      onPing: onPing,
      idGenerator: idGenerator,
    );
  }

  /// Platform-specific [LocationSettings] for the background stream.
  /// iOS needs `allowBackgroundLocationUpdates: true`; Android needs a
  /// foreground service notification when targeting API 26+.
  static LocationSettings _backgroundSettings() {
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 25,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'Verificando tu quest',
          notificationTitle: 'smwhr',
          enableWakeLock: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    );
  }

  void _scheduleNextRandomized({
    required List<DateTime> remaining,
    required String eventId,
    required List<LatLng> polygon,
    required void Function(GeolocatorPing) onPing,
    required String Function() idGenerator,
  }) {
    if (!_running || remaining.isEmpty) return;
    final next = remaining.first;
    final delay = next.difference(DateTime.now());
    _nextRandomTimer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      if (!_running) return;
      await _tick(
        eventId: eventId,
        polygon: polygon,
        onPing: onPing,
        idGenerator: idGenerator,
      );
      _scheduleNextRandomized(
        remaining: remaining.sublist(1),
        eventId: eventId,
        polygon: polygon,
        onPing: onPing,
        idGenerator: idGenerator,
      );
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _nextRandomTimer?.cancel();
    _nextRandomTimer = null;
    await _bgStream?.cancel();
    _bgStream = null;
    _latestPosition = null;
    _running = false;
  }

  Future<void> _tick({
    required String eventId,
    required List<LatLng> polygon,
    required void Function(GeolocatorPing) onPing,
    required String Function() idGenerator,
  }) async {
    // Prefer the cached position from the background stream — by the
    // time a spot-check fires we usually have a fix that's seconds
    // old, no need to spin up another GPS request. Fall back to a
    // one-shot `getCurrentPosition` when the stream hasn't delivered
    // its first update yet (cold-start race) or when we're not in
    // randomized mode.
    Position? position = _latestPosition;
    if (position == null) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: positionTimeout,
          ),
        );
      } catch (_) {
        // Shadow tracker is best-effort. The next tick retries; the
        // primary (Locus) is the source of truth either way.
        return;
      }
    }
    onPing(
      GeolocatorPing(
        id: idGenerator(),
        eventId: eventId,
        timestamp: DateTime.now().toUtc(),
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        isInsidePolygon: isInsidePolygon(
          LatLng(position.latitude, position.longitude),
          polygon,
        ),
      ),
    );
  }

  static String _defaultId() {
    final r = math.Random();
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = r.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
    return 'ping_${ts}_$rand';
  }
}

/// Picks [count] firing timestamps within `[from, until]`. Slot-based:
/// the window is divided into [count] equal slots, one firing per slot
/// at a random offset. The slot-based scheme guarantees coverage (one
/// fire per fraction of the event) AND randomness (timing within each
/// slot is unpredictable to anyone trying to spoof location). Min
/// spacing protects against the rare case where two adjacent slots
/// pick a near-boundary time and bunch up.
List<DateTime> _pickRandomFirings({
  required DateTime from,
  required DateTime until,
  required int count,
  required Duration minSpacing,
  required math.Random rng,
}) {
  assert(count >= 1);
  final total = until.difference(from);
  if (total <= Duration.zero) return const [];
  final slot = Duration(microseconds: total.inMicroseconds ~/ count);

  // Adaptive spacing — for tight windows the constant 5-min floor
  // would collapse every pick to the slot boundary, defeating the
  // randomization. We cap the effective floor at half a slot so
  // adjacent picks always have room to vary.
  final effectiveMin = Duration(
    microseconds: math.min(
      minSpacing.inMicroseconds,
      slot.inMicroseconds ~/ 2,
    ),
  );

  final firings = <DateTime>[];
  DateTime? prev;
  for (var i = 0; i < count; i++) {
    final slotStart = from.add(slot * i);
    final slotEnd = i == count - 1 ? until : from.add(slot * (i + 1));
    final span = slotEnd.difference(slotStart);
    if (span <= Duration.zero) break;
    // Random.nextInt caps at 2^32, so use a double-scaled range — slots
    // longer than ~71 minutes (in microseconds) blow past that limit.
    final offsetUs = (rng.nextDouble() * span.inMicroseconds).floor();
    var pick = slotStart.add(Duration(microseconds: offsetUs));
    if (prev != null) {
      final earliest = prev.add(effectiveMin);
      if (pick.isBefore(earliest)) {
        pick = earliest.isBefore(slotEnd) ? earliest : slotEnd;
      }
    }
    firings.add(pick);
    prev = pick;
  }
  return firings;
}

/// Ray-casting point-in-polygon test on the WGS84 plane.
///
/// Treats the polygon as a closed loop; the caller doesn't need to repeat
/// the first vertex at the end (the seed *does* — the duplicate is
/// harmless, the algorithm just skips a degenerate edge).
///
/// Edge / vertex points are ambiguous at floating-point precision; for
/// the smwhr use case (venues are tens to hundreds of metres across) the
/// "edge case" is academic and gets handled by the dwell threshold
/// downstream. Tests pin the *unambiguous* center / outside cases.
///
/// Returns `false` for an empty or sub-triangle polygon.
bool isInsidePolygon(LatLng point, List<LatLng> polygon) {
  if (polygon.length < 3) return false;
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].longitude, yi = polygon[i].latitude;
    final xj = polygon[j].longitude, yj = polygon[j].latitude;
    final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
        (point.longitude <
            (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}
