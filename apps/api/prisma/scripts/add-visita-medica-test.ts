import { PrismaClient } from '@prisma/client';
import { upsertFutureEvent } from '../lib/event-fixtures';

const prisma = new PrismaClient();

async function main() {
  const id = await upsertFutureEvent(prisma, {
    slug: 'test-visita-medica-2026-05-01',
    title: 'Visita médica (test)',
    venueName: 'Médica Santa María',
    venueAddress: 'Tulancingo, Hgo.',
    city: 'Tulancingo',
    country: 'MX',
    category: 'culture',
    startsAt: new Date('2026-05-01T08:00:00-06:00'),
    endsAt:   new Date('2026-05-01T09:00:00-06:00'),
    dwellMin: 5,
    isFeatured: true,
    intentCount: 0,
    description: 'Evento de prueba — consulta en el fisio para validar el tracker en campo real.',
    heroColor: '#9D2DFF',
    venue: { lat: 20.0941344, lng: -98.3667859, delta: 0.0008 },
  });
  console.log(`✓ test-visita-medica-2026-05-01 → ${id}`);
  const total = await prisma.event.count({ where: { status: 'scheduled' } });
  console.log(`✓ ${total} scheduled events in catalog`);
}

main().catch(console.error).finally(() => prisma.$disconnect());
