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

  Future<void> startQuest(String eventId) async {
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

    await geolocatorTracker.start(
      eventId: eventId,
      polygon: event.geofencePolygon,
      onPing: (p) => trackingDb.appendGeolocatorPing(eventId, p),
    );

    trackingSync.schedulePeriodic(eventId);
  }

  Future<void> stopQuest(String eventId) async {
    await locusTracker.stop();
    await geolocatorTracker.stop();
    await trackingSync.finalSync(eventId);
    await trackingDb.close(eventId);
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
