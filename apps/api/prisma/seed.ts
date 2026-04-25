// prisma/seed.ts
// Seed inicial smwhr LATAM
// Eventos curados: música, deportes, festivales, outdoor en México 2026
// Ejecutar con: npx prisma db seed

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Polygons aproximados de venues principales en CDMX
// IMPORTANTE: ajustar a coordenadas reales antes de producción
const VENUES = {
  estadioGNPSeguros: {
    polygon: `POLYGON((
      -99.2080 19.4030,
      -99.2030 19.4030,
      -99.2030 19.3990,
      -99.2080 19.3990,
      -99.2080 19.4030
    ))`,
    center: 'POINT(-99.2055 19.4010)',
  },
  estadioAzteca: {
    polygon: `POLYGON((
      -99.1530 19.3045,
      -99.1490 19.3045,
      -99.1490 19.3010,
      -99.1530 19.3010,
      -99.1530 19.3045
    ))`,
    center: 'POINT(-99.1510 19.3028)',
  },
  foroSol: {
    polygon: `POLYGON((
      -99.0905 19.4045,
      -99.0855 19.4045,
      -99.0855 19.4005,
      -99.0905 19.4005,
      -99.0905 19.4045
    ))`,
    center: 'POINT(-99.0880 19.4025)',
  },
  auditorioNacional: {
    polygon: `POLYGON((
      -99.1898 19.4256,
      -99.1875 19.4256,
      -99.1875 19.4238,
      -99.1898 19.4238,
      -99.1898 19.4256
    ))`,
    center: 'POINT(-99.1886 19.4247)',
  },
  parqueFundidora: {
    polygon: `POLYGON((
      -100.2890 25.6810,
      -100.2820 25.6810,
      -100.2820 25.6760,
      -100.2890 25.6760,
      -100.2890 25.6810
    ))`,
    center: 'POINT(-100.2855 25.6785)',
  },
  lasEstacas: {
    polygon: `POLYGON((
      -99.1310 18.7280,
      -99.1250 18.7280,
      -99.1250 18.7230,
      -99.1310 18.7230,
      -99.1310 18.7280
    ))`,
    center: 'POINT(-99.1280 18.7255)',
  },
};

async function main() {
  console.log('🌱 Seeding smwhr LATAM database...');

  // ============================================================
  // BADGE TEMPLATES
  // ============================================================

  const musicTemplate = await prisma.badgeTemplate.upsert({
    where: { id: '00000000-0000-0000-0000-000000000001' },
    update: {},
    create: {
      id: '00000000-0000-0000-0000-000000000001',
      name: 'Music — Default',
      category: 'music',
      variant: 'default',
      frameSvgUrl: 'https://storage.smwhr.quest/frames/music_default.svg',
      accentColor: '#FF2D95',
      ambientColor: '#FF2D95',
      config: {
        titleFont: 'Space Grotesk',
        titleWeight: 700,
        serialFont: 'JetBrains Mono',
        layout: 'standard',
      },
    },
  });

  const sportsTemplate = await prisma.badgeTemplate.upsert({
    where: { id: '00000000-0000-0000-0000-000000000002' },
    update: {},
    create: {
      id: '00000000-0000-0000-0000-000000000002',
      name: 'Sports — Default',
      category: 'sports',
      variant: 'default',
      frameSvgUrl: 'https://storage.smwhr.quest/frames/sports_default.svg',
      accentColor: '#2DFF95',
      ambientColor: '#2DFF95',
      config: {
        titleFont: 'Space Grotesk',
        titleWeight: 700,
        serialFont: 'JetBrains Mono',
        layout: 'standard',
      },
    },
  });

  const festivalsTemplate = await prisma.badgeTemplate.upsert({
    where: { id: '00000000-0000-0000-0000-000000000003' },
    update: {},
    create: {
      id: '00000000-0000-0000-0000-000000000003',
      name: 'Festivals — Default',
      category: 'festivals',
      variant: 'default',
      frameSvgUrl: 'https://storage.smwhr.quest/frames/festivals_default.svg',
      accentColor: '#FF9D2D',
      ambientColor: '#FF9D2D',
      config: {
        titleFont: 'Space Grotesk',
        titleWeight: 700,
        serialFont: 'JetBrains Mono',
        layout: 'standard',
      },
    },
  });

  const outdoorTemplate = await prisma.badgeTemplate.upsert({
    where: { id: '00000000-0000-0000-0000-000000000004' },
    update: {},
    create: {
      id: '00000000-0000-0000-0000-000000000004',
      name: 'Outdoor — Default',
      category: 'outdoor',
      variant: 'default',
      frameSvgUrl: 'https://storage.smwhr.quest/frames/outdoor_default.svg',
      accentColor: '#2DC8FF',
      ambientColor: '#2DC8FF',
      config: {
        titleFont: 'Space Grotesk',
        titleWeight: 700,
        serialFont: 'JetBrains Mono',
        layout: 'standard',
      },
    },
  });

  console.log('✅ Badge templates seeded (4 categories)');

  // ============================================================
  // EVENTOS HERO MAYO 2026
  // ============================================================

  // BTS World Tour - hero event de R0.1
  const bts = await prisma.event.upsert({
    where: { slug: 'bts-world-tour-cdmx-2026-05-07' },
    update: {},
    create: {
      slug: 'bts-world-tour-cdmx-2026-05-07',
      title: 'World Tour 2026',
      artist: 'BTS',
      venueName: 'Estadio GNP Seguros',
      venueAddress: 'Av. Río Churubusco 17, Ciudad de México',
      city: 'Ciudad de México',
      countryCode: 'MX',
      category: 'music',
      subcategory: 'concert',
      startsAt: new Date('2026-05-07T20:00:00-06:00'),
      endsAt: new Date('2026-05-07T23:30:00-06:00'),
      dwellMinimumMin: 60,
      geofenceRadiusM: 250,
      heroColor: '#FF2D95',
      isFeatured: true,
      status: 'scheduled',
      badgeTemplateId: musicTemplate.id,
      totalCapacity: 65000,
    },
  });

  await prisma.$executeRawUnsafe(`
    UPDATE events
    SET geofence_polygon = ST_GeogFromText('${VENUES.estadioGNPSeguros.polygon}'),
        geofence_center = ST_GeogFromText('${VENUES.estadioGNPSeguros.center}')
    WHERE id = '${bts.id}'
  `);

  // BTS día 2
  await prisma.event.upsert({
    where: { slug: 'bts-world-tour-cdmx-2026-05-09' },
    update: {},
    create: {
      slug: 'bts-world-tour-cdmx-2026-05-09',
      title: 'World Tour 2026 — Día 2',
      artist: 'BTS',
      venueName: 'Estadio GNP Seguros',
      city: 'Ciudad de México',
      category: 'music',
      subcategory: 'concert',
      startsAt: new Date('2026-05-09T20:00:00-06:00'),
      endsAt: new Date('2026-05-09T23:30:00-06:00'),
      dwellMinimumMin: 60,
      geofenceRadiusM: 250,
      heroColor: '#FF2D95',
      status: 'scheduled',
      badgeTemplateId: musicTemplate.id,
      totalCapacity: 65000,
    },
  });

  // BTS día 3
  await prisma.event.upsert({
    where: { slug: 'bts-world-tour-cdmx-2026-05-10' },
    update: {},
    create: {
      slug: 'bts-world-tour-cdmx-2026-05-10',
      title: 'World Tour 2026 — Día 3',
      artist: 'BTS',
      venueName: 'Estadio GNP Seguros',
      city: 'Ciudad de México',
      category: 'music',
      subcategory: 'concert',
      startsAt: new Date('2026-05-10T20:00:00-06:00'),
      endsAt: new Date('2026-05-10T23:30:00-06:00'),
      dwellMinimumMin: 60,
      geofenceRadiusM: 250,
      heroColor: '#FF2D95',
      status: 'scheduled',
      badgeTemplateId: musicTemplate.id,
      totalCapacity: 65000,
    },
  });

  console.log('✅ BTS hero events seeded (3 días)');

  // ============================================================
  // MÚSICA — Conciertos secundarios
  // ============================================================

  await prisma.event.upsert({
    where: { slug: 'olivia-dean-pepsi-center-2026-05-12' },
    update: {},
    create: {
      slug: 'olivia-dean-pepsi-center-2026-05-12',
      title: 'The Art of Loving Tour',
      artist: 'Olivia Dean',
      venueName: 'Pepsi Center WTC',
      city: 'Ciudad de México',
      category: 'music',
      subcategory: 'concert',
      startsAt: new Date('2026-05-12T21:00:00-06:00'),
      endsAt: new Date('2026-05-12T23:30:00-06:00'),
      dwellMinimumMin: 60,
      geofenceRadiusM: 150,
      heroColor: '#FF2D95',
      status: 'scheduled',
      badgeTemplateId: musicTemplate.id,
      totalCapacity: 7500,
    },
  });

  await prisma.event.upsert({
    where: { slug: 'caifanes-auditorio-nacional-2026-05-22' },
    update: {},
    create: {
      slug: 'caifanes-auditorio-nacional-2026-05-22',
      title: 'Tour 30 Aniversario',
      artist: 'Caifanes',
      venueName: 'Auditorio Nacional',
      city: 'Ciudad de México',
      category: 'music',
      subcategory: 'concert',
      startsAt: new Date('2026-05-22T20:30:00-06:00'),
      endsAt: new Date('2026-05-22T23:00:00-06:00'),
      dwellMinimumMin: 60,
      geofenceRadiusM: 100,
      heroColor: '#FF2D95',
      status: 'scheduled',
      badgeTemplateId: musicTemplate.id,
      totalCapacity: 9700,
    },
  });

  await prisma.event.upsert({
    where: { slug: 'natanael-cano-palacio-deportes-2026-05-28' },
    update: {},
    create: {
      slug: 'natanael-cano-palacio-deportes-2026-05-28',
      title: 'Corridos Tumbados Tour',
      artist: 'Natanael Cano',
      venueName: 'Palacio de los Deportes',
      city: 'Ciudad de México',
      category: 'music',
      subcategory: 'concert',
      startsAt: new Date('2026-05-28T21:00:00-06:00'),
      endsAt: new Date('2026-05-28T23:30:00-06:00'),
      dwellMinimumMin: 60,
      geofenceRadiusM: 200,
      heroColor: '#FF2D95',
      status: 'scheduled',
      badgeTemplateId: musicTemplate.id,
      totalCapacity: 22000,
    },
  });

  console.log('✅ Music events seeded (3 conciertos secundarios)');

  // ============================================================
  // SPORTS — Liga MX y Mundial 2026
  // ============================================================

  // Mundial 2026 - apertura México vs Canadá
  const mundialOpening = await prisma.event.upsert({
    where: { slug: 'mundial-mexico-vs-canada-azteca-2026-06-11' },
    update: {},
    create: {
      slug: 'mundial-mexico-vs-canada-azteca-2026-06-11',
      title: 'México vs Canadá',
      artist: 'Mundial 2026',
      venueName: 'Estadio Azteca',
      city: 'Ciudad de México',
      category: 'sports',
      subcategory: 'football_match',
      startsAt: new Date('2026-06-11T19:00:00-06:00'),
      endsAt: new Date('2026-06-11T21:30:00-06:00'),
      dwellMinimumMin: 75,
      geofenceRadiusM: 350,
      heroColor: '#2DFF95',
      isFeatured: true,
      status: 'scheduled',
      badgeTemplateId: sportsTemplate.id,
      totalCapacity: 87000,
    },
  });

  await prisma.$executeRawUnsafe(`
    UPDATE events
    SET geofence_polygon = ST_GeogFromText('${VENUES.estadioAzteca.polygon}'),
        geofence_center = ST_GeogFromText('${VENUES.estadioAzteca.center}')
    WHERE id = '${mundialOpening.id}'
  `);

  await prisma.event.upsert({
    where: { slug: 'america-vs-chivas-azteca-2026-05-18' },
    update: {},
    create: {
      slug: 'america-vs-chivas-azteca-2026-05-18',
      title: 'Clásico Nacional',
      artist: 'América vs Chivas',
      venueName: 'Estadio Azteca',
      city: 'Ciudad de México',
      category: 'sports',
      subcategory: 'football_match',
      startsAt: new Date('2026-05-18T21:00:00-06:00'),
      endsAt: new Date('2026-05-18T23:00:00-06:00'),
      dwellMinimumMin: 60,
      geofenceRadiusM: 350,
      heroColor: '#2DFF95',
      status: 'scheduled',
      badgeTemplateId: sportsTemplate.id,
      totalCapacity: 87000,
    },
  });

  await prisma.event.upsert({
    where: { slug: 'tigres-vs-monterrey-universitario-2026-05-25' },
    update: {},
    create: {
      slug: 'tigres-vs-monterrey-universitario-2026-05-25',
      title: 'Clásico Regio',
      artist: 'Tigres vs Monterrey',
      venueName: 'Estadio Universitario',
      city: 'San Nicolás de los Garza',
      category: 'sports',
      subcategory: 'football_match',
      startsAt: new Date('2026-05-25T20:00:00-06:00'),
      endsAt: new Date('2026-05-25T22:00:00-06:00'),
      dwellMinimumMin: 60,
      geofenceRadiusM: 250,
      heroColor: '#2DFF95',
      status: 'scheduled',
      badgeTemplateId: sportsTemplate.id,
      totalCapacity: 42000,
    },
  });

  await prisma.event.upsert({
    where: { slug: 'cruz-azul-vs-pumas-cu-2026-05-30' },
    update: {},
    create: {
      slug: 'cruz-azul-vs-pumas-cu-2026-05-30',
      title: 'Cruz Azul vs Pumas',
      artist: 'Liga MX Jornada Final',
      venueName: 'Estadio Olímpico Universitario',
      city: 'Ciudad de México',
      category: 'sports',
      subcategory: 'football_match',
      startsAt: new Date('2026-05-30T21:00:00-06:00'),
      endsAt: new Date('2026-05-30T23:00:00-06:00'),
      dwellMinimumMin: 60,
      geofenceRadiusM: 250,
      heroColor: '#2DFF95',
      status: 'scheduled',
      badgeTemplateId: sportsTemplate.id,
      totalCapacity: 72000,
    },
  });

  console.log('✅ Sports events seeded (Mundial + 3 partidos Liga MX)');

  // ============================================================
  // FESTIVALES — Calendario 2026-2027
  // ============================================================

  const coronaCapital = await prisma.event.upsert({
    where: { slug: 'corona-capital-cdmx-2026-10-17' },
    update: {},
    create: {
      slug: 'corona-capital-cdmx-2026-10-17',
      title: 'Corona Capital 2026',
      artist: 'Multiple Artists',
      venueName: 'Curva 4, Autódromo Hermanos Rodríguez',
      city: 'Ciudad de México',
      category: 'festivals',
      subcategory: 'music_festival',
      startsAt: new Date('2026-10-17T13:00:00-06:00'),
      endsAt: new Date('2026-10-19T23:00:00-06:00'),
      dwellMinimumMin: 120,
      geofenceRadiusM: 500,
      heroColor: '#FF9D2D',
      status: 'scheduled',
      badgeTemplateId: festivalsTemplate.id,
      totalCapacity: 80000,
    },
  });

  await prisma.event.upsert({
    where: { slug: 'hipnosis-cdmx-2026-11-14' },
    update: {},
    create: {
      slug: 'hipnosis-cdmx-2026-11-14',
      title: 'Hipnosis 2026',
      artist: 'Multiple Artists',
      venueName: 'Parque Bicentenario',
      city: 'Ciudad de México',
      category: 'festivals',
      subcategory: 'music_festival',
      startsAt: new Date('2026-11-14T13:00:00-06:00'),
      endsAt: new Date('2026-11-14T23:00:00-06:00'),
      dwellMinimumMin: 90,
      geofenceRadiusM: 400,
      heroColor: '#FF9D2D',
      status: 'scheduled',
      badgeTemplateId: festivalsTemplate.id,
      totalCapacity: 30000,
    },
  });

  await prisma.event.upsert({
    where: { slug: 'bahidora-las-estacas-2027-02-13' },
    update: {},
    create: {
      slug: 'bahidora-las-estacas-2027-02-13',
      title: 'Bahidorá 2027',
      artist: 'Multiple Artists',
      venueName: 'Las Estacas',
      city: 'Tlaltizapán, Morelos',
      category: 'festivals',
      subcategory: 'music_festival',
      startsAt: new Date('2027-02-13T14:00:00-06:00'),
      endsAt: new Date('2027-02-15T05:00:00-06:00'),
      dwellMinimumMin: 240,
      geofenceRadiusM: 600,
      heroColor: '#FF9D2D',
      status: 'scheduled',
      badgeTemplateId: festivalsTemplate.id,
      totalCapacity: 12000,
    },
  });

  await prisma.event.upsert({
    where: { slug: 'vive-latino-foro-sol-2027-03-13' },
    update: {},
    create: {
      slug: 'vive-latino-foro-sol-2027-03-13',
      title: 'Vive Latino 2027',
      artist: 'Multiple Artists',
      venueName: 'Foro Sol',
      city: 'Ciudad de México',
      category: 'festivals',
      subcategory: 'music_festival',
      startsAt: new Date('2027-03-13T13:00:00-06:00'),
      endsAt: new Date('2027-03-14T23:00:00-06:00'),
      dwellMinimumMin: 120,
      geofenceRadiusM: 450,
      heroColor: '#FF9D2D',
      status: 'scheduled',
      badgeTemplateId: festivalsTemplate.id,
      totalCapacity: 65000,
    },
  });

  await prisma.event.upsert({
    where: { slug: 'pal-norte-fundidora-2027-04-02' },
    update: {},
    create: {
      slug: 'pal-norte-fundidora-2027-04-02',
      title: "Pa'l Norte 2027",
      artist: 'Multiple Artists',
      venueName: 'Parque Fundidora',
      city: 'Monterrey',
      category: 'festivals',
      subcategory: 'music_festival',
      startsAt: new Date('2027-04-02T14:00:00-06:00'),
      endsAt: new Date('2027-04-04T23:00:00-06:00'),
      dwellMinimumMin: 120,
      geofenceRadiusM: 500,
      heroColor: '#FF9D2D',
      status: 'scheduled',
      badgeTemplateId: festivalsTemplate.id,
      totalCapacity: 90000,
    },
  });

  console.log('✅ Festivals seeded (Corona Capital, Hipnosis, Bahidorá, Vive Latino, Pa\'l Norte)');

  // ============================================================
  // OUTDOOR
  // ============================================================

  await prisma.event.upsert({
    where: { slug: 'cicloton-cdmx-2026-05-24' },
    update: {},
    create: {
      slug: 'cicloton-cdmx-2026-05-24',
      title: 'Ciclotón Familiar',
      artist: 'CDMX',
      venueName: 'Reforma',
      city: 'Ciudad de México',
      category: 'outdoor',
      subcategory: 'cycling',
      startsAt: new Date('2026-05-24T08:00:00-06:00'),
      endsAt: new Date('2026-05-24T14:00:00-06:00'),
      dwellMinimumMin: 60,
      geofenceRadiusM: 1000,
      heroColor: '#2DC8FF',
      status: 'scheduled',
      badgeTemplateId: outdoorTemplate.id,
      totalCapacity: 50000,
    },
  });

  await prisma.event.upsert({
    where: { slug: 'pico-orizaba-ascenso-2026-06-07' },
    update: {},
    create: {
      slug: 'pico-orizaba-ascenso-2026-06-07',
      title: 'Ascenso Citlaltépetl',
      artist: 'Pico de Orizaba',
      venueName: 'Pico de Orizaba',
      city: 'Tlachichuca',
      category: 'outdoor',
      subcategory: 'mountaineering',
      startsAt: new Date('2026-06-07T03:00:00-06:00'),
      endsAt: new Date('2026-06-07T18:00:00-06:00'),
      dwellMinimumMin: 240,
      geofenceRadiusM: 800,
      heroColor: '#2DC8FF',
      status: 'scheduled',
      badgeTemplateId: outdoorTemplate.id,
    },
  });

  console.log('✅ Outdoor events seeded (Ciclotón, Pico de Orizaba)');

  console.log(`
  ═══════════════════════════════════════════════════════════
  Seed completado:
  - 4 badge templates (music, sports, festivals, outdoor)
  - 16 eventos LATAM total:
    · 6 música (3 BTS hero + 3 secundarios)
    · 4 deportes (Mundial + Liga MX)
    · 5 festivales (CDMX + Monterrey)
    · 2 outdoor (CDMX + Pico de Orizaba)
  ═══════════════════════════════════════════════════════════
  `);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
