import '../../../data/local/photo_queue.dart';
import '../../../data/local/tracking_db.dart';
import '../../../data/models/event.dart';
import '../../../data/models/quest.dart';

/// Builds a [QuestStatus] entirely from local sources — Hive trackers
/// + the photo queue + the cached [Event]. Used as the offline
/// fallback when `GET /quests/:id/status` fails.
///
/// What we can derive without the network:
///   - **arrival** → earliest in-polygon Geolocator ping locally.
///   - **dwell** → wall-clock minutes between the first and latest
///     in-polygon ping. Approximate (the server uses a richer
///     interpolation) but good enough to keep the UI counter live.
///   - **spot-checks** → count of in-polygon pings, denominator from
///     the event's duration (mirrors the backend's `targetSpotCheckCount`).
///   - **photo** → presence of a [PendingPhoto] in the queue.
///
/// `serverTasks` is intentionally empty so the model's `tasks` getter
/// falls through to the client-side derivation. When the server comes
/// back online, the next stream tick replaces this with the persisted
/// ledger and the UI swings back to the canonical view.
Future<QuestStatus> buildLocalQuestStatus({
  required String eventId,
  required Event event,
  required TrackingDb trackingDb,
  required PhotoQueue photoQueue,
}) async {
  final pings = await _allGeolocatorPings(trackingDb, eventId);
  final inPolygonPings = pings.where((p) => p.isInsidePolygon).toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final firstInside = inPolygonPings.isNotEmpty ? inPolygonPings.first : null;
  final lastInside = inPolygonPings.isNotEmpty ? inPolygonPings.last : null;

  final dwellMinutes = (firstInside != null && lastInside != null)
      ? lastInside.timestamp.difference(firstInside.timestamp).inMinutes
      : 0;

  final pendingPhoto = photoQueue.pending(eventId);
  final hasPhoto = pendingPhoto != null;

  final endsAt = event.endsAt ?? event.startsAt.add(const Duration(hours: 4));
  final target = _targetSpotCheckCount(endsAt.difference(event.startsAt));

  final hasArrived = firstInside != null;
  final integrityActive = hasArrived; // best-effort: if we're at the
  // venue locally, treat integrity as active until the server says
  // otherwise. This keeps the camera CTA usable offline.

  return QuestStatus(
    eventId: eventId,
    isActive: true,
    dwellMinutes: dwellMinutes,
    checks: QuestChecks(
      gpsVerified: hasArrived,
      deviceTrusted: integrityActive,
      integrityActive: integrityActive,
      photoCapture: hasPhoto,
    ),
    startedAt: firstInside?.timestamp,
    inPolygonGeolocatorCount: inPolygonPings.length,
    inPolygonLocusCount: 0,
    firstInPolygonAt: firstInside?.timestamp,
    targetSpotCheckCount: target,
    serverTasks: const [],
  );
}

/// Mirrors the backend's `targetSpotCheckCount` so offline N/M matches
/// what the server will compute once the next sync lands. Kept in
/// sync with `apps/api/src/quests/verification-tasks.constants.ts`
/// and `quest_tracker.dart`'s own copy of this formula.
int _targetSpotCheckCount(Duration eventDuration) {
  final raw = (eventDuration.inMinutes / 12).round();
  if (raw < 4) return 4;
  if (raw > 20) return 20;
  return raw;
}

Future<List<GeolocatorPing>> _allGeolocatorPings(
  TrackingDb db,
  String eventId,
) =>
    db.allGeolocatorPings(eventId);
