/**
 * 14:10 PM CDMX, 5-minute window at smwhr HQ.
 *   target spot-checks = clamp(round(5/1.5), 4, 20) = 4
 *   required inside    = ceil(4 × 0.4) = 2
 *
 * Idempotent by slug. Same coordinates as reset-hq-test.ts.
 *
 * Usage:
 *   cd apps/api && pnpm db:add-1410-quick
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

// 14:10 – 14:15 CDMX today (UTC-6 → 20:10–20:15 UTC).
function quickWindowToday(): { startsAt: Date; endsAt: Date } {
  const now = new Date();
  const y = now.getUTCFullYear();
  const m = now.getUTCMonth();
  const d = now.getUTCDate();
  const startsAt = new Date(Date.UTC(y, m, d, 20, 10, 0));
  const endsAt = new Date(Date.UTC(y, m, d, 20, 15, 0));
  return { startsAt, endsAt };
}

const { startsAt, endsAt } = quickWindowToday();

const event: FutureEventInput = {
  slug: 'smwhr-hq-1410-quick',
  title: 'smwhr hq · 14:10 quick',
  venueName: 'smwhr HQ',
  city: 'Tulancingo',
  country: 'MX',
  category: 'culture',
  startsAt,
  endsAt,
  dwellMin: 2,
  description:
    'Quick smoke: 5 min, 4 spot-checks programados, 2 dentro del polygon validan tu asistencia.',
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
  console.log(`  scheduled spot-checks: 4`);
  console.log(`  required inside: 2`);
  console.log(`  photo upload: REQUIRED (hard gate)`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
