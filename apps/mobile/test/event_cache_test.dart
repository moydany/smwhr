import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smwhr/data/local/event_cache.dart';
import 'package:smwhr/data/models/event.dart';
import 'package:smwhr/data/models/event_category.dart';
import 'package:smwhr/data/models/lat_lng.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('event_cache_test_');
    Hive.init(tmp.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  Event makeEvent({
    String id = 'evt-1',
    String slug = 'bts-mexico-2026-n1',
    List<LatLng>? polygon,
  }) {
    return Event(
      id: id,
      slug: slug,
      title: 'BTS World Tour · Noche 1',
      artistName: 'BTS',
      venueName: 'Estadio GNP Seguros',
      city: 'Ciudad de México',
      countryCode: 'MX',
      startsAt: DateTime.utc(2026, 5, 7, 20, 30),
      endsAt: DateTime.utc(2026, 5, 7, 23, 30),
      heroImageUrl: 'https://cdn.example/hero.jpg',
      description: 'La primera de tres noches.',
      category: EventCategory.music,
      geofencePolygon: polygon ??
          const [
            LatLng(19.4017, -99.1770),
            LatLng(19.4017, -99.1740),
            LatLng(19.4047, -99.1740),
            LatLng(19.4047, -99.1770),
            LatLng(19.4017, -99.1770),
          ],
      dwellMinimumMin: 45,
      ticketmasterUrl: 'https://ticketmaster.com.mx/bts',
      intentCount: 8420,
      verifiedAttendeeCount: 0,
      isFeatured: true,
      badgeFrameUrl: 'https://cdn.example/frame_music.svg',
    );
  }

  group('EventCache', () {
    test('round-trips an Event across save → get with field fidelity',
        () async {
      final cache = EventCache();
      final original = makeEvent();
      await cache.save(original);

      final back = await cache.get(original.id);

      expect(back, isNotNull);
      expect(back!.id, original.id);
      expect(back.slug, original.slug);
      expect(back.title, original.title);
      expect(back.artistName, original.artistName);
      expect(back.venueName, original.venueName);
      expect(back.city, original.city);
      expect(back.countryCode, original.countryCode);
      expect(back.startsAt.toUtc(), original.startsAt);
      expect(back.endsAt!.toUtc(), original.endsAt);
      expect(back.heroImageUrl, original.heroImageUrl);
      expect(back.description, original.description);
      expect(back.category, original.category);
      expect(back.geofencePolygon, original.geofencePolygon);
      expect(back.dwellMinimumMin, original.dwellMinimumMin);
      expect(back.ticketmasterUrl, original.ticketmasterUrl);
      expect(back.intentCount, original.intentCount);
      expect(back.verifiedAttendeeCount, original.verifiedAttendeeCount);
      expect(back.isFeatured, original.isFeatured);
      expect(back.badgeFrameUrl, original.badgeFrameUrl);

      await cache.close();
    });

    test('survives a Hive close/reopen (cold restart)', () async {
      var cache = EventCache();
      await cache.save(makeEvent(id: 'evt-cold'));
      await cache.close();
      await Hive.close();
      Hive.init(tmp.path);

      cache = EventCache();
      final back = await cache.get('evt-cold');
      expect(back, isNotNull);
      expect(back!.geofencePolygon, hasLength(5));
      await cache.close();
    });

    test('clear removes the entry', () async {
      final cache = EventCache();
      await cache.save(makeEvent(id: 'gone'));
      expect(await cache.get('gone'), isNotNull);
      await cache.clear('gone');
      expect(await cache.get('gone'), isNull);
      await cache.close();
    });

    test('returns null for missing ids without throwing', () async {
      final cache = EventCache();
      expect(await cache.get('never-saved'), isNull);
      await cache.close();
    });
  });
}
