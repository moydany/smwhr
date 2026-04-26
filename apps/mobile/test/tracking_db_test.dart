import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smwhr/data/local/adapters/geolocator_ping_adapter.dart';
import 'package:smwhr/data/local/adapters/locus_event_adapter.dart';
import 'package:smwhr/data/local/tracking_db.dart';
import 'package:smwhr/data/models/quest.dart';

void main() {
  late Directory tmp;

  setUpAll(() {
    Hive.registerAdapter(LocusEventAdapter());
    Hive.registerAdapter(GeolocatorPingAdapter());
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tracking_db_test_');
    Hive.init(tmp.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  group('TrackingDb', () {
    const eventId = 'event-1';

    LocusEvent locus(int i) => LocusEvent(
          id: 'locus-$i',
          eventId: eventId,
          type: LocusEventType.values[i % LocusEventType.values.length],
          timestamp: DateTime.utc(2026, 5, 7, 20, 30 + i),
          latitude: 19.4 + i * 0.0001,
          longitude: -99.1 + i * 0.0001,
          accuracy: 5.0 + i,
          raw: {'kind': 'test', 'i': i},
        );

    GeolocatorPing ping(int i) => GeolocatorPing(
          id: 'ping-$i',
          eventId: eventId,
          timestamp: DateTime.utc(2026, 5, 7, 21, i),
          latitude: 19.4 + i * 0.0002,
          longitude: -99.1 + i * 0.0002,
          accuracy: 8.0 + i,
          isInsidePolygon: i.isEven,
        );

    test('round-trips locus events + pings across reopen', () async {
      var db = TrackingDb();
      await db.open(eventId);

      for (var i = 0; i < 5; i++) {
        await db.appendLocusEvent(eventId, locus(i));
        await db.appendGeolocatorPing(eventId, ping(i));
      }

      expect(await db.totalCount(eventId), 10);
      await db.close(eventId);

      // Reopen — survives a "cold restart".
      db = TrackingDb();
      await db.open(eventId);

      final locusBack = await db.unsyncedLocusEvents(eventId);
      final pingsBack = await db.unsyncedGeolocatorPings(eventId);

      expect(locusBack, hasLength(5));
      expect(pingsBack, hasLength(5));

      // Spot-check field fidelity on one of each.
      final l3 = locusBack.firstWhere((e) => e.id == 'locus-3');
      expect(l3.eventId, eventId);
      expect(l3.type, LocusEventType.values[3]);
      expect(l3.timestamp, DateTime.utc(2026, 5, 7, 20, 33));
      expect(l3.latitude, closeTo(19.4003, 1e-9));
      expect(l3.longitude, closeTo(-99.0997, 1e-9));
      expect(l3.accuracy, 8.0);
      expect(l3.raw, {'kind': 'test', 'i': 3});

      final p2 = pingsBack.firstWhere((p) => p.id == 'ping-2');
      expect(p2.eventId, eventId);
      expect(p2.latitude, closeTo(19.4004, 1e-9));
      expect(p2.longitude, closeTo(-99.0996, 1e-9));
      expect(p2.accuracy, 10.0);
      expect(p2.isInsidePolygon, isTrue);

      await db.close(eventId);
    });

    test('markSynced removes ids from the unsynced reads after reopen',
        () async {
      var db = TrackingDb();
      await db.open(eventId);
      for (var i = 0; i < 5; i++) {
        await db.appendLocusEvent(eventId, locus(i));
        await db.appendGeolocatorPing(eventId, ping(i));
      }

      // Mark the first 3 of each as synced.
      await db.markSynced(
        locusIds: ['locus-0', 'locus-1', 'locus-2'],
        pingIds: ['ping-0', 'ping-1', 'ping-2'],
      );

      // Verify in-memory.
      var unsyncedLocus = await db.unsyncedLocusEvents(eventId);
      var unsyncedPings = await db.unsyncedGeolocatorPings(eventId);
      expect(unsyncedLocus.map((e) => e.id).toSet(), {'locus-3', 'locus-4'});
      expect(unsyncedPings.map((p) => p.id).toSet(), {'ping-3', 'ping-4'});

      // Reopen — synced state must persist (it lives in the meta box).
      await db.close(eventId);
      db = TrackingDb();
      await db.open(eventId);

      unsyncedLocus = await db.unsyncedLocusEvents(eventId);
      unsyncedPings = await db.unsyncedGeolocatorPings(eventId);
      expect(unsyncedLocus.map((e) => e.id).toSet(), {'locus-3', 'locus-4'});
      expect(unsyncedPings.map((p) => p.id).toSet(), {'ping-3', 'ping-4'});

      // Total still 10 — markSynced doesn't delete rows.
      expect(await db.totalCount(eventId), 10);

      await db.close(eventId);
    });

    test('throws when reading an event that was never opened', () async {
      final db = TrackingDb();
      expect(
        () => db.unsyncedLocusEvents(eventId),
        throwsStateError,
      );
    });

    test('append round-trips an empty raw map without crashing', () async {
      final db = TrackingDb();
      await db.open(eventId);
      await db.appendLocusEvent(
        eventId,
        LocusEvent(
          id: 'minimal',
          eventId: eventId,
          type: LocusEventType.heartbeat,
          timestamp: DateTime.utc(2026, 5, 7, 20, 30),
        ),
      );

      await db.close(eventId);
      await db.open(eventId);
      final back = await db.unsyncedLocusEvents(eventId);
      expect(back, hasLength(1));
      expect(back.first.latitude, isNull);
      expect(back.first.longitude, isNull);
      expect(back.first.accuracy, isNull);
      expect(back.first.raw, isEmpty);
      await db.close(eventId);
    });
  });
}
