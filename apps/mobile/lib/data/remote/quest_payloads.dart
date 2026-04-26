import '../models/quest.dart';

/// Wire-format mappers for the dual-track tracker batch sync.
///
/// Lives outside `RealQuestsRepository` so [TrackingSync] can build the
/// HTTP body without taking a dependency on the full repository (which
/// would create a cycle: repo → tracker → sync → repo).

Map<String, dynamic> locusEventToJson(LocusEvent e) => {
      'eventType': locusEventTypeToBackend(e.type),
      'latitude': e.latitude ?? 0,
      'longitude': e.longitude ?? 0,
      if (e.accuracy != null) 'accuracy': e.accuracy,
      'timestamp': e.timestamp.toIso8601String(),
      if (e.raw.isNotEmpty) 'rawPayload': e.raw,
    };

Map<String, dynamic> geolocatorPingToJson(GeolocatorPing p) => {
      'latitude': p.latitude,
      'longitude': p.longitude,
      'accuracy': p.accuracy,
      'timestamp': p.timestamp.toIso8601String(),
    };

/// Mobile [LocusEventType] → backend `LocusEventType` enum string.
///
/// `geofenceDwell`, `motionChange`, `heartbeat` collapse to the closest
/// backend equivalent — the backend reconciliation engine doesn't (yet)
/// distinguish dwell/heartbeat from a regular location point.
String locusEventTypeToBackend(LocusEventType t) => switch (t) {
      LocusEventType.geofenceEnter => 'GEOFENCE_ENTER',
      LocusEventType.geofenceExit => 'GEOFENCE_EXIT',
      LocusEventType.geofenceDwell => 'LOCATION_UPDATE',
      LocusEventType.locationUpdate => 'LOCATION_UPDATE',
      LocusEventType.motionChange => 'MOTION_CHANGE',
      LocusEventType.heartbeat => 'LOCATION_UPDATE',
    };
