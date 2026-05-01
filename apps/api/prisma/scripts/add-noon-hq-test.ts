/**
 * One-shot helper to drop a 12 PM test event at smwhr HQ. Idempotent
 * by slug (`smwhr-hq-noon-test`) — re-running wipes prior tracker /
 * task / photo / badge / checkin state so the founder gets a clean
 * smoke session each invocation.
 *
 * Window: 12:00 – 13:00 CDMX (UTC-6) on whatever "today" the script
 * runs in. The fixed CDMX offset keeps behaviour predictable when the
 * server clock is in UTC (Railway, Docker) vs. local (founder's mac).
 *
 * Usage:
 *   cd apps/api && npx ts-node prisma/scripts/add-noon-hq-test.ts
 */
import { PrismaClient } from '@prisma/client';
import {
  upsertFutureEvent,
  type FutureEventInput,
  type VenueLoc,
} from '../lib/event-fixtures';

const prisma = new PrismaClient();

// Same coordinates as reset-hq-test.ts — keep in sync if the HQ
// physical location ever moves.
const HQ_VENUE: VenueLoc = {
  lat: 20 + 4 / 60 + 14.1 / 3600,
  lng: -(98 + 22 / 60 + 35.1 / 3600),
  delta: 0.00018, // ~20m half-side
};

// Build "today 12:00 / 13:00 CDMX" without depending on the server's
// local timezone. CDMX is UTC-6 (no daylight saving since 2022).
function noonCdmxTodayUtc(): { startsAt: Date; endsAt: Date } {
  const now = new Date();
  // Use UTC accessors so we don't drift if the server is in a
  // non-CDMX timezone. CDMX noon = UTC 18:00.
  const y = now.getUTCFullYear();
  const m = now.getUTCMonth();
  const d = now.getUTCDate();
  const startsAt = new Date(Date.UTC(y, m, d, 18, 0, 0));
  const endsAt = new Date(Date.UTC(y, m, d, 19, 0, 0));
  return { startsAt, endsAt };
}

const { startsAt, endsAt } = noonCdmxTodayUtc();

const event: FutureEventInput = {
  slug: 'smwhr-hq-noon-test',
  title: 'smwhr hq · noon smoke',
  venueName: 'smwhr HQ',
  city: 'Tulancingo',
  country: 'MX',
  category: 'culture',
  startsAt,
  endsAt,
  dwellMin: 5,
  description:
    'Evento de prueba: 1 hora a mediodía CDMX para validar el flujo de verificación nuevo (target 5 spot-checks, 40% inside).',
  heroColor: '#9D2DFF',
  isFeatured: false,
  intentCount: 0,
  venue: HQ_VENUE,
};

async function main() {
  const existing = await prisma.event.findUnique({ where: { slug: event.slug } });
  if (existing) {
    await prisma.$transaction([
      prisma.verificationTask.deleteMany({ where: { eventId: existing.id } }),
      prisma.geolocatorPing.deleteMany({ where: { eventId: existing.id } }),
      prisma.locusEvent.deleteMany({ where: { eventId: existing.id } }),
      prisma.photo.deleteMany({ where: { eventId: existing.id } }),
      prisma.badge.deleteMany({ where: { eventId: existing.id } }),
      prisma.checkin.deleteMany({ where: { eventId: existing.id } }),
    ]);
    console.log(`  cleared prior state for ${event.slug}`);
  }

  const id = await upsertFutureEvent(prisma, event);
  console.log(`✓ ${event.slug} → ${id}`);
  console.log(
    `  starts: ${startsAt.toLocaleString('en-US', { timeZone: 'America/Mexico_City' })} CDMX`,
  );
  console.log(
    `  ends:   ${endsAt.toLocaleString('en-US', { timeZone: 'America/Mexico_City' })} CDMX`,
  );
  console.log(`  center: ${HQ_VENUE.lat.toFixed(7)}, ${HQ_VENUE.lng.toFixed(7)}`);
  console.log(`  radius: ~20m (square polygon, ~40m side)`);
  console.log(`  target spot-checks: 5 (1h / 12 min, clamped to min 4)`);
  console.log(`  required inside: 2 (40% of 5, ceil)`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
