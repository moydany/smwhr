/**
 * Shared building blocks for event fixtures.
 *
 * Both `prisma/seed.ts` (full demo seed) and `prisma/scripts/*.ts`
 * (operational one-offs like `reset-future-events`) build events the
 * same way: upsert by slug, then write the geofence polygon + center
 * via PostGIS in a follow-up `UPDATE`. Centralising the pattern here
 * keeps the two paths from drifting and lets new scripts compose from
 * the same primitives.
 */
import type { PrismaClient } from '@prisma/client';

export interface VenueLoc {
  /** Decimal latitude (WGS84). */
  lat: number;
  /** Decimal longitude (WGS84). */
  lng: number;
  /**
   * Half-side of the square polygon, in degrees. Defaults to 0.0015
   * (~165m at the equator) which is a reasonable concert-venue
   * footprint. Use larger values for festivals / outdoor areas.
   */
  delta?: number;
}

/**
 * Named venues used across the seed and operational scripts. Add new
 * entries here rather than inlining coordinates at the call site so a
 * change to a venue's footprint propagates to every event there.
 */
export const VENUES: Record<string, VenueLoc> = {
  gnpSeguros: { lat: 19.4032, lng: -99.1755 },
  estadioAzteca: { lat: 19.3029, lng: -99.1505 },
  foroSol: { lat: 19.4044, lng: -99.0931 },
  estadioBBVA: { lat: 25.6692, lng: -100.2447 },
  laBombonera: { lat: -34.6356, lng: -58.3651 },
  autodromo: { lat: 19.4042, lng: -99.0907, delta: 0.005 },
  parqueBicentenario: { lat: 19.5043, lng: -99.1864, delta: 0.005 },
  trasloma: { lat: 20.6750, lng: -103.4080 },
  iztaccihuatl: { lat: 19.1789, lng: -98.6418, delta: 0.02 },
  tepozteco: { lat: 18.9885, lng: -99.1014 },
  guanajuatoCentro: { lat: 21.0190, lng: -101.2574, delta: 0.01 },
  auditorioTelmex: { lat: 20.7237, lng: -103.4007 },
  // Test venues for the active-quest sprint (Tulancingo HQ + Estadio Harp Helú).
  franzBehr103: { lat: 20.0705988, lng: -98.3763053, delta: 0.001 },
  estadioHarpHelu: { lat: 19.4033566, lng: -99.0843454, delta: 0.0025 },
  // delta 0.003 (~330 m) — generous radius to cover GPS uncertainty at unfamiliar venues.
  maravillaStudios: { lat: 19.4556486, lng: -99.1589733, delta: 0.003 },
  teatroPueblaFeria: { lat: 19.0572934, lng: -98.1803358, delta: 0.003 },
};

/**
 * Hardcoded UUIDs for the per-category default badge templates. Stable
 * across environments so seeded events can reference them without a
 * lookup roundtrip.
 */
export const TEMPLATE_IDS = {
  music: '00000000-0000-0000-0000-000000000001',
  sports: '00000000-0000-0000-0000-000000000002',
  festivals: '00000000-0000-0000-0000-000000000003',
  outdoor: '00000000-0000-0000-0000-000000000004',
  culture: '00000000-0000-0000-0000-000000000005',
} as const;

export type EventCategory = keyof typeof TEMPLATE_IDS;

/** Builds a closed-ring WKT POLYGON around a venue's center. */
export function buildPolygonWkt(loc: VenueLoc): string {
  const d = loc.delta ?? 0.0015;
  const ring = [
    [loc.lng - d, loc.lat - d],
    [loc.lng + d, loc.lat - d],
    [loc.lng + d, loc.lat + d],
    [loc.lng - d, loc.lat + d],
    [loc.lng - d, loc.lat - d],
  ];
  return `POLYGON((${ring.map(([x, y]) => `${x} ${y}`).join(', ')}))`;
}

/**
 * Writes the PostGIS geography columns for an event. The Prisma schema
 * marks them `Unsupported`, so we round-trip through a parameterised
 * raw query — `$executeRaw` is safe against injection because the
 * template tag binds each value as a parameter.
 */
export async function setEventGeofence(
  prisma: PrismaClient,
  eventId: string,
  loc: VenueLoc,
): Promise<void> {
  const polygonWkt = buildPolygonWkt(loc);
  const centerWkt = `POINT(${loc.lng} ${loc.lat})`;
  await prisma.$executeRaw`
    UPDATE "events"
    SET geofence_polygon = ST_GeogFromText(${polygonWkt}),
        geofence_center  = ST_GeogFromText(${centerWkt})
    WHERE id = ${eventId}::uuid
  `;
}

export interface FutureEventInput {
  slug: string;
  title: string;
  artist?: string;
  venueName: string;
  venueAddress?: string;
  city: string;
  country?: string;
  category: EventCategory;
  startsAt: Date;
  endsAt: Date;
  dwellMin?: number;
  description?: string;
  heroColor?: string;
  isFeatured?: boolean;
  intentCount?: number;
  totalCapacity?: number;
  venue: VenueLoc;
}

/**
 * Idempotent upsert of a future event + its geofence. Returns the
 * event's id so callers can chain follow-up writes (intents, etc.).
 *
 * The PostGIS columns are written separately because Prisma can't
 * model `geography` natively — calling this is the only sanctioned way
 * to keep them in sync with `venue`.
 */
export async function upsertFutureEvent(
  prisma: PrismaClient,
  e: FutureEventInput,
): Promise<string> {
  const event = await prisma.event.upsert({
    where: { slug: e.slug },
    update: {
      title: e.title,
      artist: e.artist ?? null,
      venueName: e.venueName,
      venueAddress: e.venueAddress ?? null,
      city: e.city,
      countryCode: e.country ?? 'MX',
      category: e.category,
      startsAt: e.startsAt,
      endsAt: e.endsAt,
      dwellMinimumMin: e.dwellMin ?? 60,
      description: e.description ?? null,
      heroColor: e.heroColor ?? null,
      intentCount: e.intentCount ?? 0,
      isFeatured: e.isFeatured ?? false,
      totalCapacity: e.totalCapacity ?? null,
      badgeTemplateId: TEMPLATE_IDS[e.category],
      status: 'scheduled',
    },
    create: {
      slug: e.slug,
      title: e.title,
      artist: e.artist ?? null,
      venueName: e.venueName,
      venueAddress: e.venueAddress ?? null,
      city: e.city,
      countryCode: e.country ?? 'MX',
      category: e.category,
      startsAt: e.startsAt,
      endsAt: e.endsAt,
      dwellMinimumMin: e.dwellMin ?? 60,
      description: e.description ?? null,
      heroColor: e.heroColor ?? null,
      intentCount: e.intentCount ?? 0,
      isFeatured: e.isFeatured ?? false,
      totalCapacity: e.totalCapacity ?? null,
      badgeTemplateId: TEMPLATE_IDS[e.category],
      status: 'scheduled',
    },
  });
  await setEventGeofence(prisma, event.id, e.venue);
  return event.id;
}
