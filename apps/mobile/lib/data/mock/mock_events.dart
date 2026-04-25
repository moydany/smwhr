import '../models/event.dart';
import '../models/event_category.dart';
import '../models/lat_lng.dart';

/// 16 LATAM events spanning the 5 verticals, hydrated for R0.1 demos.
///
/// Hero events: BTS x3 nights at Estadio GNP Seguros (the launch anchor).
/// Geofence polygons are rough rectangles around real venues — replaced
/// with surveyed polygons in Phase 2.
final List<Event> mockEvents = [
  // === BTS — Hero anchor (3 nights) =====================================
  Event(
    id: 'evt-bts-mx-n1',
    slug: 'bts-mexico-2026-n1',
    title: 'BTS World Tour · Noche 1',
    artistName: 'BTS',
    venueName: 'Estadio GNP Seguros',
    city: 'Ciudad de México',
    countryCode: 'MX',
    startsAt: DateTime(2026, 5, 7, 20, 30),
    endsAt: DateTime(2026, 5, 7, 23, 30),
    description:
        'La primera de tres noches que cambian todo. ARMY mexicano por fin '
        'recibe a los siete. Estadio lleno, lluvia probable, vibra eterna.',
    category: EventCategory.music,
    geofencePolygon: _polygonGNPSeguros,
    dwellMinimumMin: 45,
    posterUrl: 'https://placehold.co/600x800/0a0a0a/FF2D95?text=BTS+N1',
    heroImageUrl: 'https://placehold.co/1200x800/0a0a0a/FF2D95?text=BTS',
    ticketmasterUrl: 'https://www.ticketmaster.com.mx/bts-tickets',
    promoterName: 'OCESA',
    intentCount: 8420,
    verifiedAttendeeCount: 0,
    isFeatured: true,
    badgeFrameUrl: 'assets/badges/frame_music.svg',
  ),
  Event(
    id: 'evt-bts-mx-n2',
    slug: 'bts-mexico-2026-n2',
    title: 'BTS World Tour · Noche 2',
    artistName: 'BTS',
    venueName: 'Estadio GNP Seguros',
    city: 'Ciudad de México',
    countryCode: 'MX',
    startsAt: DateTime(2026, 5, 9, 20, 30),
    endsAt: DateTime(2026, 5, 9, 23, 30),
    description: 'Segunda noche. La que definitivamente vas a recordar.',
    category: EventCategory.music,
    geofencePolygon: _polygonGNPSeguros,
    dwellMinimumMin: 45,
    posterUrl: 'https://placehold.co/600x800/0a0a0a/FF2D95?text=BTS+N2',
    ticketmasterUrl: 'https://www.ticketmaster.com.mx/bts-tickets',
    promoterName: 'OCESA',
    intentCount: 7910,
    isFeatured: true,
    badgeFrameUrl: 'assets/badges/frame_music.svg',
  ),
  Event(
    id: 'evt-bts-mx-n3',
    slug: 'bts-mexico-2026-n3',
    title: 'BTS World Tour · Noche 3',
    artistName: 'BTS',
    venueName: 'Estadio GNP Seguros',
    city: 'Ciudad de México',
    countryCode: 'MX',
    startsAt: DateTime(2026, 5, 10, 20, 30),
    endsAt: DateTime(2026, 5, 10, 23, 30),
    description: 'La última. Todo lo que se lloró se llora. Encore.',
    category: EventCategory.music,
    geofencePolygon: _polygonGNPSeguros,
    dwellMinimumMin: 45,
    posterUrl: 'https://placehold.co/600x800/0a0a0a/FF2D95?text=BTS+N3',
    ticketmasterUrl: 'https://www.ticketmaster.com.mx/bts-tickets',
    promoterName: 'OCESA',
    intentCount: 8120,
    isFeatured: true,
    badgeFrameUrl: 'assets/badges/frame_music.svg',
  ),

  // === Música — el resto ================================================
  Event(
    id: 'evt-bad-bunny-cdmx',
    slug: 'bad-bunny-cdmx-2026',
    title: 'Bad Bunny · Most Wanted Tour',
    artistName: 'Bad Bunny',
    venueName: 'Estadio Azteca',
    city: 'Ciudad de México',
    countryCode: 'MX',
    startsAt: DateTime(2026, 6, 14, 21, 0),
    description: 'Benito vuelve a México. Cuatro fechas, una sola noche '
        'tuya.',
    category: EventCategory.music,
    geofencePolygon: _polygonAzteca,
    posterUrl: 'https://placehold.co/600x800/121212/FF2D95?text=Bad+Bunny',
    promoterName: 'OCESA',
    intentCount: 12300,
    badgeFrameUrl: 'assets/badges/frame_music.svg',
  ),
  Event(
    id: 'evt-rosalia-foro',
    slug: 'rosalia-foro-sol-2026',
    title: 'Rosalía · Motomami Live',
    artistName: 'Rosalía',
    venueName: 'Foro Sol',
    city: 'Ciudad de México',
    countryCode: 'MX',
    startsAt: DateTime(2026, 7, 22, 21, 0),
    description: 'Motomami, la versión que solo la ves vivo.',
    category: EventCategory.music,
    geofencePolygon: _polygonForoSol,
    posterUrl: 'https://placehold.co/600x800/121212/FF2D95?text=Rosalia',
    promoterName: 'OCESA',
    intentCount: 4210,
    badgeFrameUrl: 'assets/badges/frame_music.svg',
  ),
  Event(
    id: 'evt-mana-monterrey',
    slug: 'mana-monterrey-2026',
    title: 'Maná · Vivir Sin Aire Tour',
    artistName: 'Maná',
    venueName: 'Estadio BBVA',
    city: 'Monterrey',
    countryCode: 'MX',
    startsAt: DateTime(2026, 5, 30, 21, 0),
    description: 'Clásico mexicano en estadio nuevo.',
    category: EventCategory.music,
    geofencePolygon: _genericPolygon(25.6692, -100.2447),
    posterUrl: 'https://placehold.co/600x800/121212/FF2D95?text=Mana',
    intentCount: 2800,
    badgeFrameUrl: 'assets/badges/frame_music.svg',
  ),

  // === Deportes ========================================================
  Event(
    id: 'evt-clasico-nacional',
    slug: 'clasico-nacional-2026-jun',
    title: 'Clásico Nacional · América vs Chivas',
    venueName: 'Estadio Azteca',
    city: 'Ciudad de México',
    countryCode: 'MX',
    startsAt: DateTime(2026, 6, 7, 19, 0),
    description: 'El más visto de la liga. La que vas a contar.',
    category: EventCategory.sports,
    geofencePolygon: _polygonAzteca,
    posterUrl: 'https://placehold.co/600x800/121212/2DFF95?text=Clasico',
    intentCount: 5640,
    badgeFrameUrl: 'assets/badges/frame_sports.svg',
  ),
  Event(
    id: 'evt-rayados-tigres',
    slug: 'rayados-tigres-clasico-regio-2026',
    title: 'Clásico Regio · Rayados vs Tigres',
    venueName: 'Estadio BBVA',
    city: 'Monterrey',
    countryCode: 'MX',
    startsAt: DateTime(2026, 8, 16, 19, 0),
    description: 'Norte contra norte. Solo norteños lo entienden.',
    category: EventCategory.sports,
    geofencePolygon: _genericPolygon(25.6692, -100.2447),
    posterUrl: 'https://placehold.co/600x800/121212/2DFF95?text=Regio',
    intentCount: 3120,
    badgeFrameUrl: 'assets/badges/frame_sports.svg',
  ),
  Event(
    id: 'evt-boca-river',
    slug: 'boca-river-bombonera-2026',
    title: 'Superclásico · Boca vs River',
    venueName: 'La Bombonera',
    city: 'Buenos Aires',
    countryCode: 'AR',
    startsAt: DateTime(2026, 9, 27, 17, 0),
    description: 'No hay otro como éste. Punto.',
    category: EventCategory.sports,
    geofencePolygon: _genericPolygon(-34.6356, -58.3651),
    posterUrl: 'https://placehold.co/600x800/121212/2DFF95?text=Boca-River',
    intentCount: 8800,
    badgeFrameUrl: 'assets/badges/frame_sports.svg',
  ),

  // === Festivales ======================================================
  Event(
    id: 'evt-corona-capital',
    slug: 'corona-capital-2026',
    title: 'Corona Capital 2026',
    venueName: 'Autódromo Hermanos Rodríguez',
    city: 'Ciudad de México',
    countryCode: 'MX',
    startsAt: DateTime(2026, 11, 14, 13, 0),
    endsAt: DateTime(2026, 11, 16, 23, 30),
    description: 'Tres días. Diez escenarios. Una multitud que solo se '
        'reconoce en noviembre.',
    category: EventCategory.festivals,
    geofencePolygon: _polygonAutodromo,
    dwellMinimumMin: 90,
    posterUrl: 'https://placehold.co/600x800/121212/FF9D2D?text=Corona',
    promoterName: 'OCESA',
    intentCount: 11200,
    badgeFrameUrl: 'assets/badges/frame_festivals.svg',
  ),
  Event(
    id: 'evt-vive-latino',
    slug: 'vive-latino-2026',
    title: 'Vive Latino 2026',
    venueName: 'Foro Sol',
    city: 'Ciudad de México',
    countryCode: 'MX',
    startsAt: DateTime(2026, 3, 14, 13, 0),
    endsAt: DateTime(2026, 3, 15, 23, 30),
    description: 'El gran festival latinoamericano.',
    category: EventCategory.festivals,
    geofencePolygon: _polygonForoSol,
    dwellMinimumMin: 90,
    posterUrl: 'https://placehold.co/600x800/121212/FF9D2D?text=Vive+Latino',
    intentCount: 7430,
    badgeFrameUrl: 'assets/badges/frame_festivals.svg',
  ),
  Event(
    id: 'evt-coordenada',
    slug: 'coordenada-2026',
    title: 'Festival Coordenada',
    venueName: 'Trasloma',
    city: 'Guadalajara',
    countryCode: 'MX',
    startsAt: DateTime(2026, 10, 24, 14, 0),
    endsAt: DateTime(2026, 10, 25, 23, 30),
    description: 'El festival que está convirtiendo Guadalajara en capital.',
    category: EventCategory.festivals,
    geofencePolygon: _genericPolygon(20.6750, -103.4080),
    dwellMinimumMin: 90,
    posterUrl: 'https://placehold.co/600x800/121212/FF9D2D?text=Coordenada',
    intentCount: 2310,
    badgeFrameUrl: 'assets/badges/frame_festivals.svg',
  ),

  // === Outdoor =========================================================
  Event(
    id: 'evt-iztaccihuatl-luna',
    slug: 'iztaccihuatl-luna-llena-2026-jul',
    title: 'Iztaccíhuatl · Luna llena',
    venueName: 'Parque Nacional Izta-Popo',
    city: 'Amecameca',
    countryCode: 'MX',
    startsAt: DateTime(2026, 7, 19, 4, 0),
    description: 'Salida a las 4 am. Cumbre en luna llena. No es turismo.',
    category: EventCategory.outdoor,
    geofencePolygon: _genericPolygon(19.1789, -98.6418, deltaDeg: 0.02),
    dwellMinimumMin: 120,
    posterUrl: 'https://placehold.co/600x800/121212/2DC8FF?text=Izta',
    intentCount: 180,
    badgeFrameUrl: 'assets/badges/frame_outdoor.svg',
  ),
  Event(
    id: 'evt-tepoz-amanecer',
    slug: 'tepozteco-amanecer-2026-may',
    title: 'Tepozteco al amanecer',
    venueName: 'Cerro del Tepozteco',
    city: 'Tepoztlán',
    countryCode: 'MX',
    startsAt: DateTime(2026, 5, 25, 5, 30),
    description: 'Salida pre-amanecer en domingo. Llegamos arriba con sol.',
    category: EventCategory.outdoor,
    geofencePolygon: _genericPolygon(18.9885, -99.1014),
    posterUrl: 'https://placehold.co/600x800/121212/2DC8FF?text=Tepoz',
    intentCount: 92,
    badgeFrameUrl: 'assets/badges/frame_outdoor.svg',
  ),

  // === Cultura =========================================================
  Event(
    id: 'evt-cervantino-2026',
    slug: 'cervantino-2026',
    title: 'Festival Cervantino',
    venueName: 'Centro Histórico',
    city: 'Guanajuato',
    countryCode: 'MX',
    startsAt: DateTime(2026, 10, 9, 18, 0),
    endsAt: DateTime(2026, 10, 25, 23, 0),
    description: 'El festival cultural más grande de Latinoamérica.',
    category: EventCategory.culture,
    geofencePolygon: _genericPolygon(21.0190, -101.2574, deltaDeg: 0.01),
    dwellMinimumMin: 60,
    posterUrl: 'https://placehold.co/600x800/121212/9D2DFF?text=Cervantino',
    intentCount: 1740,
    badgeFrameUrl: 'assets/badges/frame_culture.svg',
  ),
];

// === Polígonos por venue (rectángulos aproximados) ======================

/// Estadio GNP Seguros — CDMX. ~19.4032 N, -99.1755 W.
final List<LatLng> _polygonGNPSeguros = _genericPolygon(19.4032, -99.1755);

/// Estadio Azteca — CDMX. ~19.3029 N, -99.1505 W.
final List<LatLng> _polygonAzteca = _genericPolygon(19.3029, -99.1505);

/// Foro Sol — CDMX. ~19.4044 N, -99.0931 W.
final List<LatLng> _polygonForoSol = _genericPolygon(19.4044, -99.0931);

/// Autódromo Hermanos Rodríguez — CDMX. ~19.4042 N, -99.0907 W.
final List<LatLng> _polygonAutodromo =
    _genericPolygon(19.4042, -99.0907, deltaDeg: 0.005);

List<LatLng> _genericPolygon(double lat, double lng,
    {double deltaDeg = 0.0015}) {
  final d = deltaDeg;
  return [
    LatLng(lat + d, lng - d),
    LatLng(lat + d, lng + d),
    LatLng(lat - d, lng + d),
    LatLng(lat - d, lng - d),
    LatLng(lat + d, lng - d),
  ];
}

/// Lookup table by id.
final Map<String, Event> mockEventsById = {
  for (final e in mockEvents) e.id: e,
};

/// Lookup table by slug.
final Map<String, Event> mockEventsBySlug = {
  for (final e in mockEvents) e.slug: e,
};
