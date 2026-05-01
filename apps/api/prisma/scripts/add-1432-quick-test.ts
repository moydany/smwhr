/**
 * 14:32 PM CDMX, 8-minute window at smwhr HQ.
 *   target spot-checks = clamp(round(8/1.5), 4, 20) = 5
 *   required inside    = ceil(5 × 0.4) = 2
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

function quickWindowToday(): { startsAt: Date; endsAt: Date } {
  const now = new Date();
  const y = now.getUTCFullYear();
  const m = now.getUTCMonth();
  const d = now.getUTCDate();
  // 14:32 – 14:40 CDMX → 20:32 – 20:40 UTC
  const startsAt = new Date(Date.UTC(y, m, d, 20, 32, 0));
  const endsAt = new Date(Date.UTC(y, m, d, 20, 40, 0));
  return { startsAt, endsAt };
}

const { startsAt, endsAt } = quickWindowToday();

const event: FutureEventInput = {
  slug: 'smwhr-hq-1432-quick',
  title: 'smwhr hq · 14:32 quick',
  venueName: 'smwhr HQ',
  city: 'Tulancingo',
  country: 'MX',
  category: 'culture',
  startsAt,
  endsAt,
  dwellMin: 2,
  description: 'Quick smoke: 8 min, 5 spot-checks programados, 2 dentro del polygon validan tu asistencia.',
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
  console.log(`  starts: ${startsAt.toLocaleString('en-US', { timeZone: 'America/Mexico_City' })} CDMX`);
  console.log(`  ends:   ${endsAt.toLocaleString('en-US', { timeZone: 'America/Mexico_City' })} CDMX`);
  console.log(`  scheduled spot-checks: 5`);
  console.log(`  required inside: 2`);
}

main().catch((e) => { console.error(e); process.exit(1); }).finally(() => prisma.$disconnect());
