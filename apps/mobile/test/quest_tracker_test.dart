import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:smwhr/data/local/adapters/geolocator_ping_adapter.dart';
import 'package:smwhr/data/local/adapters/locus_event_adapter.dart';
import 'package:smwhr/data/local/tracking_db.dart';
import 'package:smwhr/data/models/event.dart';
import 'package:smwhr/data/models/event_category.dart';
import 'package:smwhr/data/models/lat_lng.dart';
import 'package:smwhr/data/models/quest.dart';
import 'package:smwhr/data/repositories/events_repository.dart';
import 'package:smwhr/features/quest/services/geolocator_tracker.dart';
import 'package:smwhr/features/quest/services/locus_tracker.dart';
import 'package:smwhr/features/quest/services/permission_flow.dart';
import 'package:smwhr/features/quest/services/quest_tracker.dart';
import 'package:smwhr/features/quest/services/tracking_sync.dart';

void main() {
  late Directory tmp;

  setUpAll(() {
    Hive.registerAdapter(LocusEventAdapter());
    Hive.registerAdapter(GeolocatorPingAdapter());
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('quest_tracker_test_');
    Hive.init(tmp.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  Event makeEvent({String id = 'event-1', List<LatLng>? polygon}) {
    return Event(
      id: id,
      slug: 'test-$id',
      title: 'Test',
      venueName: 'Venue',
      city: 'CDMX',
      countryCode: 'MX',
      startsAt: DateTime.utc(2026, 5, 7, 20, 30),
      description: '',
      category: EventCategory.music,
      geofencePolygon: polygon ??
          const [
            LatLng(19.40, -99.18),
            LatLng(19.40, -99.17),
            LatLng(19.41, -99.17),
            LatLng(19.41, -99.18),
            LatLng(19.40, -99.18),
          ],
    );
  }

  group('QuestTracker.startQuest', () {
    test('happy path: opens db, starts both trackers with the polygon, '
        'schedules the periodic sync', () async {
      final event = makeEvent();
      final perms = _GrantingPermissionFlow();
      final locus = _FakeLocusTracker();
      final geolocator = _FakeGeolocatorTracker();
      final db = TrackingDb();
      final sync = TrackingSync(
        db: db,
        syncFn: ({
          required eventId,
          required locusEvents,
          required geolocatorPings,
        }) async {},
      );
      final events = _FakeEventsRepository({event.id: event});

      final tracker = QuestTracker(
        permissionFlow: perms,
        locusTracker: locus,
        geolocatorTracker: geolocator,
        trackingDb: db,
        trackingSync: sync,
        eventsRepository: events,
      );

      await tracker.startQuest(event.id);

      expect(locus.startCount, 1);
      expect(locus.lastEventId, event.id);
      expect(locus.lastPolygon, event.geofencePolygon);
      expect(geolocator.startCount, 1);
      expect(geolocator.lastEventId, event.id);
      expect(geolocator.lastPolygon, event.geofencePolygon);
      // Hive box opened — totalCount works.
      expect(await db.totalCount(event.id), 0);

      await tracker.stopQuest(event.id);
    });

    test('throws QuestPermissionException when perms denied; does not open DB '
        'or start trackers', () async {
      final event = makeEvent();
      final perms = _DenyingPermissionFlow();
      final locus = _FakeLocusTracker();
      final geolocator = _FakeGeolocatorTracker();
      final db = TrackingDb();
      final sync = TrackingSync(
        db: db,
        syncFn: ({
          required eventId,
          required locusEvents,
          required geolocatorPings,
        }) async {},
      );
      final events = _FakeEventsRepository({event.id: event});
      final tracker = QuestTracker(
        permissionFlow: perms,
        locusTracker: locus,
        geolocatorTracker: geolocator,
        trackingDb: db,
        trackingSync: sync,
        eventsRepository: events,
      );

      expect(
        () => tracker.startQuest(event.id),
        throwsA(isA<QuestPermissionException>()),
      );

      // Wait a microtask so the rejected future settles before the asserts.
      await Future<void>.delayed(Duration.zero);
      expect(locus.startCount, 0);
      expect(geolocator.startCount, 0);
    });

    test('throws QuestException when the event id is unknown', () async {
      final perms = _GrantingPermissionFlow();
      final db = TrackingDb();
      final sync = TrackingSync(
        db: db,
        syncFn: ({
          required eventId,
          required locusEvents,
          required geolocatorPings,
        }) async {},
      );
      final tracker = QuestTracker(
        permissionFlow: perms,
        locusTracker: _FakeLocusTracker(),
        geolocatorTracker: _FakeGeolocatorTracker(),
        trackingDb: db,
        trackingSync: sync,
        eventsRepository: _FakeEventsRepository(const {}),
      );
      expect(
        () => tracker.startQuest('missing'),
        throwsA(isA<QuestException>()),
      );
    });
  });

  group('QuestTracker.stopQuest', () {
    test('cancels both trackers and final-syncs (drains via TrackingSync)',
        () async {
      final event = makeEvent();
      final locus = _FakeLocusTracker();
      final geolocator = _FakeGeolocatorTracker();
      final db = TrackingDb();
      var syncCalls = 0;
      final sync = TrackingSync(
        db: db,
        syncFn: ({
          required eventId,
          required locusEvents,
          required geolocatorPings,
        }) async {
          syncCalls++;
        },
      );
      final tracker = QuestTracker(
        permissionFlow: _GrantingPermissionFlow(),
        locusTracker: locus,
        geolocatorTracker: geolocator,
        trackingDb: db,
        trackingSync: sync,
        eventsRepository: _FakeEventsRepository({event.id: event}),
      );

      await tracker.startQuest(event.id);

      // Stuff one event into the DB so finalSync has something to drain.
      await db.appendLocusEvent(
        event.id,
        LocusEvent(
          id: 'l-1',
          eventId: event.id,
          type: LocusEventType.locationUpdate,
          timestamp: DateTime.utc(2026, 5, 7, 20, 31),
          latitude: 19.405,
          longitude: -99.175,
        ),
      );

      await tracker.stopQuest(event.id);

      expect(locus.stopCount, 1);
      expect(geolocator.stopCount, 1);
      expect(syncCalls, 1, reason: 'finalSync should fire one POST');
    });
  });

  group('TrackingSync.syncBatch', () {
    test('no-ops when there is nothing unsynced', () async {
      final db = TrackingDb();
      await db.open('e1');
      var calls = 0;
      final sync = TrackingSync(
        db: db,
        syncFn: ({
          required eventId,
          required locusEvents,
          required geolocatorPings,
        }) async {
          calls++;
        },
      );
      await sync.syncBatch('e1');
      expect(calls, 0);
      await db.close('e1');
    });

    test('posts the right shape and marks rows synced afterwards', () async {
      final db = TrackingDb();
      await db.open('e1');
      await db.appendLocusEvent(
        'e1',
        LocusEvent(
          id: 'l-1',
          eventId: 'e1',
          type: LocusEventType.geofenceEnter,
          timestamp: DateTime.utc(2026, 5, 7, 20, 30),
          latitude: 19.40,
          longitude: -99.17,
          accuracy: 8,
        ),
      );
      await db.appendGeolocatorPing(
        'e1',
        GeolocatorPing(
          id: 'p-1',
          eventId: 'e1',
          timestamp: DateTime.utc(2026, 5, 7, 20, 31),
          latitude: 19.41,
          longitude: -99.17,
          accuracy: 12,
          isInsidePolygon: true,
        ),
      );

      String? capturedEventId;
      List<LocusEvent>? capturedLocus;
      List<GeolocatorPing>? capturedPings;

      final sync = TrackingSync(
        db: db,
        syncFn: ({
          required eventId,
          required locusEvents,
          required geolocatorPings,
        }) async {
          capturedEventId = eventId;
          capturedLocus = locusEvents;
          capturedPings = geolocatorPings;
        },
      );

      await sync.syncBatch('e1');

      expect(capturedEventId, 'e1');
      expect(capturedLocus, hasLength(1));
      expect(capturedPings, hasLength(1));
      // Subsequent reads see the rows as synced.
      expect((await db.unsyncedLocusEvents('e1')), isEmpty);
      expect((await db.unsyncedGeolocatorPings('e1')), isEmpty);
      await db.close('e1');
    });

    test('does not mark synced when the POST throws (next tick retries)',
        () async {
      final db = TrackingDb();
      await db.open('e1');
      await db.appendLocusEvent(
        'e1',
        LocusEvent(
          id: 'l-1',
          eventId: 'e1',
          type: LocusEventType.locationUpdate,
          timestamp: DateTime.utc(2026, 5, 7, 20, 30),
        ),
      );
      final sync = TrackingSync(
        db: db,
        syncFn: ({
          required eventId,
          required locusEvents,
          required geolocatorPings,
        }) async {
          throw const SocketException('boom');
        },
      );
      await sync.syncBatch('e1');
      expect((await db.unsyncedLocusEvents('e1')), hasLength(1));
      await db.close('e1');
    });
  });
}

class _GrantingPermissionFlow extends PermissionFlow {
  @override
  Future<PermissionResult> requestForActiveQuest(Event event) async =>
      const PermissionResult(outcome: PermissionOutcome.granted);
}

class _DenyingPermissionFlow extends PermissionFlow {
  @override
  Future<PermissionResult> requestForActiveQuest(Event event) async =>
      const PermissionResult(
        outcome: PermissionOutcome.permanentlyDenied,
        shouldOpenSettings: true,
      );
}

class _FakeLocusTracker extends LocusTracker {
  int startCount = 0;
  int stopCount = 0;
  String? lastEventId;
  List<LatLng>? lastPolygon;

  @override
  Future<void> start({
    required String eventId,
    required List<LatLng> polygon,
    required void Function(LocusEvent) onEvent,
    String Function() idGenerator = _staticId,
  }) async {
    startCount++;
    lastEventId = eventId;
    lastPolygon = polygon;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  static String _staticId() => 'fake-locus';
}

class _FakeGeolocatorTracker extends GeolocatorTracker {
  int startCount = 0;
  int stopCount = 0;
  String? lastEventId;
  List<LatLng>? lastPolygon;

  @override
  Future<void> start({
    required String eventId,
    required List<LatLng> polygon,
    required void Function(GeolocatorPing) onPing,
    Duration interval = GeolocatorTracker.defaultInterval,
    String Function() idGenerator = _staticId,
  }) async {
    startCount++;
    lastEventId = eventId;
    lastPolygon = polygon;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  static String _staticId() => 'fake-ping';
}

class _FakeEventsRepository implements EventsRepository {
  _FakeEventsRepository(this._events);
  final Map<String, Event> _events;

  @override
  Future<Event?> getEventById(String id) async => _events[id];

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Fake stub: ${invocation.memberName}');
}
