# smwhr — Día 1 Checklist (Miércoles 22 Abril 2026)

Este documento es tu guía hora por hora del Día 1 del sprint. Sigue el orden. No te saltes pasos. Si algo no funciona, resuélvelo antes de avanzar.

**Objetivo del Día 1:** Al final del día, tener el monorepo configurado, todas las cuentas externas listas, Supabase con PostGIS activado, Railway con health check respondiendo, y los CLAUDE.md en su lugar. Cero código de producto todavía.

---

## 🌅 Mañana — 08:00 a 13:00 — Setup de cuentas y dominio

### 08:00 — 08:30 · Dominio y repo

- [ ] Registrar `smwhr.quest` en Porkbun (~$12 USD/año)
    - Si está tomado: `smwhr.app` o `getsmwhr.com`
    - Comprar también `smwhr.mx` como backup regional
- [ ] Crear repo privado en GitHub: `orbit-m/smwhr`
    - Usar template del monorepo (pnpm workspaces)
- [ ] Clone local:
    ```bash
    git clone git@github.com:orbit-m/smwhr.git
    cd smwhr
    ```

### 08:30 — 10:00 · Cuentas externas

Abre una pestaña por cada uno y créalos en orden. Guarda todas las credentials en un archivo `.env.master` local.

- [ ] **Supabase** — https://supabase.com/dashboard/new
    - Region: `us-east-1` (cerca de México, bajo latency)
    - Plan: Free tier (suficiente para R0.1)
    - Nombre: `smwhr-prod`
    - Guarda: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `DATABASE_URL`
- [ ] **Upstash Redis** — https://console.upstash.com/
    - Region: `us-east-1`
    - Plan: Free tier
    - Tipo: Global
    - Guarda: `REDIS_URL`, `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`
- [ ] **Railway** — https://railway.app/dashboard
    - Conecta con GitHub
    - Plan: Hobby ($5/mes)
    - Crea proyecto vacío `smwhr`
- [ ] **Vercel** — https://vercel.com/dashboard
    - Conecta con GitHub
    - Plan: Hobby (free)
    - Nombre proyecto: `smwhr-landing`
- [ ] **Ticketmaster Developer** — https://developer.ticketmaster.com/
    - Registra app nueva: "smwhr"
    - Guarda: `TICKETMASTER_API_KEY`
- [ ] **Apple Developer** — https://developer.apple.com/
    - Verifica que tu cuenta $99/año está activa
    - Si no tienes: crearla ($99 USD, esperar 24-48h de aprobación)
    - Create App ID: `quest.smwhr.app`
    - Enable capabilities: Sign in with Apple, Push Notifications, App Attest
- [ ] **Google Cloud Console** — https://console.cloud.google.com/
    - Crea proyecto nuevo: `smwhr`
    - Habilita APIs: Play Integrity, Vision, Maps Geocoding
    - Create OAuth Client IDs: iOS, Android, Web
    - Guarda: `GOOGLE_CLIENT_ID_*`
- [ ] **Firebase** — https://console.firebase.google.com/
    - Vincula al proyecto `smwhr` de Google Cloud
    - Registra apps iOS + Android
    - Descarga `GoogleService-Info.plist` (iOS) y `google-services.json` (Android)
- [ ] **OneSignal** — https://dashboard.onesignal.com/
    - Crea app: `smwhr`
    - Guarda: `ONESIGNAL_APP_ID`, `ONESIGNAL_API_KEY`
- [ ] **Resend** — https://resend.com/
    - Crea cuenta, verifica email
    - Agrega dominio `smwhr.quest` (DNS via Cloudflare)
    - Guarda: `RESEND_API_KEY`
- [ ] **Cloudflare** — https://dash.cloudflare.com/
    - Agregar zona `smwhr.quest`
    - Cambiar nameservers en Porkbun
    - Configurar DNS records (A, CNAME para railway + vercel)
- [ ] **Sentry** — https://sentry.io/signup/
    - Plan: Developer (free)
    - Crea proyectos: `smwhr-api`, `smwhr-mobile`
    - Guarda: `SENTRY_DSN`
- [ ] **PostHog** — https://app.posthog.com/signup
    - Plan: Free tier (1M events/mes)
    - Guarda: `POSTHOG_KEY`

### 10:00 — 11:30 · Supabase setup

- [ ] En Supabase Dashboard, abrir SQL Editor y ejecutar:
    ```sql
    -- Habilitar extensiones
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

    -- Verificar
    SELECT postgis_version();
    SELECT uuid_generate_v4();
    ```
- [ ] En Supabase Auth Settings:
    - Site URL: `https://smwhr.quest`
    - Redirect URLs: `quest.smwhr.app://auth/callback`, `http://localhost:3000/auth/callback`
    - Enable providers: Apple, Google, Email (magic link)
    - Configurar Apple/Google OAuth con las credentials creadas arriba
- [ ] En Supabase Storage:
    - Crear bucket `photos` (privado)
    - Crear bucket `badges` (público con RLS)
    - Crear bucket `frames` (público, CDN)

### 11:30 — 12:30 · Monorepo setup

```bash
cd smwhr

# Inicializar pnpm workspaces
cat > package.json << 'EOF'
{
  "name": "smwhr-monorepo",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev:api": "pnpm --filter api dev",
    "dev:mobile": "pnpm --filter mobile run",
    "dev:landing": "pnpm --filter landing dev",
    "build:api": "pnpm --filter api build",
    "build:landing": "pnpm --filter landing build",
    "prisma:generate": "pnpm --filter api prisma generate",
    "prisma:migrate": "pnpm --filter api prisma migrate dev",
    "prisma:studio": "pnpm --filter api prisma studio",
    "prisma:seed": "pnpm --filter api prisma db seed"
  },
  "devDependencies": {
    "prettier": "^3.0.0",
    "typescript": "^5.3.0"
  }
}
EOF

cat > pnpm-workspace.yaml << 'EOF'
packages:
  - 'apps/*'
  - 'packages/*'
EOF

# Crear .gitignore
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
.pnpm-store/

# Env
.env
.env.local
.env.master
!.env.example

# Build
dist/
build/
.next/

# Flutter
apps/mobile/build/
apps/mobile/.dart_tool/
apps/mobile/.flutter-plugins
apps/mobile/.flutter-plugins-dependencies
apps/mobile/ios/Pods/
apps/mobile/ios/.symlinks/

# Prisma
apps/api/prisma/generated/

# IDE
.vscode/
.idea/
*.swp

# OS
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*

# Testing
coverage/
.nyc_output/
EOF

# Estructura inicial
mkdir -p apps/api apps/mobile apps/landing packages/shared-types docs design/mocks/v1

# Copiar CLAUDE.md files (ya tienes estos del starter kit)
# Copiar schema.prisma al folder apps/api/prisma/
# Copiar seed.ts al folder apps/api/prisma/
# Copiar .env.example a la raíz

# Commit inicial
git add .
git commit -m "chore: initial monorepo setup"
git push origin main
```

### 12:30 — 13:00 · Almuerzo y planning del afternoon

Tómate 30 min de almuerzo real. Alejate de la pantalla. Necesitas batería mental para el bloque tarde que es más técnico.

---

## 🌆 Tarde — 14:00 a 18:00 — Bootstrap técnico

### 14:00 — 15:30 · Bootstrap backend (apps/api)

```bash
cd apps/api

# Crear NestJS app
npx @nestjs/cli new . --package-manager pnpm --skip-git

# Instalar dependencias core
pnpm add @nestjs/config @nestjs/swagger @nestjs/throttler @nestjs/schedule
pnpm add @nestjs/passport passport passport-jwt passport-google-oauth20
pnpm add passport-apple passport-custom
pnpm add @nestjs/bullmq bullmq
pnpm add class-validator class-transformer
pnpm add @supabase/supabase-js
pnpm add sharp
pnpm add bcrypt jsonwebtoken
pnpm add axios

# Dev dependencies
pnpm add -D prisma @types/bcrypt @types/passport-jwt
pnpm add -D @types/jsonwebtoken

# Prisma setup
npx prisma init
# Copiar schema.prisma del starter-kit a prisma/schema.prisma
# Copiar seed.ts del starter-kit a prisma/seed.ts

# Agregar script de seed a package.json:
# "prisma": { "seed": "ts-node prisma/seed.ts" }

# Configurar .env
cp ../../.env.example .env
# Editar .env con valores reales

# Generar Prisma client
npx prisma generate

# Primera migración (crea las tablas)
npx prisma migrate dev --name init

# Ejecutar seed
npx prisma db seed

# Verificar que todo funciona
npx prisma studio  # abre UI en localhost:5555

# Configurar scripts en package.json:
# "start:dev": "nest start --watch"
# "build": "nest build"
# "start:prod": "node dist/main"
```

### 15:30 — 16:30 · Primer endpoint + deploy Railway

Crear health check en `apps/api/src/health/health.controller.ts`:

```typescript
import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  check() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '0.1.0',
    };
  }
}
```

Deploy a Railway:

```bash
# En Railway dashboard:
# 1. New Project → Deploy from GitHub
# 2. Seleccionar repo smwhr
# 3. Set root directory: apps/api
# 4. Agregar variables de entorno del .env
# 5. Deploy

# Verificar que funciona:
curl https://smwhr-api.up.railway.app/health
```

### 16:30 — 17:30 · Bootstrap mobile (apps/mobile)

```bash
cd apps/mobile

# Crear Flutter app
flutter create --org quest.smwhr --project-name smwhr .

# Agregar dependencias
# Editar pubspec.yaml con:
```

```yaml
name: smwhr
description: You were somewhere.
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ^3.5.0
  flutter: ^3.24.0

dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

  # Navigation
  go_router: ^14.2.0

  # HTTP
  dio: ^5.5.0

  # Secure storage
  flutter_secure_storage: ^9.2.0

  # Local DB (Hive para dual-track)
  hive: ^2.2.0
  hive_flutter: ^1.1.0

  # Supabase
  supabase_flutter: ^2.5.0

  # Geolocation dual-track
  locus: ^2.0.0
  geolocator: ^12.0.0
  permission_handler: ^11.3.0
  workmanager: ^0.5.2

  # Media
  camera: ^0.11.0
  native_exif: ^0.6.0

  # Auth
  sign_in_with_apple: ^6.1.0
  google_sign_in: ^6.2.0

  # Push
  firebase_core: ^3.0.0
  firebase_messaging: ^15.0.0
  flutter_local_notifications: ^17.2.0

  # UI
  flutter_svg: ^2.0.0
  lottie: ^3.1.0
  cached_network_image: ^3.3.0
  shared_preferences: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.0
  hive_generator: ^2.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/badges/
    - assets/animations/
    - assets/icons/
  fonts:
    - family: Space Grotesk
      fonts:
        - asset: assets/fonts/SpaceGrotesk-Regular.ttf
        - asset: assets/fonts/SpaceGrotesk-Medium.ttf
          weight: 500
        - asset: assets/fonts/SpaceGrotesk-Bold.ttf
          weight: 700
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
    - family: JetBrains Mono
      fonts:
        - asset: assets/fonts/JetBrainsMono-Regular.ttf
        - asset: assets/fonts/JetBrainsMono-Medium.ttf
          weight: 500
```

```bash
# Instalar
flutter pub get

# Download de fonts (Google Fonts TTF)
mkdir -p assets/fonts
# Descargar manualmente de fonts.google.com:
# - Space Grotesk (Regular, Medium, Bold)
# - Inter (Regular, Medium, Bold)
# - JetBrains Mono (Regular, Medium)

# Verificar que compila
flutter run
```

### 17:30 — 18:00 · Bootstrap landing (apps/landing)

```bash
cd apps/landing

# Crear Next.js app
npx create-next-app@latest . \
  --typescript \
  --tailwind \
  --app \
  --no-src-dir \
  --import-alias "@/*" \
  --use-pnpm

# Deploy a Vercel
# En Vercel dashboard:
# 1. Add New Project → Import repo smwhr
# 2. Root directory: apps/landing
# 3. Framework: Next.js (auto-detected)
# 4. Deploy
# 5. Configurar dominio: smwhr.quest
```

---

## 🌙 Noche — 19:00 a 22:00 — Preparar Día 2

### 19:00 — 20:00 · Cena y descompresión

Come bien. Si vives con gente, habla con ellos. Haz ejercicio 20 min. No revises el teléfono con contexto de trabajo.

### 20:00 — 21:30 · Documentación y commit final

```bash
cd smwhr

# Commit todo el trabajo del día
git add .
git commit -m "chore: Day 1 complete — monorepo, backend, mobile, landing scaffolded"
git push

# Actualizar README principal
cat > README.md << 'EOF'
# smwhr

You were somewhere.

## Structure
- `apps/api` — NestJS backend
- `apps/mobile` — Flutter app
- `apps/landing` — Next.js landing

## Setup
1. `cp .env.example .env` and fill values
2. `pnpm install`
3. `pnpm prisma:generate && pnpm prisma:migrate`
4. `pnpm prisma:seed`
5. `pnpm dev:api`

## Docs
- `docs/ARCHITECTURE.md` — technical architecture
- `docs/ROADMAP.md` — product roadmap
- `CLAUDE.md` — agent constitution
EOF

git add README.md
git commit -m "docs: main README"
git push
```

### 21:30 — 22:00 · Planning del Día 2

Abre notas y escribe:

1. **¿Qué salió bien hoy?** (mínimo 3 cosas)
2. **¿Qué bloqueos encontré?** (documenta para resolver rápido)
3. **¿Mañana primer bloque de 4h en qué?** (plan con fechas específicas: 09:00-13:00 = X, 14:00-18:00 = Y)
4. **¿Qué necesito dormir resolver?** (ponlo en el subconsciente)

### 22:00 · Sleep

Duerme. El Día 2 necesita foco técnico intenso. No te desveles navegando ni planeando.

---

## ✅ Checklist final del Día 1

Al acostarte, deberías tener:

- [x] Dominio `smwhr.quest` registrado y DNS apuntando a Cloudflare
- [x] Todas las cuentas externas creadas con credenciales guardadas
- [x] Supabase con PostGIS habilitado + Auth configurado + Storage buckets
- [x] Repo GitHub con estructura monorepo + CLAUDE.md files
- [x] Backend NestJS con health check respondiendo en Railway
- [x] Prisma migrations ejecutadas + seed corriendo exitosamente
- [x] Flutter app compilando en emulator
- [x] Landing Next.js desplegada en Vercel
- [x] Plan claro del Día 2 escrito

Si checkeas los 9 items, el Día 1 fue exitoso. Si te falta alguno crítico (dominio, Supabase, backend deployed), resuélvelo en el Día 2 primero.

---

## 🚨 Troubleshooting

### "Apple Developer account pendiente"
Si no puedes completar App ID hoy: continúa con Google auth only para Día 2. Agrega Apple el Día 3 cuando esté aprobado.

### "Supabase DB connection fails"
Verifica que usas el connection pooler URL (`aws-0-xx.pooler.supabase.com:6543`) para `DATABASE_URL` y el direct URL (`xxxx.supabase.co:5432`) para `DIRECT_URL`.

### "Railway deploy failing"
Verifica que `apps/api/package.json` tiene `"start:prod": "node dist/main.js"` y que el build completa localmente con `pnpm build`.

### "Flutter geolocation no funciona en emulador"
Locus y geolocator requieren device real. Deja el testing de dual-track para Día 4 con un phone físico.

---

*Este es tu mapa del Día 1. Síguelo. Al final, deberías tener los fundamentos para empezar a construir producto el Día 2. Vamos con fuego, Moi.*
