import 'package:flutter_test/flutter_test.dart';
import 'package:smwhr/data/models/lat_lng.dart';
import 'package:smwhr/features/quest/services/geolocator_tracker.dart';

void main() {
  group('isInsidePolygon (BTS GNP Seguros polygon)', () {
    // Mirrors apps/api/prisma/seed.ts buildPolygonWkt for VENUES.gnpSeguros.
    // Square ring around the venue centroid, ±0.0015° in each axis. Last
    // vertex repeats the first (PostGIS WKT closure); ray-cast handles it
    // by skipping the degenerate edge.
    const center = LatLng(19.4032, -99.1755);
    const d = 0.0015;
    final polygon = <LatLng>[
      LatLng(center.latitude - d, center.longitude - d),
      LatLng(center.latitude - d, center.longitude + d),
      LatLng(center.latitude + d, center.longitude + d),
      LatLng(center.latitude + d, center.longitude - d),
      LatLng(center.latitude - d, center.longitude - d),
    ];

    test('center is inside', () {
      expect(isInsidePolygon(center, polygon), isTrue);
    });

    test('a point just inside the bounds is inside', () {
      final justInside = LatLng(
        center.latitude + d * 0.5,
        center.longitude - d * 0.8,
      );
      expect(isInsidePolygon(justInside, polygon), isTrue);
    });

    test('a point ~0.005° away in any direction is outside', () {
      final far = [
        LatLng(center.latitude + 0.005, center.longitude),
        LatLng(center.latitude - 0.005, center.longitude),
        LatLng(center.latitude, center.longitude + 0.005),
        LatLng(center.latitude, center.longitude - 0.005),
        LatLng(center.latitude + 0.005, center.longitude + 0.005),
      ];
      for (final p in far) {
        expect(isInsidePolygon(p, polygon), isFalse, reason: '$p');
      }
    });

    test('a point right outside one edge is outside', () {
      final justOutside = LatLng(
        center.latitude,
        center.longitude + d * 1.001, // a sliver past the +x edge
      );
      expect(isInsidePolygon(justOutside, polygon), isFalse);
    });
  });

  group('isInsidePolygon (Tulancingo HQ polygon — prueba-tulancingo-hq)', () {
    // VENUES.franzBehr103: { lat: 20.0705988, lng: -98.3763053, delta: 0.001 }
    const center = LatLng(20.0705988, -98.3763053);
    const d = 0.001;
    final polygon = <LatLng>[
      LatLng(center.latitude - d, center.longitude - d),
      LatLng(center.latitude - d, center.longitude + d),
      LatLng(center.latitude + d, center.longitude + d),
      LatLng(center.latitude + d, center.longitude - d),
      LatLng(center.latitude - d, center.longitude - d),
    ];

    test('center is inside', () {
      expect(isInsidePolygon(center, polygon), isTrue);
    });

    test('200m offset is outside (~0.002°)', () {
      expect(
        isInsidePolygon(
          LatLng(center.latitude + 0.002, center.longitude),
          polygon,
        ),
        isFalse,
      );
    });
  });

  group('isInsidePolygon (degenerate inputs)', () {
    test('empty polygon → false', () {
      expect(isInsidePolygon(const LatLng(0, 0), const []), isFalse);
    });

    test('polygon with < 3 vertices → false', () {
      final pts = [const LatLng(0, 0), const LatLng(1, 1)];
      expect(isInsidePolygon(const LatLng(0.5, 0.5), pts), isFalse);
    });

    test('triangle: centroid inside, far point outside', () {
      final triangle = [
        const LatLng(0, 0),
        const LatLng(0, 2),
        const LatLng(2, 1),
      ];
      // Centroid = (0.667, 1).
      expect(
        isInsidePolygon(const LatLng(0.6, 1), triangle),
        isTrue,
      );
      expect(
        isInsidePolygon(const LatLng(5, 5), triangle),
        isFalse,
      );
    });
  });
}
