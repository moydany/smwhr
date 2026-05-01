/**
 * 13:10 PM CDMX, 15-minute window at smwhr HQ. Pairs with the
 * `targetSpotCheckCount` formula (1 attempt per 1.5 min, clamp 4-20)
 * which yields 10 attempts for a 15-min event; combined with the
 * 0.4 ratio gate that's 4 inside-polygon pings to verify.
 *
 * Idempotent by slug — re-running clears prior tracker / task /
 * photo / badge / checkin state. Same coordinates as
 * reset-hq-test.ts.
 *
 * Usage:
 *   cd apps/api && pnpm db:add-1310-quick
 */
import { PrismaClient } from '@prisma/client';
import {
  upsertFutureEvent,
  type FutureEventInput,
  type VenueLoc,
} from '../lib/event-fixtures';

const prisma = new PrismaClient();

const HQ_VENUE: VenueLoc = {
  lat: 20 + 4 / 60 + 14.1 / 3600,
  lng: -(98 + 22 / 60 + 35.1 / 3600),
  delta: 0.00018,
};

// 13:10 – 13:25 CDMX today (UTC-6 → 19:10–19:25 UTC).
function quickWindowToday(): { startsAt: Date; endsAt: Date } {
  const now = new Date();
  const y = now.getUTCFullYear();
  const m = now.getUTCMonth();
  const d = now.getUTCDate();
  const startsAt = new Date(Date.UTC(y, m, d, 19, 10, 0));
  const endsAt = new Date(Date.UTC(y, m, d, 19, 25, 0));
  return { startsAt, endsAt };
}

const { startsAt, endsAt } = quickWindowToday();

const event: FutureEventInput = {
  slug: 'smwhr-hq-1310-quick',
  title: 'smwhr hq · 13:10 quick',
  venueName: 'smwhr HQ',
  city: 'Tulancingo',
  country: 'MX',
  category: 'culture',
  startsAt,
  endsAt,
  dwellMin: 5,
  description:
    'Quick smoke: 15 min, 10 spot-checks programados, 4 dentro del polygon validan tu asistencia.',
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
  console.log(`  scheduled spot-checks: 10  (round(15/1.5))`);
  console.log(`  required inside: 4  (ceil(10 × 0.4))`);
  console.log(`  photo upload: REQUIRED (hard gate)`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
