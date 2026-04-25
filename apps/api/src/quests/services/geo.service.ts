import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class GeoService {
  private readonly logger = new Logger(GeoService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Recompute isInsidePolygon for every locus event + geolocator ping
   * belonging to (userId, eventId), based on the event's
   * geofence_polygon. Returns the count of points marked inside.
   *
   * Uses ST_Contains so the check happens entirely in Postgres — fast
   * for batches in the thousands.
   */
  async applyGeofenceTo(userId: string, eventId: string): Promise<{ insideLocus: number; insideGeolocator: number }> {
    const [locus, geolocator] = await this.prisma.$transaction([
      this.prisma.$executeRaw`
        UPDATE "locus_events" le
        SET "isInsidePolygon" = ST_Contains(
          (SELECT geofence_polygon FROM "events" WHERE id = ${eventId}::uuid)::geometry,
          ST_SetSRID(ST_MakePoint(le.longitude, le.latitude), 4326)::geometry
        )
        WHERE le."userId" = ${userId}::uuid AND le."eventId" = ${eventId}::uuid
      `,
      this.prisma.$executeRaw`
        UPDATE "geolocator_pings" gp
        SET "isInsidePolygon" = ST_Contains(
          (SELECT geofence_polygon FROM "events" WHERE id = ${eventId}::uuid)::geometry,
          ST_SetSRID(ST_MakePoint(gp.longitude, gp.latitude), 4326)::geometry
        )
        WHERE gp."userId" = ${userId}::uuid AND gp."eventId" = ${eventId}::uuid
      `,
    ]);

    const [{ count: insideLocus }] = await this.prisma.$queryRaw<{ count: number }[]>`
      SELECT COUNT(*)::int as count FROM "locus_events"
      WHERE "userId" = ${userId}::uuid AND "eventId" = ${eventId}::uuid AND "isInsidePolygon" = true
    `;
    const [{ count: insideGeolocator }] = await this.prisma.$queryRaw<{ count: number }[]>`
      SELECT COUNT(*)::int as count FROM "geolocator_pings"
      WHERE "userId" = ${userId}::uuid AND "eventId" = ${eventId}::uuid AND "isInsidePolygon" = true
    `;
    this.logger.debug(
      `geofence applied user=${userId} event=${eventId} inside locus=${insideLocus} geolocator=${insideGeolocator} (rows touched: ${locus}+${geolocator})`,
    );
    return { insideLocus, insideGeolocator };
  }

  /**
   * Test a single (lat, lng) against an event's polygon. Used for
   * photo upload's isInsideGeofence flag.
   */
  async pointIsInside(eventId: string, latitude: number, longitude: number): Promise<boolean> {
    const result = await this.prisma.$queryRaw<{ inside: boolean }[]>`
      SELECT ST_Contains(
        (SELECT geofence_polygon FROM "events" WHERE id = ${eventId}::uuid)::geometry,
        ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geometry
      ) as inside
    `;
    return Boolean(result[0]?.inside);
  }

  /**
   * Set the polygon + center for an event from a list of (lat, lng)
   * vertices. The ring closes itself if the last vertex isn't equal to
   * the first.
   */
  async setEventGeofence(eventId: string, vertices: Array<{ lat: number; lng: number }>) {
    if (vertices.length < 3) throw new Error('Polygon needs at least 3 vertices');
    const closed = vertices[0].lat === vertices[vertices.length - 1].lat && vertices[0].lng === vertices[vertices.length - 1].lng
      ? vertices
      : [...vertices, vertices[0]];
    const wkt = `POLYGON((${closed.map((v) => `${v.lng} ${v.lat}`).join(', ')}))`;

    const sumLat = vertices.reduce((s, v) => s + v.lat, 0) / vertices.length;
    const sumLng = vertices.reduce((s, v) => s + v.lng, 0) / vertices.length;
    const centerWkt = `POINT(${sumLng} ${sumLat})`;

    await this.prisma.$executeRaw`
      UPDATE "events"
      SET geofence_polygon = ST_GeogFromText(${wkt}),
          geofence_center  = ST_GeogFromText(${centerWkt})
      WHERE id = ${eventId}::uuid
    `;
  }
}
