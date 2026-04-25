# smwhr — Technical Architecture & Design

**Versión:** v1.1
**Fecha:** 22 abril 2026
**Scope:** Release 0.1 — Music (lanzamiento 5 mayo 2026)

**Changelog v1.1:**
- Añadida arquitectura dual-track de geolocation (Locus primary + geolocator shadow)
- Reconciliation engine en backend
- Schema actualizado con tablas para shadow tracking
- Pipeline de verificación actualizado con cross-validation
- Dependencias Flutter ajustadas

---

## 1. Stack definitivo

### Mobile
- **Flutter** (stable más reciente, Dart 3.5+)
- **Riverpod** para state management
- **go_router** para navegación declarativa
- **dio** para HTTP con interceptors
- **flutter_secure_storage** para tokens JWT

**Geolocation (dual-track):**
- **locus** `^2.0.0` — tracking primary con polygon geofences, motion recognition, headless execution
- **geolocator** `^12.0.0` — shadow tracking como fallback independiente
- **permission_handler** `^11.0.0` — manejo uniforme de permisos
- **workmanager** `^0.5.2` — background execution adicional para Android

**Captura y media:**
- **native_exif** para metadata de fotos
- **camera** para captura in-app (no galería, fuerza captura en vivo)
- **image_picker** como fallback de emergencia

**Persistencia local:**
- **hive_flutter** `^1.1.0` — SQLite-like local DB para dual-track logging
- **supabase_flutter** para cliente oficial

**Auth y notifications:**
- **firebase_messaging** + **flutter_local_notifications** para push
- **sign_in_with_apple** + **google_sign_in** para OAuth

### Backend
- **NestJS** 10+ con TypeScript strict mode
- **Prisma** como ORM con cliente generado
- **BullMQ** + **Redis** para jobs en background
- **class-validator** + **class-transformer** para DTOs
- **Passport.js** strategies para auth
- **sharp** para composición de imágenes
- **@nestjs/schedule** para cron jobs
- **Swagger/OpenAPI** auto-generado en `/docs`

### Database & Backend-as-Service
- **Supabase** (hosted) para:
    - Postgres 16 managed
    - Auth (Apple, Google, magic link)
    - Storage (fotos de usuarios)
    - Row Level Security (RLS)
    - Realtime (para Release 0.2+)
- **Extensiones Postgres:** PostGIS, uuid-ossp, pg_cron (backup)

### Infraestructura
- **Backend deploy:** Railway
- **Redis:** Upstash (serverless Redis, free tier 10k comandos/día)
- **Storage:** Supabase Storage (S3-compatible) con CDN built-in
- **DNS:** Cloudflare
- **Mobile distribution:** TestFlight + Firebase App Distribution (beta), después App Store + Play Store
- **Monitoring:** Sentry (errors) + PostHog (analytics) + BetterStack (logs + uptime)
- **Push:** OneSignal (gratis hasta 10k usuarios) o FCM directo

### External APIs
- **Ticketmaster Discovery API** — catálogo de eventos
- **Google Play Integrity API** — verificación Android
- **Apple DeviceCheck / App Attest** — verificación iOS
- **Google Vision API** o **AWS Rekognition** — NSFW detection
- **Google Maps Geocoding** o **Mapbox** — autocompletar ciudad

---

## 2. Arquitectura de alto nivel

```
┌─────────────────────────────────────────────────────────┐
│                   Flutter App                           │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │         Dual-Track Quest Tracker                 │   │
│  │                                                  │   │
│  │   ┌──────────┐       ┌──────────────┐            │   │
│  │   │  Locus   │       │  geolocator  │            │   │
│  │   │(primary) │       │  (shadow)    │            │   │
│  │   └────┬─────┘       └──────┬───────┘            │   │
│  │        │                    │                    │   │
│  │        ▼                    ▼                    │   │
│  │   ┌─────────────────────────────────┐            │   │
│  │   │  Hive local DB                  │            │   │
│  │   │  - locus_events                 │            │   │
│  │   │  - geolocator_pings             │            │   │
│  │   └────────────┬────────────────────┘            │   │
│  └────────────────┼─────────────────────────────────┘   │
│                   │                                     │
└───────────────────┼─────────────────────────────────────┘
                    │
                    │ HTTPS (JWT auth, batch upload)
                    ▼
┌─────────────────────────────────────────────────────────┐
│              NestJS API (Railway)                       │
│                                                         │
│  ┌───────────┐ ┌───────────┐ ┌──────────────────┐       │
│  │   Auth    │ │  Events   │ │  Verification    │       │
│  │  Module   │ │  Module   │ │  + Reconciliation│       │
│  └───────────┘ └───────────┘ └──────────────────┘       │
│  ┌───────────┐ ┌───────────┐ ┌──────────────────┐       │
│  │  Uploads  │ │  Badges   │ │  Integrations    │       │
│  │  Module   │ │  Module   │ │  Module          │       │
│  └───────────┘ └───────────┘ └──────────────────┘       │
│                                                         │
│  ┌──────────────────────────────────────────────┐       │
│  │  BullMQ Workers                              │       │
│  │  - reconciliation (new)                      │       │
│  │  - badge-composition                         │       │
│  │  - photo-processing                          │       │
│  │  - quest-emission                            │       │
│  └──────────────────────────────────────────────┘       │
└──────┬───────────────────────┬──────────────────────────┘
       │                       │
       ▼                       ▼
┌─────────────┐         ┌─────────────┐     ┌────────────┐
│  Supabase   │         │    Redis    │     │  External  │
│             │         │  (Upstash)  │     │    APIs    │
│  - Postgres │         │  - BullMQ   │     │            │
│  - Auth     │         │  - Cache    │     │ Ticketmas- │
│  - Storage  │         └─────────────┘     │   ter      │
│  - RLS      │                             │ Integrity  │
└─────────────┘                             │ Vision     │
                                            └────────────┘
```

---

## 3. Arquitectura de Dual-Track Geolocation

Este es el corazón diferenciado de smwhr: **redundancia inteligente** para garantizar que la verificación funcione incluso si una de las dos librerías falla.

### Principio central

**Ambas librerías ejecutan en paralelo durante todo el evento.** Locus opera como fuente primaria de decisiones (gracias a sus features avanzadas), mientras geolocator corre como "shadow track" con heartbeats periódicos independientes. El backend recibe ambos datasets y un `ReconciliationEngine` decide cuál usar como ground truth.

Inspiración: cajas negras duales en aviación.

### Responsabilidades por librería

**Locus (primary):**
- Polygon geofence entry/exit detection
- Motion recognition (walking, running, stationary)
- Headless execution cuando app está killed
- SQLite persistence nativa
- Trip detection
- Privacy zones

**geolocator (shadow):**
- Heartbeat periódico cada 5 min mientras app está activo
- `getCurrentPosition()` simple con accuracy high
- Escribe ping con timestamp independiente
- Cero lógica compleja — es literalmente "dónde estoy ahora"

### Flujo durante el evento

```
┌────────────────────────────────────────────────────────┐
│  T-15min: Push notification "Tu quest arranca pronto"  │
└─────────────────────┬──────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────┐
│  Usuario abre app, el QuestTracker se inicializa:      │
│  1. Locus.startTracking(eventId, polygon)              │
│  2. Geolocator timer periódico cada 5min arranca       │
│  3. Hive local DB preparada con tablas shadow          │
└─────────────────────┬──────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────┐
│  Durante el evento (2-4 horas):                        │
│                                                        │
│  Locus emite eventos:                                  │
│    - ONFENCE_ENTER → guarda en Hive                    │
│    - LOCATION_UPDATE → guarda en Hive                  │
│    - MOTION_CHANGE → guarda en Hive                    │
│    - ONFENCE_EXIT → guarda en Hive                     │
│                                                        │
│  Geolocator dispara timer:                             │
│    - Cada 5 min: getCurrentPosition()                  │
│    - Guarda ping en Hive con timestamp y accuracy      │
│    - Si está dentro del polygon, marca is_inside=true  │
│                                                        │
│  Cada 30 min: batch upload al backend                  │
│    - POST /quests/:id/sync con ambos datasets          │
└─────────────────────┬──────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────┐
│  Evento termina + 1h grace period:                     │
│  1. Cron dispara ReconciliationEngine por cada intent  │
│  2. Engine compara Locus vs geolocator data            │
│  3. Decide qué dataset es truth                        │
│  4. Calcula verification score                         │
│  5. Emite badge si score >= threshold                  │
└────────────────────────────────────────────────────────┘
```

### Estrategias del Reconciliation Engine

```typescript
async function reconcileCheckin(
  userId: string,
  eventId: string
): Promise<ReconciliationResult> {
  const locusData = await getLocusEvents(userId, eventId);
  const geoloData = await getGeolocatorPings(userId, eventId);
  const event = await getEvent(eventId);

  // Estrategia 1: Locus completo y consistente → úsalo
  if (locusData.isComplete && locusData.hasGeofenceEnter && locusData.hasGeofenceExit) {
    return {
      source: 'locus',
      dwellMinutes: locusData.dwellMinutes,
      verificationScore: calculateScore(locusData, event),
      reason: 'locus_primary_complete'
    };
  }

  // Estrategia 2: Locus parcial pero geolocator tiene data suficiente → fallback
  if (geoloData.pingsCount >= MIN_PINGS_FOR_VERIFICATION) {
    const dwellFromGeo = calculateDwellFromPings(geoloData, event.geofencePolygon);

    if (dwellFromGeo >= event.dwellMinimumMin) {
      logSystemEvent('locus_fallback_triggered', { userId, eventId });
      return {
        source: 'geolocator_fallback',
        dwellMinutes: dwellFromGeo,
        verificationScore: calculateScore(geoloData, event) * 0.9, // slight penalty
        reason: 'locus_incomplete_geo_sufficient'
      };
    }
  }

  // Estrategia 3: Ambos tienen data, cross-validar
  if (locusData.hasData && geoloData.hasData) {
    const agreement = calculateAgreement(locusData, geoloData);

    if (agreement > 0.8) {
      return {
        source: 'locus_validated',
        dwellMinutes: locusData.dwellMinutes,
        verificationScore: calculateScore(locusData, event) + CROSS_VALIDATION_BONUS,
        reason: 'high_agreement_cross_validated'
      };
    } else {
      // Divergen, investigar y usar el más conservador
      logSystemEvent('tracking_divergence', { userId, eventId, agreement, locusData, geoloData });
      const conservative = pickMostConservative(locusData, geoloData);
      return {
        source: 'divergence_conservative',
        dwellMinutes: conservative.dwellMinutes,
        verificationScore: calculateScore(conservative, event) * 0.7,
        reason: 'sources_diverged'
      };
    }
  }

  // Estrategia 4: Insuficiente data
  return {
    source: 'none',
    dwellMinutes: 0,
    verificationScore: 0,
    reason: 'insufficient_data'
  };
}
```

### Benefits del dual-track

1. **Risk mitigation:** lanzas con Locus sin apostar la primera producción a una librería nueva
2. **Telemetría comparativa:** datos reales de agreement Locus vs geolocator por device/manufacturer
3. **Anti-fraud:** cross-validation entre fuentes independientes detecta mock GPS manipulations
4. **Migration path:** si futuro compras SDK comercial o construyes propio, la arquitectura ya tolera reemplazar el primary
5. **Graceful degradation:** un usuario con Locus roto aún recibe su badge via shadow track

### Costos del dual-track

1. **Complejidad extra:** +1.5-2 días de implementación en el sprint
2. **Batería:** +2-4% durante tracking activo (geolocator cada 5 min)
3. **Storage local:** ~200KB por evento (vs 100KB single-track)
4. **Bandwidth:** upload duplicado por evento (~50KB extra comprimido)

**Veredicto:** los costos son marginales frente al risk mitigation. Dual-track es la decisión correcta para R0.1.

---

## 4. Estructura de repositorio (monorepo)

```
smwhr/
├── apps/
│   ├── api/                       # Backend NestJS
│   │   ├── src/
│   │   │   ├── main.ts
│   │   │   ├── app.module.ts
│   │   │   ├── config/
│   │   │   ├── common/
│   │   │   ├── modules/
│   │   │   │   ├── auth/
│   │   │   │   ├── users/
│   │   │   │   ├── events/
│   │   │   │   ├── intents/
│   │   │   │   ├── quests/
│   │   │   │   │   ├── dto/
│   │   │   │   │   ├── quests.controller.ts
│   │   │   │   │   ├── quests.service.ts
│   │   │   │   │   ├── tracking.service.ts      # ingesta dual-track
│   │   │   │   │   └── reconciliation.service.ts # engine
│   │   │   │   ├── badges/
│   │   │   │   ├── uploads/
│   │   │   │   ├── integrations/
│   │   │   │   └── notifications/
│   │   │   ├── workers/
│   │   │   │   ├── reconciliation.worker.ts     # new
│   │   │   │   ├── badge-composition.worker.ts
│   │   │   │   └── photo-processing.worker.ts
│   │   │   └── prisma/
│   │   ├── prisma/
│   │   │   ├── schema.prisma
│   │   │   ├── migrations/
│   │   │   └── seed.ts
│   │   ├── test/
│   │   ├── Dockerfile
│   │   └── package.json
│   │
│   ├── mobile/
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── core/
│   │   │   ├── shared/
│   │   │   ├── features/
│   │   │   │   ├── auth/
│   │   │   │   ├── onboarding/
│   │   │   │   ├── events/
│   │   │   │   ├── quest/
│   │   │   │   │   ├── services/
│   │   │   │   │   │   ├── quest_tracker.dart        # orchestrator
│   │   │   │   │   │   ├── locus_tracker.dart        # primary
│   │   │   │   │   │   ├── geolocator_tracker.dart   # shadow
│   │   │   │   │   │   └── tracking_sync.dart        # upload batch
│   │   │   │   │   ├── providers/
│   │   │   │   │   ├── screens/
│   │   │   │   │   └── widgets/
│   │   │   │   ├── camera/
│   │   │   │   ├── badges/
│   │   │   │   ├── profile/
│   │   │   │   └── share/
│   │   │   ├── data/
│   │   │   │   ├── local/
│   │   │   │   │   ├── tracking_db.dart          # Hive local DB
│   │   │   │   │   └── models/
│   │   │   │   └── remote/
│   │   │   └── domain/
│   │   ├── android/
│   │   ├── ios/
│   │   ├── assets/
│   │   └── pubspec.yaml
│   │
│   └── landing/
│
├── packages/
│   ├── shared-types/
│   └── config/
│
├── docs/
│   ├── README.md
│   ├── ARCHITECTURE.md            # este documento
│   ├── ROADMAP.md
│   ├── ONBOARDING_FLOW.md
│   ├── TRACKING.md                # detalle del dual-track (new)
│   └── API.md
│
├── design/
│   └── mocks/v1/
│
├── .github/
│   └── workflows/
│
├── CLAUDE.md
├── package.json
├── pnpm-workspace.yaml
├── .gitignore
├── .env.example
└── README.md
```

---

## 5. Schema de base de datos (Prisma)

```prisma
// prisma/schema.prisma

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider   = "postgresql"
  url        = env("DATABASE_URL")
  extensions = [postgis, uuid_ossp(map: "uuid-ossp")]
}

// ============================================================
// USUARIOS
// ============================================================
model User {
  id                            String    @id @default(uuid()) @db.Uuid
  handle                        String    @unique @db.VarChar(20)
  displayName                   String    @db.VarChar(40)
  email                         String    @unique
  avatarUrl                     String?
  bio                           String?   @db.VarChar(140)
  city                          String?
  countryCode                   String    @default("MX") @db.VarChar(2)
  interests                     String[]

  authProvider                  String
  authProviderId                String?
  supabaseUserId                String?   @unique @db.Uuid

  timezone                      String    @default("America/Mexico_City")
  language                      String    @default("es") @db.VarChar(2)

  pushToken                     String?
  pushPlatform                  String?
  notificationPromptShownAt     DateTime?

  onboardingCompletedAt         DateTime?

  createdAt                     DateTime  @default(now())
  lastActiveAt                  DateTime  @default(now())
  updatedAt                     DateTime  @updatedAt

  intents                       Intent[]
  checkins                      Checkin[]
  badges                        Badge[]
  photos                        Photo[]
  locusEvents                   LocusEvent[]
  geolocatorPings               GeolocatorPing[]

  @@index([email])
  @@index([handle])
  @@index([city])
  @@map("users")
}

// ============================================================
// EVENTOS
// ============================================================
model Event {
  id                String    @id @default(uuid()) @db.Uuid
  slug              String    @unique @db.VarChar(100)

  title             String
  artist            String?
  venueName         String
  venueAddress      String?
  city              String
  countryCode       String    @default("MX") @db.VarChar(2)

  category          String
  subcategory       String?

  startsAt          DateTime
  endsAt            DateTime
  dwellMinimumMin   Int       @default(60)

  geofencePolygon   Unsupported("geography(Polygon, 4326)")
  geofenceCenter    Unsupported("geography(Point, 4326)")
  geofenceRadiusM   Int?

  externalSource    String?
  externalId        String?
  externalUrl       String?

  heroImageUrl      String?
  heroColor         String?   @db.VarChar(7)

  badgeTemplateId   String?   @db.Uuid
  badgeTemplate     BadgeTemplate? @relation(fields: [badgeTemplateId], references: [id])

  intentCount       Int       @default(0)
  badgeCount        Int       @default(0)
  totalCapacity     Int?

  status            String    @default("scheduled")
  isFeatured        Boolean   @default(false)

  createdAt         DateTime  @default(now())
  updatedAt         DateTime  @updatedAt

  intents           Intent[]
  checkins          Checkin[]
  badges            Badge[]
  locusEvents       LocusEvent[]
  geolocatorPings   GeolocatorPing[]

  @@index([category, startsAt])
  @@index([city, startsAt])
  @@index([status, startsAt])
  @@index([isFeatured, startsAt])
  @@map("events")
}

// ============================================================
// INTENTS
// ============================================================
model Intent {
  id        String    @id @default(uuid()) @db.Uuid
  userId    String    @db.Uuid
  eventId   String    @db.Uuid
  createdAt DateTime  @default(now())

  user      User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  event     Event     @relation(fields: [eventId], references: [id], onDelete: Cascade)

  @@unique([userId, eventId])
  @@index([eventId])
  @@map("intents")
}

// ============================================================
// LOCUS EVENTS (primary track)
// ============================================================
model LocusEvent {
  id                String    @id @default(uuid()) @db.Uuid
  userId            String    @db.Uuid
  eventId           String    @db.Uuid

  // Event type from Locus
  eventType         String    // 'geofence_enter' | 'geofence_exit' | 'location_update' | 'motion_change' | 'trip_start' | 'trip_end'

  // Location data
  latitude          Float
  longitude         Float
  accuracy          Float?
  altitude          Float?
  speed             Float?
  heading           Float?

  // Context
  activity          String?   // 'still' | 'walking' | 'running' | 'driving' | 'unknown'
  confidence        Float?    // motion confidence 0-1

  // Timing
  timestamp         DateTime  // device timestamp
  receivedAt        DateTime  @default(now())

  // Metadata
  isInsidePolygon   Boolean   @default(false)
  rawPayload        Json?     // full Locus payload for debugging

  user              User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  event             Event     @relation(fields: [eventId], references: [id], onDelete: Cascade)

  @@index([userId, eventId, timestamp])
  @@index([eventId, eventType])
  @@map("locus_events")
}

// ============================================================
// GEOLOCATOR PINGS (shadow track)
// ============================================================
model GeolocatorPing {
  id                String    @id @default(uuid()) @db.Uuid
  userId            String    @db.Uuid
  eventId           String    @db.Uuid

  latitude          Float
  longitude         Float
  accuracy          Float?
  altitude          Float?

  timestamp         DateTime  // device timestamp
  receivedAt        DateTime  @default(now())

  isInsidePolygon   Boolean   @default(false)
  batteryLevel      Int?      // 0-100, si el device lo reporta

  user              User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  event             Event     @relation(fields: [eventId], references: [id], onDelete: Cascade)

  @@index([userId, eventId, timestamp])
  @@map("geolocator_pings")
}

// ============================================================
// CHECKINS (resultado post-reconciliation)
// ============================================================
model Checkin {
  id                      String    @id @default(uuid()) @db.Uuid
  userId                  String    @db.Uuid
  eventId                 String    @db.Uuid

  // Reconciliation results
  primarySource           String    // 'locus' | 'geolocator_fallback' | 'locus_validated' | 'divergence_conservative' | 'none'
  reconciliationReason    String?   // texto explicativo
  agreementScore          Float?    // 0-1, qué tan coincidentes son Locus y geolocator
  reconciledAt            DateTime?

  // Aggregated tracking results
  dwellMinutes            Int       @default(0)
  firstPointAt            DateTime?
  lastPointAt             DateTime?
  totalPointsCollected    Int       @default(0)  // count across both sources
  locusEventsCount        Int       @default(0)
  geolocatorPingsCount    Int       @default(0)

  // Integrity
  integrityToken          String?   @db.Text
  integrityVerdict        String?
  integrityPlatform       String?
  integrityCheckedAt      DateTime?

  // Device info
  deviceId                String?
  deviceModel             String?
  appVersion              String?

  // Photo (optional)
  photoId                 String?   @unique @db.Uuid
  photo                   Photo?    @relation(fields: [photoId], references: [id])

  // Scoring
  verificationScore       Int       @default(0)
  isVerified              Boolean   @default(false)
  verificationReason      String?

  createdAt               DateTime  @default(now())
  updatedAt               DateTime  @updatedAt

  user                    User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  event                   Event     @relation(fields: [eventId], references: [id], onDelete: Cascade)

  @@unique([userId, eventId])
  @@index([eventId, isVerified])
  @@index([primarySource])
  @@map("checkins")
}

// ============================================================
// PHOTOS
// ============================================================
model Photo {
  id                String    @id @default(uuid()) @db.Uuid
  userId            String    @db.Uuid

  storagePath       String
  publicUrl         String?

  exifTimestamp     DateTime?
  exifLatitude      Float?
  exifLongitude     Float?
  exifRaw           Json?

  isExifValid       Boolean   @default(false)
  isInsideGeofence  Boolean   @default(false)
  isWithinTimeWindow Boolean  @default(false)

  nsfwScore         Float?
  nsfwFlagged       Boolean   @default(false)

  processingStatus  String    @default("pending")

  createdAt         DateTime  @default(now())
  updatedAt         DateTime  @updatedAt

  user              User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  checkin           Checkin?

  @@index([userId])
  @@map("photos")
}

// ============================================================
// BADGE TEMPLATES
// ============================================================
model BadgeTemplate {
  id              String    @id @default(uuid()) @db.Uuid
  name            String
  category        String
  variant         String?

  frameSvgUrl     String
  accentColor     String    @db.VarChar(7)
  ambientColor    String?   @db.VarChar(7)
  textureUrl      String?

  config          Json

  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt

  events          Event[]
  badges          Badge[]

  @@map("badge_templates")
}

// ============================================================
// BADGES
// ============================================================
model Badge {
  id                  String    @id @default(uuid()) @db.Uuid
  userId              String    @db.Uuid
  eventId             String    @db.Uuid
  templateId          String    @db.Uuid

  serialNumber        Int
  totalForEvent       Int

  composedImageUrl    String?
  shareImageUrl       String?

  verificationScore   Int       @default(0)
  isVerified          Boolean   @default(false)
  awardedAt           DateTime  @default(now())

  createdAt           DateTime  @default(now())
  updatedAt           DateTime  @updatedAt

  user                User            @relation(fields: [userId], references: [id], onDelete: Cascade)
  event               Event           @relation(fields: [eventId], references: [id], onDelete: Cascade)
  template            BadgeTemplate   @relation(fields: [templateId], references: [id])

  @@unique([userId, eventId])
  @@index([eventId, serialNumber])
  @@index([userId, awardedAt])
  @@map("badges")
}

// ============================================================
// AUDITORÍA
// ============================================================
model SystemEvent {
  id          String    @id @default(uuid()) @db.Uuid
  type        String
  userId      String?   @db.Uuid
  eventId     String?   @db.Uuid
  metadata    Json?
  createdAt   DateTime  @default(now())

  @@index([type, createdAt])
  @@index([userId, createdAt])
  @@map("system_events")
}
```

### Row Level Security (Supabase policies)

```sql
-- Usuarios solo ven sus propios registros
CREATE POLICY "users_select_own" ON users
  FOR SELECT USING (auth.uid() = supabase_user_id);

CREATE POLICY "users_update_own" ON users
  FOR UPDATE USING (auth.uid() = supabase_user_id);

CREATE POLICY "users_public_profile" ON users
  FOR SELECT USING (true);

-- Events públicos
CREATE POLICY "events_public_read" ON events
  FOR SELECT USING (true);

-- Intents propios
CREATE POLICY "intents_own" ON intents
  FOR ALL USING (auth.uid() IN (
    SELECT supabase_user_id FROM users WHERE id = intents.user_id
  ));

-- Checkins propios
CREATE POLICY "checkins_own" ON checkins
  FOR ALL USING (auth.uid() IN (
    SELECT supabase_user_id FROM users WHERE id = checkins.user_id
  ));

-- Locus events propios
CREATE POLICY "locus_events_own" ON locus_events
  FOR ALL USING (auth.uid() IN (
    SELECT supabase_user_id FROM users WHERE id = locus_events.user_id
  ));

-- Geolocator pings propios
CREATE POLICY "geolocator_pings_own" ON geolocator_pings
  FOR ALL USING (auth.uid() IN (
    SELECT supabase_user_id FROM users WHERE id = geolocator_pings.user_id
  ));

-- Badges públicos para perfiles compartibles
CREATE POLICY "badges_public_read" ON badges
  FOR SELECT USING (true);

-- Photos privadas
CREATE POLICY "photos_own" ON photos
  FOR ALL USING (auth.uid() IN (
    SELECT supabase_user_id FROM users WHERE id = photos.user_id
  ));
```

---

## 6. Endpoints API

### Auth
```
POST   /auth/apple              Body: { identityToken, authorizationCode }
POST   /auth/google             Body: { idToken }
POST   /auth/email/request      Body: { email }
POST   /auth/email/verify       Body: { token }
POST   /auth/refresh            Body: { refreshToken }
POST   /auth/logout
```

### Users
```
GET    /me
PATCH  /me
POST   /me/onboarding           Body: { handle, displayName, city, interests }
POST   /me/push-token           Body: { token, platform }
GET    /users/:handle
GET    /users/:handle/badges
GET    /users/check-handle/:h
```

### Events
```
GET    /events                  Query: ?city=&category=&from=&to=&featured=
GET    /events/:slug
POST   /events/:id/intent
DELETE /events/:id/intent
GET    /events/:id/intents
```

### Quest / Tracking (dual-track)
```
POST   /quests/:eventId/sync
  Body: {
    locusEvents: LocusEventBatch[],
    geolocatorPings: GeolocatorPingBatch[],
    clientTimestamp: ISO8601,
    deviceInfo: { id, model, os, appVersion }
  }
  → guarda ambos datasets, retorna confirmación

POST   /quests/:eventId/integrity
  Body: { token, platform }

POST   /quests/:eventId/photo
  multipart: foto + EXIF

GET    /quests/:eventId/status
  → retorna estado actual del quest con info de ambas fuentes
```

### Badges
```
GET    /me/badges
GET    /badges/:id
GET    /badges/:id/share
```

### Integrations (internas)
```
POST   /webhooks/ticketmaster
```

---

## 7. Jobs y workflows de background

### BullMQ queues

```typescript
- 'reconciliation'       // NEW: reconcilia dual-track al cerrar evento
- 'quest-emission'       // emitir badges verificadas
- 'photo-processing'     // validar EXIF, NSFW check
- 'badge-composition'    // generar imagen compositada
- 'event-sync'           // polling Ticketmaster
- 'push-notifications'   // delivery
- 'stats-aggregation'    // counts cached
```

### Cron schedules

```typescript
// Cada 5 minutos
@Cron('*/5 * * * *')
syncTicketmasterEvents()

// Cada 30 minutos: detectar eventos que terminaron
@Cron('*/30 * * * *')
closeEndedEvents()  // dispara reconciliation + emission

// Cada hora
@Cron('0 * * * *')
cleanupAndAggregate()

// Diario 3AM
@Cron('0 3 * * *')
dailyStatsRefresh()
```

### Pipeline de emisión de badge actualizado

```
Evento termina (startsAt + duration + 1h grace)
        ↓
Cron "closeEndedEvents" lo detecta
        ↓
Encola job "reconciliation" por cada intent del evento
        ↓
Worker "reconciliation" procesa:
  1. Fetch locusEvents del usuario para ese evento
  2. Fetch geolocatorPings del usuario para ese evento
  3. Ejecuta ReconciliationEngine:
     - Evalúa estrategias 1-4
     - Determina primarySource
     - Calcula dwellMinutes reconciliado
     - Calcula agreementScore
  4. Upsert Checkin con resultados
  5. Si verificationScore >= threshold, encola "badge-composition"
        ↓
Worker "badge-composition":
  1. Fetch checkin + photo (si existe)
  2. Descargar frame SVG del template
  3. Si hay foto: composite con sharp (frame + photo + texto)
  4. Si no hay foto: usar fondo ambient default
  5. Generar dos versiones (display + share)
  6. Upload a Supabase Storage
  7. Insertar Badge en DB
  8. Encolar push notification
        ↓
Usuario recibe push → reveal screen → share
```

---

## 8. Algoritmo de verificación actualizado

### Captura durante evento (dual-track)

**Locus eventos (primary):**
```typescript
// Flutter envía batch cada 30 min o al finalizar tracking
POST /quests/:eventId/sync
{
  locusEvents: [
    {
      eventType: 'geofence_enter',
      lat: 19.3028, lng: -99.1520,
      accuracy: 8.5,
      activity: 'walking',
      timestamp: '2026-05-07T20:14:00Z'
    },
    {
      eventType: 'location_update',
      lat: 19.3029, lng: -99.1519,
      accuracy: 7.2,
      activity: 'still',
      timestamp: '2026-05-07T20:19:00Z'
    },
    // ...
  ],
  geolocatorPings: [
    {
      lat: 19.3028, lng: -99.1520,
      accuracy: 10.3,
      timestamp: '2026-05-07T20:15:00Z'
    },
    {
      lat: 19.3029, lng: -99.1519,
      accuracy: 9.1,
      timestamp: '2026-05-07T20:20:00Z'
    },
    // ...
  ],
  clientTimestamp: '2026-05-07T22:30:00Z',
  deviceInfo: { ... }
}
```

**Backend procesa:**
1. Valida intent existe
2. Inserta registros en `locus_events` y `geolocator_pings`
3. Para cada punto, calcula `isInsidePolygon` via PostGIS
4. Retorna confirmación con count de registros guardados

### Score de verificación (post-reconciliation)

```typescript
function calculateVerificationScore(
  checkin: Checkin,
  event: Event
): number {
  let score = 0;

  // Dwell time (35 pts max)
  const dwellRatio = Math.min(checkin.dwellMinutes / event.dwellMinimumMin, 1);
  score += dwellRatio * 35;

  // Tracking quality (25 pts max)
  const totalPoints = checkin.locusEventsCount + checkin.geolocatorPingsCount;
  score += Math.min(totalPoints / 20, 1) * 25;

  // Cross-validation bonus (10 pts max)
  if (checkin.agreementScore !== null) {
    if (checkin.agreementScore > 0.8) score += 10;
    else if (checkin.agreementScore > 0.6) score += 5;
  }

  // Device integrity (15 pts max)
  if (checkin.integrityVerdict === 'trusted') score += 15;
  else if (checkin.integrityVerdict === 'suspicious') score += 3;

  // Photo con EXIF válido (15 pts max, opcional)
  if (checkin.photo) {
    if (checkin.photo.isExifValid) score += 7;
    if (checkin.photo.isInsideGeofence) score += 4;
    if (checkin.photo.isWithinTimeWindow) score += 4;
  }

  // Penalización por divergencia
  if (checkin.primarySource === 'divergence_conservative') {
    score *= 0.7;
  }

  return Math.round(score);
}

// Umbrales:
// score >= 60 → VERIFIED
// score 30-59 → PARTICIPATED
// score < 30 → NO BADGE
```

---

## 9. Composición de imagen de insignia

Sin cambios respecto a v1.0. Sharp en Node compone frame SVG + foto del usuario + texto con metadata del evento.

---

## 10. Variables de entorno

```bash
# App
NODE_ENV=development
PORT=3000
API_URL=http://localhost:3000
WEB_URL=http://localhost:3001

# Database (Supabase)
DATABASE_URL=postgresql://...
DIRECT_URL=postgresql://...

# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_ROLE_KEY=xxx

# JWT
JWT_SECRET=xxx
JWT_EXPIRES_IN=7d
REFRESH_TOKEN_EXPIRES_IN=90d

# Redis (Upstash)
REDIS_URL=redis://...
REDIS_TOKEN=xxx

# Apple Sign-In
APPLE_TEAM_ID=xxx
APPLE_KEY_ID=xxx
APPLE_PRIVATE_KEY=xxx
APPLE_CLIENT_ID=quest.smwhr.app

# Google Sign-In
GOOGLE_CLIENT_ID_IOS=xxx.apps.googleusercontent.com
GOOGLE_CLIENT_ID_ANDROID=xxx.apps.googleusercontent.com
GOOGLE_CLIENT_ID_WEB=xxx.apps.googleusercontent.com

# Email (Resend)
RESEND_API_KEY=xxx
EMAIL_FROM=hi@smwhr.quest

# Ticketmaster
TICKETMASTER_API_KEY=xxx

# Integrity
GOOGLE_PLAY_INTEGRITY_KEY=xxx
APPLE_APP_ATTEST_TEAM_ID=xxx

# NSFW Detection
GOOGLE_VISION_API_KEY=xxx

# Push (OneSignal)
ONESIGNAL_APP_ID=xxx
ONESIGNAL_API_KEY=xxx

# Monitoring
SENTRY_DSN=xxx
POSTHOG_KEY=xxx

# Reconciliation (new)
RECONCILIATION_AGREEMENT_THRESHOLD=0.8
RECONCILIATION_MIN_PINGS=5
VERIFICATION_SCORE_THRESHOLD=60
```

---

## 11. Plan de ejecución técnica (7 días de hackatón)

### Día 1 (miércoles 22 abril) — Setup total
- [ ] Monorepo init con pnpm workspaces
- [ ] Supabase project creado, PostGIS habilitado
- [ ] Railway project conectado a GitHub
- [ ] Upstash Redis creado
- [ ] API keys generadas: Ticketmaster, Apple, Google, Resend, OneSignal
- [ ] NestJS scaffolded con estructura modular
- [ ] Flutter project creado con dependencies base incluyendo **locus + geolocator + hive**
- [ ] Prisma schema inicial con migration 001 (incluyendo locus_events + geolocator_pings)
- [ ] CLAUDE.md raíz y sub-CLAUDE.md por app
- [ ] Primer deploy a Railway con health check

### Día 2 (jueves 23) — Auth + Users
- [ ] Backend: módulo auth con strategies Apple/Google/email
- [ ] Backend: endpoint POST /me/onboarding
- [ ] Backend: validación de handle
- [ ] Mobile: pantalla 01 Splash/Auth funcional
- [ ] Mobile: pantalla 02 Identity
- [ ] Tests de auth end-to-end

### Día 3 (viernes 24) — Events + Intents
- [ ] Backend: integración Ticketmaster Discovery
- [ ] Backend: cron de sync cada 5 min
- [ ] Backend: endpoints GET /events, GET /events/:slug
- [ ] Backend: POST /events/:id/intent
- [ ] Mobile: pantalla 03 Interests
- [ ] Mobile: pantalla 04 Permissions
- [ ] Mobile: pantalla 05 Home feed
- [ ] Mobile: pantalla 06 Event detail

### Día 4 (sábado 25) — LOCUS PRIMARY TRACKING
- [ ] Mobile: integración Locus + configuración de polygon geofences
- [ ] Mobile: LocusTracker service que registra eventos en Hive local
- [ ] Mobile: Quest lifecycle (start/stop/pause)
- [ ] Backend: endpoint POST /quests/:id/sync
- [ ] Backend: ingesta de locus_events con validación PostGIS
- [ ] Backend: endpoint POST /quests/:id/integrity
- [ ] Mobile: pantalla 07 Active Quest con timer y status checks
- [ ] Test end-to-end: simular quest desde phone hasta DB

### Día 5 (domingo 26) — SHADOW TRACKING + RECONCILIATION
- [ ] Mobile: GeolocatorTracker service (shadow, timer cada 5 min)
- [ ] Mobile: integración con Hive para shadow logs
- [ ] Mobile: sync batch que sube ambos datasets
- [ ] Backend: ingesta de geolocator_pings
- [ ] Backend: ReconciliationEngine con las 4 estrategias
- [ ] Backend: worker BullMQ para reconciliation
- [ ] Backend: cron de cierre de eventos + dispatch a reconciliation
- [ ] Tests unitarios del ReconciliationEngine

### Día 6 (lunes 27) — CAMERA + BADGES + E2E
- [ ] Backend: upload de foto con validación EXIF
- [ ] Backend: NSFW check con Vision API
- [ ] Backend: composición de imagen con Sharp
- [ ] Backend: worker badge-composition
- [ ] Backend: push notification al emitir badge
- [ ] Mobile: pantalla 08 Camera con preview de frame
- [ ] Mobile: pantalla 09 Reveal con animación
- [ ] Mobile: pantalla 10 Profile + Collection
- [ ] Mobile: pantalla 11 Share
- [ ] E2E test completo con 3-5 amigos

### Día 7 (martes 28) — QA + Deploy + Soft launch
- [ ] Bug fixes críticos
- [ ] Build producción iOS → TestFlight
- [ ] Build producción Android → Firebase App Distribution
- [ ] Landing page live con waitlist
- [ ] PostHog eventos tracked
- [ ] Beta testers onboarded (30 personas)
- [ ] Documentación de issues conocidos

---

## 12. Gates de decisión técnica

### Gate 1 — Final Día 5 (26 abril)
**Pregunta:** ¿El dual-track tracking funciona end-to-end con reconciliation?
**Test:** un tester simula quest, ambos datasets se capturan, reconciliation engine produce un checkin correcto.
**Si NO:** evaluar si usar solo Locus o solo geolocator sacrificando resilience.
**Si SÍ:** avanzar a cámara y badges.

### Gate 2 — Final Día 6 (27 abril)
**Pregunta:** ¿Podemos hacer el flow completo en device real sin bugs críticos?
**Si NO:** considerar retrasar lanzamiento al 12 mayo.
**Si SÍ:** submit a App Store.

### Gate 3 — 4 mayo (soft launch)
**Pregunta:** ¿50+ descargas orgánicas y app estable?

### Gate 4 — 11 mayo (post-BTS)
**Pregunta:** ¿100+ badges emitidas? ¿Agreement score promedio Locus vs geolocator?

**Métrica adicional crítica post-BTS:**
- Si Locus primary produce >95% de emisiones sin necesitar fallback → simplificar para R0.2
- Si fallback se disparó >10% de las veces → mantener dual-track e investigar
- Si divergencia ocurrió >5% → issue crítico a debuggear antes de R0.2

---

## 13. Qué NO está en scope de R0.1

- ❌ Social layer
- ❌ Comentarios en badges
- ❌ Mesh networking
- ❌ Cashless integration
- ❌ Dashboard para promotores
- ❌ Premium tier
- ❌ Audio fingerprinting
- ❌ Export de badges
- ❌ Import de historial
- ❌ Beacons físicos
- ❌ Apple Music / YouTube Music integration
- ❌ Optimización agresiva de batería del dual-track (se hace en R0.2 con data real)
- ❌ Machine learning para detectar fraud patterns entre Locus y geolocator

---

*Documento canónico de arquitectura técnica de smwhr Release 0.1. Versión v1.1 con dual-track geolocation. Cualquier decisión técnica debe alinearse con lo aquí definido.*
