/// Active quest state surfaced to the UI.
///
/// In mock mode, this is mutated by `MockQuestsRepository`. In real mode
/// it'll be derived from `LocusEvent` / `GeolocatorPing` streams + the
/// backend's `GET /quests/:eventId/status`.
class QuestStatus {
  final String eventId;
  final bool isActive;
  final int dwellMinutes;
  final QuestChecks checks;
  final DateTime? startedAt;

  const QuestStatus({
    required this.eventId,
    required this.isActive,
    required this.dwellMinutes,
    required this.checks,
    this.startedAt,
  });

  /// Threshold below which the camera CTA stays disabled. The real value
  /// comes from `Event.dwellMinimumMin` on the active event.
  bool isReadyForCapture(int dwellMinimumMin) =>
      isActive && dwellMinutes >= dwellMinimumMin && checks.areAllPassing;

  factory QuestStatus.notStarted(String eventId) => QuestStatus(
        eventId: eventId,
        isActive: false,
        dwellMinutes: 0,
        checks: const QuestChecks.allFalse(),
      );

  QuestStatus copyWith({
    bool? isActive,
    int? dwellMinutes,
    QuestChecks? checks,
    DateTime? startedAt,
  }) {
    return QuestStatus(
      eventId: eventId,
      isActive: isActive ?? this.isActive,
      dwellMinutes: dwellMinutes ?? this.dwellMinutes,
      checks: checks ?? this.checks,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

/// Four verification checks shown on the active quest screen.
class QuestChecks {
  final bool gpsVerified;
  final bool deviceTrusted;
  final bool integrityActive;
  final bool photoCapture;

  const QuestChecks({
    required this.gpsVerified,
    required this.deviceTrusted,
    required this.integrityActive,
    required this.photoCapture,
  });

  const QuestChecks.allFalse()
      : gpsVerified = false,
        deviceTrusted = false,
        integrityActive = false,
        photoCapture = false;

  bool get areAllPassing =>
      gpsVerified && deviceTrusted && integrityActive && photoCapture;

  int get passingCount =>
      (gpsVerified ? 1 : 0) +
      (deviceTrusted ? 1 : 0) +
      (integrityActive ? 1 : 0) +
      (photoCapture ? 1 : 0);

  QuestChecks copyWith({
    bool? gpsVerified,
    bool? deviceTrusted,
    bool? integrityActive,
    bool? photoCapture,
  }) {
    return QuestChecks(
      gpsVerified: gpsVerified ?? this.gpsVerified,
      deviceTrusted: deviceTrusted ?? this.deviceTrusted,
      integrityActive: integrityActive ?? this.integrityActive,
      photoCapture: photoCapture ?? this.photoCapture,
    );
  }
}

/// Raw event captured by Locus during a quest. Persisted to Hive locally,
/// uploaded in batches by `TrackingSync` (Session 7).
class LocusEvent {
  final String id;
  final String eventId;
  final LocusEventType type;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final Map<String, dynamic> raw;

  const LocusEvent({
    required this.id,
    required this.eventId,
    required this.type,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.raw = const {},
  });
}

enum LocusEventType {
  geofenceEnter,
  geofenceExit,
  geofenceDwell,
  locationUpdate,
  motionChange,
  heartbeat,
}

/// Periodic geolocator ping (shadow tracker, every 5 min during quests).
class GeolocatorPing {
  final String id;
  final String eventId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isInsidePolygon;

  const GeolocatorPing({
    required this.id,
    required this.eventId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isInsidePolygon,
  });
}
