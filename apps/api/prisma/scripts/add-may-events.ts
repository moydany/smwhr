/**
 * Operational one-off: upsert Amelie Lens (CDMX, 1 may) and Calvin Harris
 * (Feria de Puebla, 3 may) without touching any existing events.
 *
 * Run via:
 *   pnpm --filter api tsx prisma/scripts/add-may-events.ts
 *   ts-node prisma/scripts/add-may-events.ts
 */
import { PrismaClient } from '@prisma/client';
import {
  upsertFutureEvent,
  type FutureEventInput,
  type VenueLoc,
} from '../lib/event-fixtures';

const prisma = new PrismaClient();

// Coordinates supplied by founder.
// delta 0.003 (~330 m) — generous to cover GPS uncertainty at unfamiliar venues.
const MARAVILLA_STUDIOS: VenueLoc = { lat: 19.4556486, lng: -99.1589733, delta: 0.003 };
const TEATRO_PUEBLO_PUEBLA: VenueLoc = { lat: 19.0572934, lng: -98.1803358, delta: 0.003 };

const EVENTS: FutureEventInput[] = [
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
  console.log('➕ add-may-events — start');
  for (const e of EVENTS) {
    const id = await upsertFutureEvent(prisma, e);
    console.log(`✓ upserted ${e.slug} (${id})`);
  }
  const total = await prisma.event.count({ where: { status: 'scheduled' } });
  console.log(`✓ done — ${total} scheduled event(s) in catalog`);
}

main()
  .catch((e) => {
    console.error('add-may-events failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
