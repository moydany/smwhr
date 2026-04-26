# R0.1 Backend — Phase 2 handoff

> Self-contained context dump so a fresh Claude/dev session can pick up
> where this one left off without re-reading every commit.

**Status:** Phase 2 backend complete through soft launch readiness as of
2026-04-25. 9 sequential commits on `main` from empty `apps/api/` to a
deployable NestJS API serving the entire R0.1 mobile contract, plus
PostGIS geofence verification, audit logging, and a notification stub
ready for the FCM/APNs swap.

**Mobile cutover landed the same day.** The Flutter app's 5
`Real*Repository` impls are wired against this backend (commits
5608e2b → 8a4f8c7). The contract was verified live through email-OTP
signup, onboarding, browse, intent toggle, profile, and waitlist. The
active-quest pipeline (`/quests/:id/sync`, `/photo`, `/integrity`,
`/finalize`, `/status`) is shipped on the backend; the mobile-side
tracker + camera + EXIF + permission flow is sequenced in
[2026-04-25-mobile-quest-active.md](./2026-04-25-mobile-quest-active.md).

---

## TL;DR

- **Stack:** NestJS 11 + Prisma 6 + Postgres (Supabase, PostGIS +
  uuid-ossp) + Supabase Auth (JWT) + Supabase Storage + `@nestjs/schedule`
  cron + `@nestjs/throttler` rate limit + helmet. Pinned in
  `apps/api/package.json`.
- **Strategy:** sync-only for R0.1. No BullMQ / Upstash; reconciliation
  runs on a 5-minute cron and badge composition is deferred to the
  mobile (the existing `BadgeFrameOverlay` widget in
  `apps/mobile/lib/features/camera/widgets/`).
- **Tests:** 26/26 across 3 suites
  (`handle.validator.spec`, `verification.service.spec`,
  `reconciliation.service.spec`).
- **Smoke:** end-to-end against real Supabase auth + Postgres + Storage
  on every commit. Last run produced a verified Badge with score 84/100,
  serial 1/1, idempotent on re-finalize.

---

## What got shipped (9 commits)

| Commit | Title | Highlights |
|--------|-------|------------|
| `c4449c7` | session 1 — bootstrap | NestJS scaffold, ConfigModule with Joi env validation, PrismaService, `GET /health`, Swagger at `/docs`, first migration creating 11 tables |
| `70f1022` | session 2 — auth + users | SupabaseService (admin + anon), `JwtAuthGuard` as APP_GUARD, `@Public()`, `@CurrentUser()`, `/auth/{email/request,email/verify,refresh,logout,apple,google}`, `/me`, `/me/onboarding`, `/users/:handle`, `/users/check-handle/:handle`, handle validator with reserved set, ApiException + global filter |
| `4f8d96c` | session 3 — events + intents + waitlist + seed | `add_event_description` migration; `GET /events` (filters: category, city, featured, from, to, limit, offset; featured-first then startsAt asc); `GET /events/:slug`; intents under `/events/:id/intent` (toggle + count, atomic in tx); public `POST /waitlist`; idempotent seed (5 templates, 9 demo users, 15 future events, 7 past events for badges, 4 intents, 7 historic badges) aligned with `apps/mobile/lib/data/mock` |
| `6fd6516` | session 4 — quests | StorageService (Supabase Storage; photos bucket private, badges + avatars public); `GET /quests/:eventId/status`; `POST /quests/:eventId/sync` (batch ingest, max 5000 each, INTENT_REQUIRED guard); `POST /quests/:eventId/integrity` (App Attest / Play Integrity token); `POST /quests/:eventId/photo` (multipart, 12MB cap, mime allowlist, EXIF metadata, isExifValid + isWithinTimeWindow ±30min) |
| `2f456b1` | session 5 — reconciliation, scoring, badges, cron | VerificationService (pure scoring 0-100 with bucket breakdown); ReconciliationService (5 strategies: cross_validated, divergence_conservative, locus_complete, locus_partial, geolocator_fallback, insufficient); CheckinFinalizerService (orchestrates + mints serial-numbered Badge); `POST /quests/:eventId/finalize` (manual trigger); `CloseEndedEventsCron` every 5 min for events that ended ≥1h ago; `GET /me/badges`, `GET /badges/:id`, `GET /badges/:id/share` |
| `4867d9d` | session 6 — hardening + deploy | helmet (HSTS, X-Frame, X-Content-Type-Options); ThrottlerModule (20/s short + 300/min long, APP_GUARD); CORS allowlist (smwhr.dev, smwhr.quest, *.vercel.app, localhost); Dockerfile (multi-stage, pnpm 10.31, Node 20-bookworm-slim) + .dockerignore; railway.json with `/health` healthcheck; `start:prod` runs `prisma migrate deploy` first |
| `34a1d42` | (chore) | Adds `*.ngrok-free.app` + `*.ngrok.app` to CORS allowlist for tunnelled local dev |
| `fe304f0` | session 7 — PostGIS geofence | Moves `postgis` extension to `extensions` schema; `add_event_geofence` migration adds `geofence_polygon geography(Polygon, 4326)` + `geofence_center geography(Point, 4326)` + GiST indexes; `Unsupported(...)` declarations in schema.prisma; GeoService (bulk `applyGeofenceTo` via `ST_Contains`, single-point `pointIsInside`, polygon writer for seed); QuestsService.sync recomputes per-point isInsidePolygon, uploadPhoto computes photo isInsideGeofence; seed sets polygons for all 22 events from a 12-venue VENUES table; smoke verified inside/outside flagged correctly |
| `ef4978f` | session 8 — audit logging | AuditModule (Global) + AuditService.record() — single, never-throws append into system_events; 12 typed event names hooked in: USER_AUTO_CREATED, ONBOARDING_COMPLETED, INTENT_SET, INTENT_CLEARED, QUEST_SYNC, INTEGRITY_ATTESTED, PHOTO_UPLOADED, CHECKIN_FINALIZED, BADGE_ISSUED, WAITLIST_SIGNUP, AUTH_OTP_REQUESTED, AUTH_OTP_VERIFIED |
| `e9ba1cc` | session 9 — notification stub | NotificationModule (Global) + NotificationService with notifyBadgeIssued + notifyEventStartingSoon. Looks up user's pushToken/pushPlatform, formats payload, logs the dispatch. Real FCM/APNs lands by replacing the body of `dispatch()` only — interface stable. Wired from CheckinFinalizerService when a Badge is minted |

---

## Endpoints surface

Every endpoint emits the shared error envelope `{statusCode, error,
code, message, timestamp, path}`. Bearer auth required unless tagged
`Public`.

| Module | Method | Path | Notes |
|---|---|---|---|
| auth | POST | `/auth/email/request` | Public. Sends Supabase OTP |
| auth | POST | `/auth/email/verify` | Public. Returns AuthSession |
| auth | POST | `/auth/refresh` | Public |
| auth | POST | `/auth/logout` | Public, 204 |
| auth | POST | `/auth/apple` | 501 AUTH_PROVIDER_NOT_CONFIGURED |
| auth | POST | `/auth/google` | 501 AUTH_PROVIDER_NOT_CONFIGURED |
| users | GET | `/me` | Auto-creates User row on first hit |
| users | PATCH | `/me` | partial: displayName, bio, city, interests, push |
| users | POST | `/me/onboarding` | INVALID_HANDLE 400, HANDLE_TAKEN 409 |
| users | GET | `/users/check-handle/:handle` | `{available, reason?}` |
| users | GET | `/users/:handle` | public profile by handle |
| users | GET | `/users/:handle/badges` | collection by handle |
| events | GET | `/events` | filters + pagination |
| events | GET | `/events/:slug` | with badgeTemplate |
| events | GET | `/events/:id/intent` | `{has, intent}` |
| events | POST | `/events/:id/intent` | INTENT_EXISTS 409 |
| events | DELETE | `/events/:id/intent` | 204 |
| events | GET | `/events/:id/intents` | list of attendees with intent |
| quests | GET | `/quests/:eventId/status` | quest state + checkin |
| quests | POST | `/quests/:eventId/sync` | batch dual-track ingest |
| quests | POST | `/quests/:eventId/integrity` | attestation token |
| quests | POST | `/quests/:eventId/photo` | multipart, 12MB cap |
| quests | POST | `/quests/:eventId/finalize` | dev-only force reconciliation |
| badges | GET | `/me/badges` | own collection |
| badges | GET | `/badges/:id` | detail |
| badges | GET | `/badges/:id/share` | shareImageUrl + shareText + deepLink |
| waitlist | POST | `/waitlist` | Public; duplicate email idempotent |
| health | GET | `/health` | Public; status + db ping |
| docs | GET | `/docs` | Swagger UI |

---

## Architecture

### Auth flow

1. Mobile (or anything) calls `POST /auth/email/request` with `{email}`
2. Backend invokes `supabase.auth.signInWithOtp` → user receives an
   email with a 6-digit OTP
3. Mobile calls `POST /auth/email/verify` with `{email, token}` →
   backend invokes `supabase.auth.verifyOtp` → returns
   `{accessToken, refreshToken, expiresAt, supabaseUserId, email}`
4. Subsequent calls send `Authorization: Bearer <accessToken>`
5. `JwtAuthGuard` (registered as APP_GUARD with `@Public()` opt-out)
   verifies the token via `supabase.auth.getUser(jwt)` and ensures a
   `users` row exists for that `supabaseUserId`. Auto-creates a stub
   row with `handle = pending_<8>` on first hit
6. `@CurrentUser()` decorator pulls the resolved User row out of `req`

### Reconciliation engine (apps/api/src/quests/services)

Pure-logic services, fully unit-tested:

`ReconciliationService.reconcile({locusEvents, geolocatorPings})` →
`{primarySource, reason, dwellMinutes, firstPointAt, lastPointAt,
totalPoints, agreementScore, locusComplete, geolocatorSufficient}`.

Strategy selection:
1. **cross_validated** — locus has `GEOFENCE_ENTER` + `GEOFENCE_EXIT`,
   geolocator has ≥3 pings, agreement >0.8 → use locus dwell, +bonus
2. **divergence_conservative** — same conditions but agreement ≤0.6 →
   take min(locusDwell, geoDwell), apply 0.7× score penalty
3. **locus_complete** — enter+exit, no/sparse geolocator → use locus
4. **locus_partial** — locus has points but missing enter/exit pair,
   geolocator confirms → use max(locus, geolocator)
5. **geolocator_fallback** — locus missing or sparse → use geolocator
6. **insufficient** — neither side has enough data

`VerificationService.score({...})` returns
`{total, isVerified, parts: {dwell, tracking, crossValidation,
integrity, photo, penaltyMultiplier}}`. Buckets:
- dwell: `(dwellMinutes / dwellMinimumMin) × 35`, max 35
- tracking: `(totalPoints / 20) × 25`, max 25
- crossValidation: agreement >0.8 → 10, >0.6 → 5, else 0
- integrity: trusted → 15, pending_verification → 3, else 0
- photo: exifValid +7, insideGeofence +4, withinTimeWindow +4 (max 15)
- penalty: `divergence_conservative` → ×0.7
- threshold: ≥60 → `isVerified` and Badge minted

`CheckinFinalizerService.finalize(userId, eventId)` orchestrates: load
points → reconcile → score → upsert Checkin → mint Badge if verified.
Idempotent (same badgeId on re-run; serial = max+1 per event,
totalForEvent updated transactionally).

`CloseEndedEventsCron @ EVERY_5_MINUTES` finds intents on events with
`endsAt ≤ now-1h` that don't yet have a reconciled Checkin and runs
`finalize` on each (cap 50/run).

### Storage + photos

`photos/<userId>/<eventId>/<photoId>.<ext>` in the private `photos`
bucket via service role. Mime allowlist: jpeg/png/heic/heif. 12MB cap.

EXIF is supplied client-side (mobile extracts it); backend computes
`isExifValid` (timestamp + lat/lng present), `isWithinTimeWindow`
(timestamp within event window ±30min). Geofence check on photo lat/lng
is deferred until the polygon column lands (currently always false).

### Hardening (commit 6)

- helmet: HSTS, X-Frame-Options=SAMEORIGIN, X-Content-Type-Options=nosniff,
  CSP off (Swagger UI needs inline scripts)
- CORS allowlist: `*.smwhr.dev`, `*.smwhr.quest`, `*.vercel.app`,
  `localhost`, `127.0.0.1`. Mobile / curl / server-side (no Origin
  header) always allowed
- ThrottlerGuard: 20/s short window + 300/min long window, by-IP
  default keyer. Returns 429 when exceeded
- Dockerfile multi-stage (Node 20 bookworm slim, pnpm 10.31)
- Railway: `apps/api/railway.json` points at the Dockerfile, healthcheck
  on `/health`, on-failure restart up to 5 retries

---

## How to run

```bash
# install deps (from repo root, pnpm workspace)
pnpm install

# generate Prisma client + run any pending migrations
cd apps/api
pnpm prisma:generate
pnpm prisma:migrate

# (optional) seed demo data
pnpm exec prisma db seed

# dev server with watch
pnpm start:dev    # http://localhost:3000

# Swagger
open http://localhost:3000/docs

# tests
pnpm test         # 26/26
```

Required env (in `apps/api/.env`, gitignored — see `.env.example`):
- `DATABASE_URL` (transaction pooler, port 6543)
- `DIRECT_URL` (session pooler, port 5432)
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`,
  `SUPABASE_JWT_SECRET`

Required Supabase config (one-time):
- Postgres extensions: `postgis`, `uuid-ossp`
- Storage buckets: `photos` (private), `badges` (public), `avatars`
  (public) — created programmatically in commit 4

---

## Cutover for mobile

To switch the Flutter app from mocks to this backend:

```bash
cd apps/mobile
flutter run \
  --dart-define=USE_MOCKS=false \
  --dart-define=API_BASE_URL=https://api.smwhr.dev \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

The `Real{Auth,Users,Events,Quests,Badges}Repository` stubs in
`apps/mobile/lib/data/remote/` already reference the exact endpoint
strings shipped here. Phase 2 cutover for mobile is detailed in
`docs/sprints/2026-04-25-phase2-cutover.md`.

---

## Phase 2 deferrals

Intentionally deferred — fine for soft launch, fix post-BTS:

| Stub | Where | Plan |
|---|---|---|
| Apple / Google sign-in | `/auth/{apple,google}` 501 | add provider creds in Supabase, switch to `signInWithIdToken` in AuthService — Moi to wire close to release |
| Sharp badge composition | backend stores `composedImageUrl = photo url`; mobile renders via `BadgeFrameOverlay` widget | port the widget logic to a sharp pipeline: frame SVG + photo overlay → 800×1200 display + 1080×1920 share |
| App Attest / Play Integrity verification | token stored as `pending_verification` (gives +3 instead of +15 to score) | call Apple App Attest / Google Play Integrity validation API in IntegrityService |
| Push notification dispatch | NotificationService logs payload; pushToken stored on User, recipient is looked up correctly | swap `NotificationService.dispatch()` to firebase-admin (FCM) + APNs HTTP/2; payload shape is stable |
| Vision API NSFW screening | `nsfwScore`/`nsfwFlagged` always default | call Google Vision SafeSearch on photo upload |
| Ticketmaster integration | events seeded manually | per-vertical sync workers; live catalog refresh |

---

## Gotchas & dev notes

- **Migrations touching PostGIS types** (e.g. `geography(...)`) must use
  `pnpm prisma migrate deploy` instead of `migrate dev`. Reason: the
  shadow database Prisma spins up for `dev` doesn't have postgis
  enabled, so it rejects the migration. `deploy` runs against the real
  DB only and skips shadow validation
- This Supabase project's postgis was originally in the `topology`
  schema, which made `geography(...)` unreachable without a qualifier.
  Fixed by `DROP EXTENSION postgis CASCADE; CREATE EXTENSION postgis
  WITH SCHEMA extensions;` (commit 7). If you bring up a fresh Supabase
  project, run `CREATE EXTENSION postgis WITH SCHEMA extensions;`
  before running any geography migration
- `nest build` requires `cwd` to be `apps/api/` — running from repo root
  triggers pnpm to look for a global `build` script and falls through.
  Use `pnpm --filter api build` from root or `cd apps/api && pnpm build`
- Supabase's drift detection bites Prisma's `postgresqlExtensions`
  preview feature because Supabase ships extra extensions
  (`pg_graphql`, `pg_stat_statements`, `pgcrypto`, `postgis_topology`,
  `supabase_vault`) Prisma doesn't model. Solution: don't declare any
  extensions in schema.prisma; Supabase manages them out-of-band. Raw
  SQL like `ST_Contains` still works
- `Prisma.JsonNull` (not literal `null`) for nullable JSON columns on
  insert — used in `LocusEvent.rawPayload`, `Photo.exifRaw`,
  `SystemEvent.metadata`
- `ScheduleModule.forRoot()` must be imported in `AppModule` for `@Cron`
  decorators to be picked up. Cron jobs run inside a single Nest
  process — fine for one Railway dyno; if scaling out, switch to
  BullMQ-backed queues
- The `photos` bucket is private and uses signed URLs. The mobile app
  resolves a signed URL via `StorageService.signedPhotoUrl(path)` —
  not yet exposed as an endpoint; add when needed
- Don't co-author commits with Claude (per founder preference,
  2026-04-25). Author every commit as the user only

---

## File map (key entry points)

```
apps/api/
├── Dockerfile + .dockerignore + railway.json   deploy artifacts
├── prisma/
│   ├── schema.prisma                            12 models, no extensions block
│   ├── migrations/
│   │   ├── 20260425205606_init/
│   │   └── 20260425211320_add_event_description/
│   └── seed.ts                                  idempotent fixture loader
├── src/
│   ├── main.ts                                  helmet + CORS + ValidationPipe + filter + Swagger
│   ├── app.module.ts                            ScheduleModule + ThrottlerModule + everything
│   ├── config/                                  ConfigService + Joi validation
│   ├── common/
│   │   ├── exceptions/api.exception.ts          ApiException with code field
│   │   └── filters/api-exception.filter.ts      stable error envelope
│   ├── prisma/                                  global PrismaService + module
│   ├── auth/
│   │   ├── decorators/{public,current-user}.decorator.ts
│   │   ├── guards/jwt-auth.guard.ts             supabase.auth.getUser + auto-create User
│   │   ├── supabase.service.ts                  admin + anon clients
│   │   ├── auth.service.ts                      magic link, refresh, NotImplemented for OAuth
│   │   ├── auth.controller.ts
│   │   └── dto/                                 5 input DTOs
│   ├── users/
│   │   ├── utils/handle.validator.{ts,spec.ts}  3-20 chars, [a-z0-9_], reserved set
│   │   ├── dto/{onboarding,update-me}.dto.ts
│   │   ├── users.{service,controller,module}.ts
│   ├── events/
│   │   ├── dto/list-events.dto.ts
│   │   ├── events.{service,controller,module}.ts
│   │   └── intents.service.ts                   colocated to avoid circular dep
│   ├── quests/
│   │   ├── dto/{locus-event,geolocator-ping,sync-tracking,integrity,upload-photo}.dto.ts
│   │   ├── services/
│   │   │   ├── reconciliation.{service,spec}.ts  5 strategies + agreement metric
│   │   │   ├── verification.{service,spec}.ts    score buckets + thresholds
│   │   │   └── checkin-finalizer.service.ts      orchestrator + Badge mint
│   │   ├── cron/close-ended-events.cron.ts       EVERY_5_MINUTES
│   │   ├── storage.service.ts                    Supabase Storage upload + signed URL
│   │   ├── quests.{service,controller,module}.ts
│   ├── badges/
│   │   ├── badges.{service,controller,module}.ts
│   ├── waitlist/
│   │   ├── dto/waitlist-signup.dto.ts
│   │   ├── waitlist.{service,controller,module}.ts
│   └── health/
│       ├── health.{controller,module}.ts        Public; DB ping
└── package.json                                 pnpm workspace api package
```

---

## Bootstrapping a fresh conversation

Paste this into a new chat:

> I'm Moi, founder of smwhr. R0.1 Phase 2 backend is complete (9
> sequential commits on `main`, NestJS + Supabase + Prisma + PostGIS
> serving the entire mobile contract end-to-end, plus geofence
> verification, audit logging in system_events, and a notification stub
> ready for FCM/APNs). All 26 unit tests pass; full smoke ran
> end-to-end against real Supabase, ending with a verified Badge minted
> for a synthetic dual-track session. Apple/Google sign-in is the only
> auth provider deferred until close to release.
> See `docs/sprints/2026-04-25-backend-phase2-handoff.md` for the full
> context dump. Today I want to <X>.
