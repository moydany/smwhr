import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../../../data/models/lat_lng.dart';
import '../../../data/models/quest.dart';

/// Shadow tracker. Independent from Locus on purpose — if the primary
/// tracker is silently broken (OS killed it, plugin bug, geofence never
/// fired), the periodic ping still gives the backend reconciliation
/// engine something to chew on.
///
/// Cadence: every 5 minutes (locked decision #5). Configurable for
/// tests via [interval]; production is fixed.
///
/// Each tick:
///   1. Request the current position (high accuracy, 10 s timeout).
///   2. Ray-cast the position against the event polygon → `isInsidePolygon`.
///   3. Hand a [GeolocatorPing] to [onPing].
///
/// Battery-saver guard (locked decision #3): we'd skip the ping when
/// battery < 5%, but `battery_plus` isn't in pubspec yet — defaulting to
/// "always ping" until it lands. The default is documented in the plan.
class GeolocatorTracker {
  Timer? _timer;
  bool _running = false;

  /// Default ping interval. Override in tests via [start]'s `interval`.
  static const Duration defaultInterval = Duration(minutes: 5);

  /// Default per-position timeout from `Geolocator.getCurrentPosition`.
  /// Tight enough that a single bad fix doesn't hold up the next tick.
  static const Duration positionTimeout = Duration(seconds: 10);

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

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<void> _tick({
    required String eventId,
    required List<LatLng> polygon,
    required void Function(GeolocatorPing) onPing,
    required String Function() idGenerator,
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: positionTimeout,
        ),
      );
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
    } catch (_) {
      // Shadow tracker is best-effort. The next tick retries; the primary
      // (Locus) is the source of truth either way.
    }
  }

  static String _defaultId() {
    final r = math.Random();
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = r.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
    return 'ping_${ts}_$rand';
  }
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
