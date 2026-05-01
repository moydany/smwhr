/**
 * smwhr seed — aligned with apps/mobile/lib/data/mock fixtures.
 *
 * Idempotent (uses upsert on unique fields). Re-running is safe.
 *
 * Fixture content:
 *   - 5 badge templates (one per category)
 *   - 9 demo users (founder + 8 LATAM)
 *   - 16 future events (3 BTS hero + music/sports/festivals/outdoor/culture)
 *   - 7 past events (one per historic badge in @moi's collection)
 *   - 4 intents (BTS x3 + Corona Capital), all on @moi
 *   - 7 historic badges in @moi's collection
 *
 * Note: demo users have no Supabase auth identity. When real users sign
 * up they get separate User rows; if they want a handle the seed already
 * uses ("moi", "sofia", etc.) they pick something else.
 */
import { PrismaClient } from '@prisma/client';
import {
  TEMPLATE_IDS,
  VENUES,
  setEventGeofence,
  upsertFutureEvent,
  type FutureEventInput,
  type VenueLoc,
} from './lib/event-fixtures';

const prisma = new PrismaClient();

const USER_IDS = {
  moi: '11111111-1111-1111-1111-111111110001',
  sofia: '11111111-1111-1111-1111-111111110002',
  carlos: '11111111-1111-1111-1111-111111110003',
  andrea: '11111111-1111-1111-1111-111111110004',
  beto: '11111111-1111-1111-1111-111111110005',
  lucia: '11111111-1111-1111-1111-111111110006',
  diego: '11111111-1111-1111-1111-111111110007',
  ximena: '11111111-1111-1111-1111-111111110008',
  paula: '11111111-1111-1111-1111-111111110009',
} as const;

async function seedBadgeTemplates() {
  const templates = [
    { id: TEMPLATE_IDS.music, name: 'Music — Default', category: 'music', accent: '#FF2D95' },
    { id: TEMPLATE_IDS.sports, name: 'Sports — Default', category: 'sports', accent: '#2DFF95' },
    { id: TEMPLATE_IDS.festivals, name: 'Festivals — Default', category: 'festivals', accent: '#FF9D2D' },
    { id: TEMPLATE_IDS.outdoor, name: 'Outdoor — Default', category: 'outdoor', accent: '#2DC8FF' },
    { id: TEMPLATE_IDS.culture, name: 'Culture — Default', category: 'culture', accent: '#9D2DFF' },
  ];
  for (const t of templates) {
    await prisma.badgeTemplate.upsert({
      where: { id: t.id },
      update: { name: t.name, category: t.category, accentColor: t.accent, ambientColor: t.accent },
      create: {
        id: t.id,
        name: t.name,
        category: t.category,
        variant: 'default',
        frameSvgUrl: `https://storage.smwhr.dev/frames/${t.category}_default.svg`,
        accentColor: t.accent,
        ambientColor: t.accent,
        config: {
          titleFont: 'Space Grotesk',
          titleWeight: 700,
          serialFont: 'JetBrains Mono',
          layout: 'standard',
        },
      },
    });
  }
  console.log(`✓ ${templates.length} badge templates`);
}

async function seedUsers() {
  const users = [
    { id: USER_IDS.moi, handle: 'moi', displayName: 'Moi', city: 'Tulancingo', country: 'MX', interests: ['music', 'sports', 'outdoor'], bio: 'Founder. Maker. Sometimes lost in concerts.', onboarded: new Date('2026-04-22') },
    { id: USER_IDS.sofia, handle: 'sofia', displayName: 'Sofía Cárdenas', city: 'Ciudad de México', country: 'MX', interests: ['music', 'festivals'], bio: 'Si toca, voy.', onboarded: new Date('2026-03-15') },
    { id: USER_IDS.carlos, handle: 'carlos', displayName: 'Carlos Reyes', city: 'Monterrey', country: 'MX', interests: ['sports', 'music'], onboarded: new Date('2026-02-20') },
    { id: USER_IDS.andrea, handle: 'andrea', displayName: 'Andrea Ruiz', city: 'Guadalajara', country: 'MX', interests: ['festivals', 'culture'], onboarded: new Date('2026-04-05') },
    { id: USER_IDS.beto, handle: 'beto', displayName: 'Beto Salazar', city: 'Ciudad de México', country: 'MX', interests: ['music'], bio: 'BTS Army desde 2015.', onboarded: new Date('2026-01-11') },
    { id: USER_IDS.lucia, handle: 'lucia', displayName: 'Lucía Torres', city: 'Bogotá', country: 'CO', interests: ['outdoor', 'culture'], onboarded: new Date('2026-03-30') },
    { id: USER_IDS.diego, handle: 'diego', displayName: 'Diego Aguilar', city: 'Buenos Aires', country: 'AR', interests: ['sports', 'festivals'], onboarded: new Date('2026-02-14') },
    { id: USER_IDS.ximena, handle: 'ximena', displayName: 'Ximena Vargas', city: 'Lima', country: 'PE', interests: ['music', 'culture'], onboarded: new Date('2026-04-10') },
    { id: USER_IDS.paula, handle: 'paula', displayName: 'Paula Hernández', city: 'Santiago', country: 'CL', interests: ['outdoor', 'sports'], onboarded: new Date('2026-03-01') },
  ];
  for (const u of users) {
    await prisma.user.upsert({
      where: { id: u.id },
      update: {
        handle: u.handle,
        displayName: u.displayName,
        bio: u.bio ?? null,
        city: u.city,
        countryCode: u.country,
        interests: u.interests,
        onboardingCompletedAt: u.onboarded,
      },
      create: {
        id: u.id,
        email: `${u.handle}@smwhr.demo`,
        handle: u.handle,
        displayName: u.displayName,
        bio: u.bio ?? null,
        city: u.city,
        countryCode: u.country,
        interests: u.interests,
        authProvider: 'demo',
        onboardingCompletedAt: u.onboarded,
      },
    });
  }
  console.log(`✓ ${users.length} demo users`);
}

async function seedFutureEvents() {
  // Test event "today" — wide window, short dwell so the active-quest
  // smoke runs in minutes. Pinned featured so it's easy to find on the
  // home feed during testing.
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayEnd = new Date();
  todayEnd.setHours(23, 59, 59, 0);

  const events: FutureEventInput[] = [
    { slug: 'prueba-tulancingo-hq', title: 'Prueba · HQ Tulancingo', venueName: 'Franz Behr 103', city: 'Tulancingo', category: 'culture', startsAt: todayStart, endsAt: todayEnd, dwellMin: 5, isFeatured: true, intentCount: 0, description: 'Evento de prueba para validar el dual-track tracker. Ventana abierta todo el día, dwell de 5 minutos.', heroColor: '#9D2DFF', venue: VENUES.franzBehr103 },
    { slug: 'padres-diamondbacks-harp-helu-2026-04-26', title: 'Padres vs Diamondbacks', artist: 'MLB Mexico City Series', venueName: 'Estadio Alfredo Harp Helú', city: 'Ciudad de México', category: 'sports', startsAt: new Date('2026-04-26T20:00:00Z'), endsAt: new Date('2026-04-26T23:30:00Z'), dwellMin: 60, isFeatured: true, intentCount: 4200, description: 'San Diego visita la CDMX. Tres horas de béisbol bajo techo en el Harp Helú.', heroColor: '#2DFF95', venue: VENUES.estadioHarpHelu },
    { slug: 'bts-mexico-2026-n1', title: 'BTS World Tour · Noche 1', artist: 'BTS', venueName: 'Estadio GNP Seguros', city: 'Ciudad de México', category: 'music', startsAt: new Date('2026-05-07T20:30:00-06:00'), endsAt: new Date('2026-05-07T23:30:00-06:00'), dwellMin: 45, isFeatured: true, intentCount: 8420, description: 'La primera de tres noches que cambian todo. ARMY mexicano por fin recibe a los siete.', heroColor: '#FF2D95', venue: VENUES.gnpSeguros },
    { slug: 'bts-mexico-2026-n2', title: 'BTS World Tour · Noche 2', artist: 'BTS', venueName: 'Estadio GNP Seguros', city: 'Ciudad de México', category: 'music', startsAt: new Date('2026-05-09T20:30:00-06:00'), endsAt: new Date('2026-05-09T23:30:00-06:00'), dwellMin: 45, isFeatured: true, intentCount: 7910, description: 'Segunda noche. La que definitivamente vas a recordar.', heroColor: '#FF2D95', venue: VENUES.gnpSeguros },
    { slug: 'bts-mexico-2026-n3', title: 'BTS World Tour · Noche 3', artist: 'BTS', venueName: 'Estadio GNP Seguros', city: 'Ciudad de México', category: 'music', startsAt: new Date('2026-05-10T20:30:00-06:00'), endsAt: new Date('2026-05-10T23:30:00-06:00'), dwellMin: 45, isFeatured: true, intentCount: 8120, description: 'La última. Todo lo que se lloró se llora. Encore.', heroColor: '#FF2D95', venue: VENUES.gnpSeguros },
    { slug: 'bad-bunny-cdmx-2026', title: 'Bad Bunny · Most Wanted Tour', artist: 'Bad Bunny', venueName: 'Estadio Azteca', city: 'Ciudad de México', category: 'music', startsAt: new Date('2026-06-14T21:00:00-06:00'), endsAt: new Date('2026-06-15T00:00:00-06:00'), dwellMin: 60, intentCount: 12300, description: 'Benito vuelve a México. Cuatro fechas, una sola noche tuya.', heroColor: '#FF2D95', venue: VENUES.estadioAzteca },
    { slug: 'rosalia-foro-sol-2026', title: 'Rosalía · Motomami Live', artist: 'Rosalía', venueName: 'Foro Sol', city: 'Ciudad de México', category: 'music', startsAt: new Date('2026-07-22T21:00:00-06:00'), endsAt: new Date('2026-07-23T00:00:00-06:00'), dwellMin: 60, intentCount: 4210, description: 'Motomami, la versión que solo la ves vivo.', heroColor: '#FF2D95', venue: VENUES.foroSol },
    { slug: 'mana-monterrey-2026', title: 'Maná · Vivir Sin Aire Tour', artist: 'Maná', venueName: 'Estadio BBVA', city: 'Monterrey', category: 'music', startsAt: new Date('2026-05-30T21:00:00-06:00'), endsAt: new Date('2026-05-30T23:30:00-06:00'), dwellMin: 60, intentCount: 2800, description: 'Clásico mexicano en estadio nuevo.', heroColor: '#FF2D95', venue: VENUES.estadioBBVA },
    { slug: 'clasico-nacional-2026-jun', title: 'Clásico Nacional · América vs Chivas', venueName: 'Estadio Azteca', city: 'Ciudad de México', category: 'sports', startsAt: new Date('2026-06-07T19:00:00-06:00'), endsAt: new Date('2026-06-07T21:00:00-06:00'), dwellMin: 60, intentCount: 5640, description: 'El más visto de la liga. La que vas a contar.', heroColor: '#2DFF95', venue: VENUES.estadioAzteca },
    { slug: 'rayados-tigres-clasico-regio-2026', title: 'Clásico Regio · Rayados vs Tigres', venueName: 'Estadio BBVA', city: 'Monterrey', category: 'sports', startsAt: new Date('2026-08-16T19:00:00-06:00'), endsAt: new Date('2026-08-16T21:00:00-06:00'), dwellMin: 60, intentCount: 3120, description: 'Norte contra norte. Solo norteños lo entienden.', heroColor: '#2DFF95', venue: VENUES.estadioBBVA },
    { slug: 'boca-river-bombonera-2026', title: 'Superclásico · Boca vs River', venueName: 'La Bombonera', city: 'Buenos Aires', country: 'AR', category: 'sports', startsAt: new Date('2026-09-27T17:00:00-03:00'), endsAt: new Date('2026-09-27T19:00:00-03:00'), dwellMin: 60, intentCount: 8800, description: 'No hay otro como éste. Punto.', heroColor: '#2DFF95', venue: VENUES.laBombonera },
    { slug: 'corona-capital-2026', title: 'Corona Capital 2026', venueName: 'Autódromo Hermanos Rodríguez', city: 'Ciudad de México', category: 'festivals', startsAt: new Date('2026-11-14T13:00:00-06:00'), endsAt: new Date('2026-11-16T23:30:00-06:00'), dwellMin: 90, intentCount: 11200, description: 'Tres días. Diez escenarios. Una multitud que solo se reconoce en noviembre.', heroColor: '#FF9D2D', venue: VENUES.autodromo },
    { slug: 'vive-latino-2026', title: 'Vive Latino 2026', venueName: 'Foro Sol', city: 'Ciudad de México', category: 'festivals', startsAt: new Date('2026-03-14T13:00:00-06:00'), endsAt: new Date('2026-03-15T23:30:00-06:00'), dwellMin: 90, intentCount: 7430, description: 'El gran festival latinoamericano.', heroColor: '#FF9D2D', venue: VENUES.foroSol },
    { slug: 'coordenada-2026', title: 'Festival Coordenada', venueName: 'Trasloma', city: 'Guadalajara', category: 'festivals', startsAt: new Date('2026-10-24T14:00:00-06:00'), endsAt: new Date('2026-10-25T23:30:00-06:00'), dwellMin: 90, intentCount: 2310, description: 'El festival que está convirtiendo Guadalajara en capital.', heroColor: '#FF9D2D', venue: VENUES.trasloma },
    { slug: 'iztaccihuatl-luna-llena-2026-jul', title: 'Iztaccíhuatl · Luna llena', venueName: 'Parque Nacional Izta-Popo', city: 'Amecameca', category: 'outdoor', startsAt: new Date('2026-07-19T04:00:00-06:00'), endsAt: new Date('2026-07-19T16:00:00-06:00'), dwellMin: 120, intentCount: 180, description: 'Salida a las 4 am. Cumbre en luna llena. No es turismo.', heroColor: '#2DC8FF', venue: VENUES.iztaccihuatl },
    { slug: 'tepozteco-amanecer-2026-may', title: 'Tepozteco al amanecer', venueName: 'Cerro del Tepozteco', city: 'Tepoztlán', category: 'outdoor', startsAt: new Date('2026-05-25T05:30:00-06:00'), endsAt: new Date('2026-05-25T09:30:00-06:00'), dwellMin: 60, intentCount: 92, description: 'Salida pre-amanecer en domingo. Llegamos arriba con sol.', heroColor: '#2DC8FF', venue: VENUES.tepozteco },
    { slug: 'cervantino-2026', title: 'Festival Cervantino', venueName: 'Centro Histórico', city: 'Guanajuato', category: 'culture', startsAt: new Date('2026-10-09T18:00:00-06:00'), endsAt: new Date('2026-10-25T23:00:00-06:00'), dwellMin: 60, intentCount: 1740, description: 'El festival cultural más grande de Latinoamérica.', heroColor: '#9D2DFF', venue: VENUES.guanajuatoCentro },
  ];
  for (const e of events) {
    await upsertFutureEvent(prisma, e);
  }
  console.log(`✓ ${events.length} future events (with geofence polygons)`);
}

interface PastEvent {
  slug: string;
  title: string;
  artist?: string;
  venueName: string;
  city: string;
  country?: string;
  category: keyof typeof TEMPLATE_IDS;
  startsAt: Date;
  venue: VenueLoc;
}

async function seedPastEvents(): Promise<Record<string, string>> {
  const past: PastEvent[] = [
    { slug: 'past-rosalia-2025', title: 'Rosalía · Motomami', artist: 'Rosalía', venueName: 'Foro Sol', city: 'Ciudad de México', category: 'music', startsAt: new Date('2025-08-14T21:00:00-06:00'), venue: VENUES.foroSol },
    { slug: 'past-corona-2025', title: 'Corona Capital 2025', venueName: 'Autódromo Hermanos Rodríguez', city: 'Ciudad de México', category: 'festivals', startsAt: new Date('2025-11-15T13:00:00-06:00'), venue: VENUES.autodromo },
    { slug: 'past-clasico-2025', title: 'Clásico Nacional · América vs Chivas', venueName: 'Estadio Azteca', city: 'Ciudad de México', category: 'sports', startsAt: new Date('2025-09-21T19:00:00-06:00'), venue: VENUES.estadioAzteca },
    { slug: 'past-iztaccihuatl-2024', title: 'Iztaccíhuatl · Cumbre', venueName: 'Parque Nacional Izta-Popo', city: 'Amecameca', category: 'outdoor', startsAt: new Date('2024-12-28T04:00:00-06:00'), venue: VENUES.iztaccihuatl },
    { slug: 'past-cervantino-2024', title: 'Festival Cervantino 2024', venueName: 'Centro Histórico', city: 'Guanajuato', category: 'culture', startsAt: new Date('2024-10-18T19:00:00-06:00'), venue: VENUES.guanajuatoCentro },
    { slug: 'past-mana-2024', title: 'Maná · Hecho en México', artist: 'Maná', venueName: 'Auditorio Telmex', city: 'Guadalajara', category: 'music', startsAt: new Date('2024-06-08T21:00:00-06:00'), venue: VENUES.auditorioTelmex },
    { slug: 'past-vivelatino-2024', title: 'Vive Latino 2024', venueName: 'Foro Sol', city: 'Ciudad de México', category: 'festivals', startsAt: new Date('2024-03-16T13:00:00-06:00'), venue: VENUES.foroSol },
  ];
  const slugToId: Record<string, string> = {};
  for (const e of past) {
    const ends = new Date(e.startsAt.getTime() + 4 * 60 * 60 * 1000);
    const event = await prisma.event.upsert({
      where: { slug: e.slug },
      update: { title: e.title, status: 'past', badgeTemplateId: TEMPLATE_IDS[e.category] },
      create: {
        slug: e.slug,
        title: e.title,
        artist: e.artist ?? null,
        venueName: e.venueName,
        city: e.city,
        countryCode: e.country ?? 'MX',
        category: e.category,
        startsAt: e.startsAt,
        endsAt: ends,
        dwellMinimumMin: 60,
        status: 'past',
        badgeTemplateId: TEMPLATE_IDS[e.category],
      },
    });
    slugToId[e.slug] = event.id;
    await setEventGeofence(prisma, event.id, e.venue);
  }
  console.log(`✓ ${past.length} past events (with geofence polygons)`);
  return slugToId;
}

async function seedIntents() {
  const slugs = ['bts-mexico-2026-n1', 'bts-mexico-2026-n2', 'bts-mexico-2026-n3', 'corona-capital-2026'];
  for (const slug of slugs) {
    const event = await prisma.event.findUnique({ where: { slug } });
    if (!event) continue;
    await prisma.intent.upsert({
      where: { userId_eventId: { userId: USER_IDS.moi, eventId: event.id } },
      update: {},
      create: { userId: USER_IDS.moi, eventId: event.id, createdAt: new Date('2026-04-18T22:14:00-06:00') },
    });
  }
  console.log(`✓ ${slugs.length} intents on @moi`);
}

async function seedBadges(pastEventIds: Record<string, string>) {
  const records = [
    { id: '001', slug: 'past-rosalia-2025', category: 'music' as const, serial: 412, total: 28412, score: 96, awardedAt: new Date('2025-08-15T00:30:00-06:00') },
    { id: '002', slug: 'past-corona-2025', category: 'festivals' as const, serial: 1218, total: 41200, score: 91, awardedAt: new Date('2025-11-16T01:00:00-06:00') },
    { id: '003', slug: 'past-clasico-2025', category: 'sports' as const, serial: 87, total: 4210, score: 94, awardedAt: new Date('2025-09-22T00:30:00-06:00') },
    { id: '004', slug: 'past-iztaccihuatl-2024', category: 'outdoor' as const, serial: 12, total: 89, score: 99, awardedAt: new Date('2024-12-28T14:00:00-06:00') },
    { id: '005', slug: 'past-cervantino-2024', category: 'culture' as const, serial: 240, total: 3120, score: 88, awardedAt: new Date('2024-10-19T01:30:00-06:00') },
    { id: '006', slug: 'past-mana-2024', category: 'music' as const, serial: 89, total: 9120, score: 92, awardedAt: new Date('2024-06-09T00:00:00-06:00') },
    { id: '007', slug: 'past-vivelatino-2024', category: 'festivals' as const, serial: 3104, total: 38400, score: 85, awardedAt: new Date('2024-03-17T02:00:00-06:00') },
  ];
  for (const r of records) {
    const eventId = pastEventIds[r.slug];
    if (!eventId) continue;
    const badgeUuid = `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa${r.id}`;
    await prisma.badge.upsert({
      where: { userId_eventId: { userId: USER_IDS.moi, eventId } },
      update: {
        serialNumber: r.serial,
        totalForEvent: r.total,
        verificationScore: r.score,
        isVerified: true,
        awardedAt: r.awardedAt,
        templateId: TEMPLATE_IDS[r.category],
      },
      create: {
        id: badgeUuid,
        userId: USER_IDS.moi,
        eventId,
        templateId: TEMPLATE_IDS[r.category],
        serialNumber: r.serial,
        totalForEvent: r.total,
        verificationScore: r.score,
        isVerified: true,
        awardedAt: r.awardedAt,
        composedImageUrl: `https://placehold.co/800x1200/0a0a0a/FF2D95?text=bdg-${r.id}`,
      },
    });
  }
  console.log(`✓ ${records.length} historic badges on @moi`);
}

async function main() {
  console.log('🌱 Seeding smwhr…');
  await seedBadgeTemplates();
  await seedUsers();
  await seedFutureEvents();
  const pastIds = await seedPastEvents();
  await seedIntents();
  await seedBadges(pastIds);
  console.log('✓ done');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
