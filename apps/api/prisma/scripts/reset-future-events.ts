/**
 * Operational one-off: drop every future (`status='scheduled'`) event
 * and replace the catalog with the real confirmed shows.
 *
 * Past events (`status='past'`) are left alone so the demo collection
 * (@moi's historic badges) survives. The Event cascade in the schema
 * removes intents, locus events, geolocator pings, checkins and
 * badges that were attached to the dropped events — re-running this
 * is destructive in that sense but otherwise idempotent.
 *
 * The smwhr HQ smoke-test event (slug: smwhr-hq-test) has its own
 * lifecycle — use reset-hq-test.ts for it.
 *
 * Run via:
 *   pnpm --filter api db:reset-future
 *   ts-node prisma/scripts/reset-future-events.ts
 */
import { PrismaClient } from '@prisma/client';
import {
  upsertFutureEvent,
  VENUES,
  type FutureEventInput,
  type VenueLoc,
} from '../lib/event-fixtures';

const prisma = new PrismaClient();

// 19°25'33.5"N 99°09'49.8"W — coordinates supplied by founder for the
// ZHU show. Decimal: 19.4259722, -99.1638333. Roma Norte / Cuauhtémoc
// edge of CDMX. Surprise street show — bumped delta to ~330m so the
// geofence covers a few blocks of foot traffic, not a single club door.
const ZHU_VENUE: VenueLoc = {
  lat: 19 + 25 / 60 + 33.5 / 3600,
  lng: -(99 + 9 / 60 + 49.8 / 3600),
  delta: 0.003,
};

// delta 0.003 (~330 m) — generous to cover GPS uncertainty at unfamiliar venues.
const MARAVILLA_STUDIOS: VenueLoc = { lat: 19.4556486, lng: -99.1589733, delta: 0.003 };
const TEATRO_PUEBLO_PUEBLA: VenueLoc = { lat: 19.0572934, lng: -98.1803358, delta: 0.003 };

const CATALOG: FutureEventInput[] = [
  // ── ZHU · CDMX ──────────────────────────────────────────────────────────
  {
    slug: 'zhu-cdmx-2026-05-01',
    title: 'On the Move',
    artist: 'ZHU',
    venueName: 'Juárez · CDMX',
    city: 'Ciudad de México',
    country: 'MX',
    category: 'music',
    // Wide window (16:00–22:00) on purpose: surprise street show, no
    // announced start. Pairs with the 5-min geolocator cadence so the
    // shadow tracker fires ~72 location checks across the window
    // instead of ~24 — far more chances to land an in-geofence ping.
    startsAt: new Date('2026-05-01T16:00:00-06:00'),
    endsAt: new Date('2026-05-01T22:00:00-06:00'),
    // 10-min dwell (vs 30) — for a passing street show, requiring half
    // an hour rules out anyone who only catches the back half of the set.
    dwellMin: 10,
    description:
      'Show gratis sorpresa en la calle. ZHU bajando a Juárez sin aviso. Sin tickets, sin filas — solo presencia.',
    heroColor: '#FF2D95',
    isFeatured: true,
    intentCount: 0,
    venue: ZHU_VENUE,
  },
  // ── Amelie Lens · CDMX ──────────────────────────────────────────────────
  {
    slug: 'amelie-lens-cdmx-2026-05-01',
    title: 'Amelie Lens · CDMX',
    artist: 'Amelie Lens',
    venueName: 'Maravilla Studios',
    venueAddress: 'C. Sabino 310, Atlampa, Cuauhtémoc, 06450, CDMX',
    city: 'Ciudad de México',
    country: 'MX',
    category: 'music',
    startsAt: new Date('2026-05-01T23:00:00-06:00'),
    endsAt: new Date('2026-05-02T05:00:00-06:00'),
    dwellMin: 60,
    isFeatured: true,
    intentCount: 0,
    description:
      'La reina del techno belga en uno de los foros más íntimos de CDMX. Una noche que no termina hasta el amanecer.',
    heroColor: '#FF2D95',
    venue: MARAVILLA_STUDIOS,
  },
  // ── Calvin Harris · Feria de Puebla ─────────────────────────────────────
  {
    slug: 'calvin-harris-feria-puebla-2026-05-03',
    title: 'Calvin Harris · Feria de Puebla 2026',
    artist: 'Calvin Harris',
    venueName: 'Teatro del Pueblo',
    venueAddress: 'Cívica 5 de Mayo, 72260 Heroica Puebla de Zaragoza, Pue.',
    city: 'Puebla',
    country: 'MX',
    category: 'music',
    startsAt: new Date('2026-05-03T22:00:00-06:00'),
    endsAt: new Date('2026-05-04T01:00:00-06:00'),
    dwellMin: 60,
    isFeatured: true,
    intentCount: 0,
    description:
      'El productor escocés más exitoso del mundo llega a la Feria de Puebla. Summer vibes en el Teatro del Pueblo.',
    heroColor: '#FF2D95',
    venue: TEATRO_PUEBLO_PUEBLA,
  },
];

async function main() {
  console.log('🧹 Reset future events — start');

  const dropped = await prisma.$transaction(async (tx) => {
    const before = await tx.event.findMany({
      where: { status: 'scheduled', slug: { not: 'smwhr-hq-test' } },
      select: { slug: true },
    });
    await tx.event.deleteMany({
      where: { status: 'scheduled', slug: { not: 'smwhr-hq-test' } },
    });
    return before.map((e) => e.slug);
  });

  if (dropped.length === 0) {
    console.log('  no scheduled events to drop');
  } else {
    console.log(`  dropped ${dropped.length} scheduled events:`);
    for (const slug of dropped) console.log(`    - ${slug}`);
  }

  for (const e of CATALOG) {
    const id = await upsertFutureEvent(prisma, e);
    console.log(`✓ upserted ${e.slug} (${id})`);
  }

  const total = await prisma.event.count({ where: { status: 'scheduled' } });
  console.log(`✓ done — ${total} scheduled event(s) in catalog`);
}

main()
  .catch((e) => {
    console.error('reset-future-events failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
