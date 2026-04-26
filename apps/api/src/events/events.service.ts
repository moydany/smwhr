import { HttpStatus, Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import { ApiException } from '../common/exceptions/api.exception';
import { PrismaService } from '../prisma/prisma.service';
import { ListEventsDto } from './dto/list-events.dto';

@Injectable()
export class EventsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(q: ListEventsDto) {
    const limit = q.limit ?? 50;
    const offset = q.offset ?? 0;

    const where: Prisma.EventWhereInput = {};
    if (q.category) where.category = q.category;
    if (q.city) where.city = { equals: q.city, mode: 'insensitive' };
    if (q.featured !== undefined) where.isFeatured = q.featured;
    if (q.from) where.startsAt = { gte: new Date(q.from) };
    if (q.to) where.endsAt = { lte: new Date(q.to) };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.event.findMany({
        where,
        include: { badgeTemplate: true },
        orderBy: [{ isFeatured: 'desc' }, { startsAt: 'asc' }],
        take: limit,
        skip: offset,
      }),
      this.prisma.event.count({ where }),
    ]);

    return { items, total, limit, offset };
  }

  async bySlug(slug: string) {
    const event = await this.prisma.event.findUnique({
      where: { slug },
      include: { badgeTemplate: true },
    });
    if (!event) {
      throw new ApiException(HttpStatus.NOT_FOUND, 'EVENT_NOT_FOUND', `Event ${slug} not found`);
    }
    const geofencePolygon = await this.fetchPolygonOuterRing(event.id);
    return { ...event, geofencePolygon };
  }

  async byId(id: string) {
    const event = await this.prisma.event.findUnique({ where: { id } });
    if (!event) {
      throw new ApiException(HttpStatus.NOT_FOUND, 'EVENT_NOT_FOUND', `Event ${id} not found`);
    }
    const geofencePolygon = await this.fetchPolygonOuterRing(event.id);
    return { ...event, geofencePolygon };
  }

  // Returns the outer ring of the event's geofence polygon as an array of
  // [lng, lat] pairs (GeoJSON coordinate order). Empty array when the
  // column is null. Mobile maps this to List<LatLng> for Locus geofence
  // registration + Geolocator ray-casting.
  private async fetchPolygonOuterRing(eventId: string): Promise<number[][]> {
    const rows = await this.prisma.$queryRaw<
      Array<{ coordinates: number[][] | null }>
    >`
      SELECT (ST_AsGeoJSON(geofence_polygon)::json->'coordinates'->0) as coordinates
      FROM events
      WHERE id = ${eventId}::uuid
    `;
    return rows[0]?.coordinates ?? [];
  }
}
