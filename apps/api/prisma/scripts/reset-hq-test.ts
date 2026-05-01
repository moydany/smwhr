/**
 * Operational helper for the smwhr HQ smoke test.
 *
 * Drops everything attached to `smwhr-hq-test` (verification tasks,
 * tracker rows, photos, badge, checkin) and re-creates the event with
 * a tight 20-meter-radius polygon centered on the HQ coordinates and
 * a 5-minute window starting NOW. Re-run any time the founder wants a
 * fresh smoke session.
 *
 * Usage:
 *   pnpm --filter api db:reset-hq
 */
import { PrismaClient } from '@prisma/client';
import {
  upsertFutureEvent,
  type FutureEventInput,
  type VenueLoc,
} from '../lib/event-fixtures';

const prisma = new PrismaClient();

// Coords: 20°04'14.1"N 98°22'35.1"W → 20.07058333, -98.37641667
// Delta 0.00018° ≈ 20m at lat 20°N (half-side of the polygon square).
const HQ_VENUE: VenueLoc = {
  lat: 20 + 4 / 60 + 14.1 / 3600,
  lng: -(98 + 22 / 60 + 35.1 / 3600),
  delta: 0.00018,
};

const startsAt = new Date();
const endsAt = new Date(startsAt.getTime() + 5 * 60 * 1000);

const event: FutureEventInput = {
  slug: 'smwhr-hq-test',
  title: 'smwhr hq',
  venueName: 'smwhr HQ',
  city: 'Tulancingo',
  country: 'MX',
  category: 'culture',
  startsAt,
  endsAt,
  dwellMin: 5,
  description:
    'Evento de prueba: 5 minutos para verificar que estuviste ahí.',
  heroColor: '#9D2DFF',
  isFeatured: true,
  intentCount: 0,
  venue: HQ_VENUE,
};

async function main() {
  // Wipe prior smoke-test state — cascade FKs handle the rest.
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
    `  starts: ${startsAt.toLocaleString('en-US', { timeZone: 'America/Mexico_City' })}`,
  );
  console.log(
    `  ends:   ${endsAt.toLocaleString('en-US', { timeZone: 'America/Mexico_City' })}`,
  );
  console.log(`  center: ${HQ_VENUE.lat.toFixed(7)}, ${HQ_VENUE.lng.toFixed(7)}`);
  console.log(`  radius: ~20m (square polygon, ~40m side)`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
