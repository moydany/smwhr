import 'dart:async';
import 'dart:math' as math;

import 'package:locus/locus.dart';

import '../../../data/models/lat_lng.dart';
import '../../../data/models/quest.dart';

/// Primary tracker. Wraps `package:locus` so the rest of the app talks
/// in our `LocusEvent` shape, not the plugin's.
///
/// Locus 2.x exposes:
///   - `Locus.location.stream`     → ongoing location updates
///   - `Locus.location.motionChanges` → stationary/moving transitions
///   - `Locus.location.heartbeats`    → heartbeat ticks
///   - `Locus.geofencing.polygonEvents` → enter / exit / dwell on a
///     polygon registered via `Locus.geofencing.addPolygon(...)`
///
/// We register the event polygon as a [PolygonGeofence] (when there are
/// at least 3 vertices) and translate every callback into a [LocusEvent]
/// the rest of the pipeline already understands. With `polygon` empty,
/// we still spin up the location/motion/heartbeat subscriptions so the
/// reconciliation engine has data — the dwell signal just won't be a
/// geofence transition, it'll be derived from the points themselves.
class LocusTracker {
  StreamSubscription<Location>? _locationSub;
  StreamSubscription<Location>? _motionSub;
  StreamSubscription<Location>? _heartbeatSub;
  StreamSubscription<PolygonGeofenceEvent>? _polygonSub;
  String? _activeGeofenceId;
  bool _running = false;

  bool get isRunning => _running;

  Future<void> start({
    required String eventId,
    required List<LatLng> polygon,
    required void Function(LocusEvent) onEvent,
    String Function() idGenerator = _defaultId,
  }) async {
    if (_running) {
      throw StateError('LocusTracker already running. Call stop() first.');
    }

    await Locus.ready(const Config(
      desiredAccuracy: DesiredAccuracy.high,
      distanceFilter: 10,
      motionTriggerDelay: 30,
      heartbeatInterval: 60,
      stopOnTerminate: false,
      startOnBoot: true,
      // Android foreground-service notification copy. Pinned ES so the
      // user always sees the same message when the persistent
      // notification appears while a quest is active.
      notification: NotificationConfig(
        title: 'smwhr',
        text: 'Verificando tu quest. Te avisamos cuando termine.',
        importance: 2, // default — visible but not noisy
      ),
    ));

    if (polygon.length >= 3) {
      await Locus.geofencing.addPolygon(
        PolygonGeofence(
          identifier: eventId,
          vertices: polygon
              .map((p) => GeoPoint(latitude: p.latitude, longitude: p.longitude))
              .toList(growable: false),
          notifyOnEntry: true,
          notifyOnExit: true,
          notifyOnDwell: true,
          loiteringDelay: 60000, // 1 min
        ),
      );
      _activeGeofenceId = eventId;

      _polygonSub = Locus.geofencing.polygonEvents.listen((evt) {
        if (evt.geofence.identifier != eventId) return;
        onEvent(_locusEventFromPolygon(eventId, evt, idGenerator));
      });
    }

    _locationSub = Locus.location.stream.listen((loc) {
      onEvent(_locusEventFromLocation(
        eventId,
        loc,
        LocusEventType.locationUpdate,
        idGenerator,
      ));
    });
    _motionSub = Locus.location.motionChanges.listen((loc) {
      onEvent(_locusEventFromLocation(
        eventId,
        loc,
        LocusEventType.motionChange,
        idGenerator,
      ));
    });
    _heartbeatSub = Locus.location.heartbeats.listen((loc) {
      onEvent(_locusEventFromLocation(
        eventId,
        loc,
        LocusEventType.heartbeat,
        idGenerator,
      ));
    });

    await Locus.start();
    _running = true;
  }

  Future<void> stop() async {
    await _locationSub?.cancel();
    await _motionSub?.cancel();
    await _heartbeatSub?.cancel();
    await _polygonSub?.cancel();
    _locationSub = _motionSub = _heartbeatSub = _polygonSub = null;

    if (_activeGeofenceId != null) {
      await Locus.geofencing.removePolygon(_activeGeofenceId!);
      _activeGeofenceId = null;
    }
    await Locus.stop();
    _running = false;
  }

  LocusEvent _locusEventFromLocation(
    String eventId,
    Location loc,
    LocusEventType type,
    String Function() idGenerator,
  ) {
    return LocusEvent(
      id: idGenerator(),
      eventId: eventId,
      type: type,
      timestamp: loc.timestamp,
      latitude: loc.coords.latitude,
      longitude: loc.coords.longitude,
      accuracy: loc.coords.accuracy,
    );
  }

  LocusEvent _locusEventFromPolygon(
    String eventId,
    PolygonGeofenceEvent evt,
    String Function() idGenerator,
  ) {
    final type = switch (evt.type) {
      PolygonGeofenceEventType.enter => LocusEventType.geofenceEnter,
      PolygonGeofenceEventType.exit => LocusEventType.geofenceExit,
      PolygonGeofenceEventType.dwell => LocusEventType.geofenceDwell,
    };
    return LocusEvent(
      id: idGenerator(),
      eventId: eventId,
      type: type,
      timestamp: evt.timestamp,
      latitude: evt.triggerLocation?.latitude,
      longitude: evt.triggerLocation?.longitude,
      raw: {'action': evt.type.name},
    );
  }

  static String _defaultId() {
    final r = math.Random();
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = r.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
    return 'locus_${ts}_$rand';
  }
}
