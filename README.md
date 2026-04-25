# smwhr

**You were somewhere.**

A mobile app that verifies physical attendance at real events and issues collectible proof of presence. LATAM-first, Mexico-rooted.

---

## 🚀 Quick start

Si es tu primera vez en el repo, lee en este orden:

1. `CLAUDE.md` — constitución del proyecto (10 min)
2. `docs/ROADMAP.md` — visión a 3 años (15 min)
3. `docs/ARCHITECTURE.md` — arquitectura técnica (20 min)
4. `docs/FRONTEND_FIRST_STRATEGY.md` — estrategia de implementación (10 min)
5. `docs/CLAUDE_CODE_SETUP.md` — cómo arrancar con Claude Code (10 min)
6. `scripts/DAY_1_CHECKLIST.md` — tu mapa hora por hora del Día 1

---

## 📁 Estructura

```
smwhr/
├── apps/
│   ├── api/              NestJS backend (Días 8-12)
│   │   └── prisma/
│   │       ├── schema.prisma
│   │       └── seed.ts
│   ├── mobile/           Flutter app (Días 1-7, frontend-first)
│   └── landing/          Next.js landing
├── docs/
│   ├── ARCHITECTURE.md   Stack + dual-track + reconciliation
│   ├── ROADMAP.md        9 releases, 3 capas, 5 años
│   ├── FRONTEND_FIRST_STRATEGY.md
│   ├── ONBOARDING_FLOW.md
│   └── CLAUDE_CODE_SETUP.md
├── design/
│   └── mocks/v1/         11 PNGs + design system PDF
├── scripts/
│   ├── DAY_1_CHECKLIST.md
│   └── init-db.sql       PostGIS local setup
├── .github/workflows/    CI para api + mobile
├── CLAUDE.md             Agent constitution (root)
├── docker-compose.yml    Postgres + Redis + MinIO local
├── .env.example
└── README.md             (este archivo)
```

---

## 🎯 Estado actual

**Fase:** R0.1 Music — Sprint Day 0 (setup)
**Target launch:** 5 mayo 2026
**Hero event:** BTS World Tour, 7-10 mayo, Estadio GNP Seguros CDMX

### Progreso del sprint

- [ ] Día 1: Setup + Design System + Theme + Splash/Auth
- [ ] Día 2: Onboarding completo (4 pantallas)
- [ ] Día 3: Home feed + Event detail
- [ ] Día 4: Active Quest screen con timer mock
- [ ] Día 5: Camera + Reveal
- [ ] Día 6: Profile + Collection + Share
- [ ] Día 7: Pulido visual + animations
- [ ] Día 8-12: Backend NestJS real
- [ ] Día 13-15: Integración + soft launch

---

## 🛠 Tech stack

### Mobile
- **Flutter** + Dart 3.5+
- **Riverpod** state management
- **go_router** navigation
- **dio** HTTP
- **Locus** + **geolocator** (dual-track tracking)
- **hive_flutter** local storage
- **Supabase Flutter** auth + storage
- **camera** in-app capture
- **Firebase Messaging** push

### Backend
- **NestJS** 10+ TypeScript strict
- **Prisma** ORM
- **Postgres 16** + **PostGIS**
- **BullMQ** + **Redis** background jobs
- **sharp** image composition
- **Passport.js** auth strategies

### Infra
- **Supabase** (DB + Auth + Storage + RLS)
- **Railway** (backend deploy)
- **Vercel** (landing deploy)
- **Upstash** (Redis serverless)
- **Cloudflare** (DNS)
- **OneSignal** (push)
- **Sentry** + **PostHog** + **BetterStack** (monitoring)

---

## 📦 Setup local

### Prerequisitos

```bash
node --version    # >= 20.x
pnpm --version    # >= 9.x
flutter --version # >= 3.24
git --version
```

### Clonar y setup

```bash
git clone git@github.com:orbit-m/smwhr.git
cd smwhr

# Variables de entorno
cp .env.example .env
# Edita .env con valores reales (ver scripts/DAY_1_CHECKLIST.md)

# Mobile
cd apps/mobile
flutter create --org quest.smwhr --project-name smwhr .
flutter pub get

# Para desarrollo con mocks (Días 1-7)
flutter run --dart-define=USE_MOCKS=true

# Para desarrollo con backend real (Días 8+)
flutter run --dart-define=USE_MOCKS=false --dart-define=API_BASE_URL=http://localhost:3000
```

### Backend (después del Día 8)

```bash
cd apps/api

# Bootstrap NestJS
npx @nestjs/cli new . --package-manager pnpm --skip-git

# Instalar dependencias (ver apps/api/CLAUDE.md)
pnpm add @nestjs/config @nestjs/swagger @nestjs/throttler @nestjs/schedule
pnpm add @nestjs/passport passport passport-jwt
pnpm add @nestjs/bullmq bullmq
pnpm add class-validator class-transformer
pnpm add @supabase/supabase-js sharp
pnpm add -D prisma

# Setup Prisma
npx prisma generate
npx prisma migrate dev --name init
npx prisma db seed

# Run
pnpm start:dev
```

### Postgres local con Docker (alternativa a Supabase remoto)

```bash
docker-compose up -d
# Postgres con PostGIS en :5432
# Redis en :6379
# MinIO (S3 mock) en :9000
```

---

## 🤖 Working con Claude Code

### Setup

1. Instala Claude Code app de escritorio: https://claude.ai/download
2. Login con cuenta Anthropic (Pro/Team/Max)
3. New conversation → add folder context → `~/Code/smwhr/apps/mobile/`
4. Add files: todos los CLAUDE.md y docs/*.md
5. Lee `docs/CLAUDE_CODE_SETUP.md` para el prompt de inicialización exacto

### Modelo de trabajo

- **Una conversación = una feature** (no mezcles)
- **Sonnet para boilerplate, Opus para arquitectura**
- **Review obligatorio antes de aceptar código**
- **Commit pequeño y frecuente**
- **CLAUDE.md es ley** (no permitir reaperturas)

---

## 🎨 Design system

Coherente entre app y landing:

```
Background:      #050505
Surface:         #111111
Surface elevated: #1A1A1A
Border:          #2A2A2A

Text primary:    #FFFFFF
Text secondary:  #888888
Text tertiary:   #555555

Accent:          #FF2D95 (magenta neón)
Accent muted:    #8B1A51

Display:  Space Grotesk (700)
Body:     Inter (400, 500)
Mono:     JetBrains Mono (400, 500)

Spacing:  4 · 8 · 12 · 16 · 24 · 32 · 48 · 64
Radius:   8 (sm) · 12 (badge) · 16 (card) · 54 (frame)
```

Mocks v1 en `design/mocks/v1/` (11 pantallas + design system).

---

## 🚦 Ambientes

- **Dev local:** `flutter run --dart-define=USE_MOCKS=true`
- **Dev con backend:** `flutter run --dart-define=USE_MOCKS=false`
- **Staging:** rama `staging`, auto-deploy a Railway/Vercel
- **Production:** rama `main`, deploy manual approval

---

## 📊 Comandos útiles

```bash
# Backend
pnpm dev:api              # Watch mode
pnpm prisma:generate
pnpm prisma:migrate
pnpm prisma:seed
pnpm prisma:studio        # UI en :5555

# Mobile
cd apps/mobile
flutter run               # Default device
flutter run -d chrome     # Web
flutter clean             # Si algo se rompe
flutter pub upgrade       # Actualizar deps

# Tests
pnpm test:api
flutter test

# Build production
pnpm build:api
flutter build ios --release
flutter build apk --release
```

---

## 🔐 Seguridad

- **Nunca commits con secrets:** `.env` está en `.gitignore`
- **JWT secret:** mínimo 64 caracteres random
- **Rotación:** secrets cada 90 días en producción
- **HTTPS only** en todos los ambientes salvo localhost
- **Rate limiting** en endpoints públicos
- **PII privacy:** strict opt-in, ninguna data se vende sin consent

Si encuentras issue de seguridad: hi@smwhr.quest (reportar privadamente, no abrir issue público).

---

## 📝 Contributing

Por ahora, solo Moi commits a `main`. Si en el futuro se incorpora alguien:

- Branch desde `main`: `feat/nombre`, `fix/nombre`, `chore/nombre`
- Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`
- PR con descripción clara + screenshots si toca UI
- CI debe pasar antes de merge
- Squash merge a `main`

---

## 📅 Timeline R0.1

```
Abril 2026
├── 22 (Mié)  Día 1: Setup + Foundation
├── 23-28     Días 2-7: Frontend completo con mocks
├── 29 (Mié)  Día 8: Backend NestJS bootstrap
├── 30        Día 9: Auth + Events
└──

Mayo 2026
├── 1 (Vie)   Día 10: Quest + dual-track
├── 2-3       Días 11-12: Badges + composition
├── 4 (Lun)   Día 13: Integración real
├── 5 (Mar)   Día 14: SOFT LAUNCH 🚀
├── 6         Día 15: Monitoring + bug fixes
├── 7 (Jue)   BTS Day 1 — hero event
├── 9 (Sáb)   BTS Day 2
├── 10 (Dom)  BTS Day 3
└── 11 (Lun)  Post-event analysis
```

---

## 🌟 Filosofía

smwhr es para personas que sí van. Que se mueven. Que invierten su presencia física en momentos que valen la pena. Cualquier feature, cualquier decisión, cualquier línea de código se evalúa con esta pregunta: *"¿Esto sirve a alguien que está saliendo de su casa para vivir algo real?"*

Si la respuesta es sí, construimos. Si la respuesta es no, cortamos.

---

## 📞 Contacto

- **Founder:** Moi
- **Email:** hi@smwhr.quest
- **X:** @smwhr (próximamente)
- **Studio:** Orbit M

---

## ⚖️ License

UNLICENSED — Proprietary. Copyright © 2026 Orbit M.

---

*"You were somewhere — y smwhr estará ahí para probarlo."*
