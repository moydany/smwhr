import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:smwhr/data/local/adapters/geolocator_ping_adapter.dart';
import 'package:smwhr/data/local/adapters/locus_event_adapter.dart';
import 'package:smwhr/data/local/tracking_db.dart';
import 'package:smwhr/data/models/quest.dart';
import 'package:smwhr/features/quest/services/boot_drain.dart';
import 'package:smwhr/features/quest/services/tracking_sync.dart';

void main() {
  late Directory tmp;

  setUpAll(() {
    Hive.registerAdapter(LocusEventAdapter());
    Hive.registerAdapter(GeolocatorPingAdapter());
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('boot_drain_test_');
    Hive.init(tmp.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  LocusEvent locus(String id, String eventId) => LocusEvent(
        id: id,
        eventId: eventId,
        type: LocusEventType.locationUpdate,
        timestamp: DateTime.utc(2026, 5, 7, 20, 30),
        latitude: 19.40,
        longitude: -99.17,
      );

  group('TrackingDb event-id index', () {
    test('open() records eventId; recordedEventIds() returns it across '
        'a close/reopen cycle', () async {
      var db = TrackingDb();
      await db.open('event-1');
      await db.open('event-2');
      await db.close('event-1');
      await db.close('event-2');

      // New db instance — survives.
      db = TrackingDb();
      final ids = await db.recordedEventIds();
      expect(ids, containsAll(['event-1', 'event-2']));
    });

    test('forgetEventId removes the id', () async {
      final db = TrackingDb();
      await db.open('event-1');
      await db.close('event-1');
      await db.forgetEventId('event-1');
      expect(await db.recordedEventIds(), isNot(contains('event-1')));
    });
  });

  group('BootDrainService.run', () {
    test('drains every recorded event id, then drops them from the index '
        'when fully synced', () async {
      // Seed: two events, each with one unsynced locus event.
      var db = TrackingDb();
      await db.open('e1');
      await db.appendLocusEvent('e1', locus('l1', 'e1'));
      await db.close('e1');
      await db.open('e2');
      await db.appendLocusEvent('e2', locus('l2', 'e2'));
      await db.close('e2');

      // Fresh objects — what main.dart would see at next cold start.
      db = TrackingDb();
      final calls = <String>[];
      final sync = TrackingSync(
        db: db,
        syncFn: ({
          required eventId,
          required locusEvents,
          required geolocatorPings,
        }) async {
          calls.add(eventId);
        },
      );
      final boot = BootDrainService(db: db, sync: sync);

      await boot.run();

      expect(calls, containsAll(['e1', 'e2']));
      expect(await db.recordedEventIds(), isEmpty,
          reason: 'fully drained ids should be dropped from the index');
    });

    test('failed POST keeps rows unsynced AND keeps id in the index for '
        'the next boot', () async {
      var db = TrackingDb();
      await db.open('e1');
      await db.appendLocusEvent('e1', locus('l1', 'e1'));
      await db.close('e1');

      db = TrackingDb();
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
      final boot = BootDrainService(db: db, sync: sync);

      await boot.run();

      // Index should still contain 'e1' so the next boot retries.
      expect(await db.recordedEventIds(), contains('e1'));
      // Row stays unsynced.
      await db.open('e1');
      expect(await db.unsyncedLocusEvents('e1'), hasLength(1));
      await db.close('e1');
    });

    test('events with no rows still get cleaned from the index', () async {
      // An empty quest (started, never produced rows) should be GC'd.
      var db = TrackingDb();
      await db.open('e-empty');
      await db.close('e-empty');

      db = TrackingDb();
      final sync = TrackingSync(
        db: db,
        syncFn: ({
          required eventId,
          required locusEvents,
          required geolocatorPings,
        }) async {
          fail('syncFn should not fire when there is nothing to send');
        },
      );
      final boot = BootDrainService(db: db, sync: sync);

      await boot.run();

      expect(await db.recordedEventIds(), isEmpty);
    });
  });
}
