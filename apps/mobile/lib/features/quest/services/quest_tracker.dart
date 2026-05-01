import 'dart:async';

import '../../../data/local/tracking_db.dart';
import '../../../data/repositories/events_repository.dart';
import 'geolocator_tracker.dart';
import 'locus_tracker.dart';
import 'permission_flow.dart';
import 'tracking_sync.dart';

/// Lifecycle-owning orchestrator for an active quest.
///
/// Bridges six things — permissions, the dual-track trackers, Hive
/// persistence, the periodic sync, and the EventsRepository for polygon
/// lookup — so the screen / repo just calls `startQuest(eventId)` and
/// `stopQuest(eventId)` and the rest happens.
///
/// Per locked decision #9, only one event is active at a time. Calling
/// `startQuest` while another quest is in flight will fail at the tracker
/// level (LocusTracker / GeolocatorTracker both throw if already running).
class QuestTracker {
  QuestTracker({
    required this.permissionFlow,
    required this.locusTracker,
    required this.geolocatorTracker,
    required this.trackingDb,
    required this.trackingSync,
    required this.eventsRepository,
  });

  final PermissionFlow permissionFlow;
  final LocusTracker locusTracker;
  final GeolocatorTracker geolocatorTracker;
  final TrackingDb trackingDb;
  final TrackingSync trackingSync;
  final EventsRepository eventsRepository;

  String? _activeEventId;

  /// `null` when no quest is in flight; otherwise the eventId of the
  /// currently-tracking quest. Lets the active-quest screen safely call
  /// [startQuest] on every mount without re-prompting for permissions
  /// or double-starting the trackers.
  String? get activeEventId => _activeEventId;
  bool get isRunning => _activeEventId != null;

  Future<void> startQuest(String eventId) async {
    // Idempotent for the active event. The screen calls startQuest
    // unconditionally on mount because the backend's `isActive` flag
    // reflects event time-window, NOT local tracker state — we can't
    // use it to decide whether to skip.
    if (_activeEventId == eventId) return;
    if (_activeEventId != null) {
      throw QuestException(
        'Another quest is active for $_activeEventId. Stop it first.',
      );
    }

    final event = await eventsRepository.getEventById(eventId);
    if (event == null) {
      throw QuestException('Event $eventId not found');
    }

    final perm = await permissionFlow.requestForActiveQuest(event);
    if (!perm.isGranted) {
      throw QuestPermissionException(perm);
    }

    await trackingDb.open(eventId);

    await locusTracker.start(
      eventId: eventId,
      polygon: event.geofencePolygon,
      onEvent: (e) => trackingDb.appendLocusEvent(eventId, e),
    );

    // Random spot-checks across the event window — unpredictable timing
    // is the verification feature here, not just a battery-saver tweak.
    // Target count mirrors what the backend reports in `targetSpotCheckCount`
    // (≈one per half-hour, clamped 3–6); deriving it locally is fine
    // because the formula is the same and the UI uses the backend value
    // for the "N/M" display anyway. `endsAt` defaults to startsAt + 4h
    // when missing, matching `Event.isLive`'s fallback so the rest of
    // the app stays consistent.
    final eventEndsAt =
        event.endsAt ?? event.startsAt.add(const Duration(hours: 4));
    final targetCount =
        _targetSpotCheckCount(eventEndsAt.difference(event.startsAt));
    await geolocatorTracker.startRandomized(
      eventId: eventId,
      polygon: event.geofencePolygon,
      eventEndsAt: eventEndsAt,
      targetCount: targetCount,
      onPing: (p) => trackingDb.appendGeolocatorPing(eventId, p),
    );

    trackingSync.schedulePeriodic(eventId);
    _activeEventId = eventId;
  }

  /// Mirrors backend `targetSpotCheckCount` in
  /// `apps/api/src/quests/verification-tasks.constants.ts`. Keep in
  /// sync — mobile schedules this many random firings, backend gates
  /// verification at 40% of this count landing in-polygon.
  static int _targetSpotCheckCount(Duration eventDuration) {
    final raw = (eventDuration.inMinutes / 1.5).round();
    if (raw < 4) return 4;
    if (raw > 20) return 20;
    return raw;
  }

  Future<void> stopQuest(String eventId) async {
    if (_activeEventId != eventId) return;
    await locusTracker.stop();
    await geolocatorTracker.stop();
    await trackingSync.finalSync(eventId);
    await trackingDb.close(eventId);
    _activeEventId = null;
  }
}

class QuestException implements Exception {
  final String message;
  const QuestException(this.message);
  @override
  String toString() => 'QuestException: $message';
}

class QuestPermissionException implements Exception {
  final PermissionResult result;
  const QuestPermissionException(this.result);
  @override
  String toString() =>
      'QuestPermissionException: ${result.outcome.name}'
      '${result.shouldOpenSettings ? ' (open settings)' : ''}';
}
