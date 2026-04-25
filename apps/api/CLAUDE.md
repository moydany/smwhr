# Backend Agent — apps/api

Scope: NestJS API + Prisma + Supabase backend de smwhr.

Lee primero el `CLAUDE.md` raíz. Este documento complementa, no reemplaza.

---

## Stack

- **Framework:** NestJS 10+ con TypeScript strict mode
- **ORM:** Prisma con Postgres (Supabase hosted)
- **Auth:** Supabase Auth (Apple, Google, magic link) + JWT propios
- **Jobs:** BullMQ + Redis (Upstash)
- **Storage:** Supabase Storage
- **Image processing:** sharp
- **Validation:** class-validator + class-transformer
- **Docs:** Swagger auto-generado en `/docs`
- **Testing:** Jest + supertest
- **Linting:** ESLint + Prettier

---

## Estructura de folders

```
apps/api/
├── src/
│   ├── main.ts
│   ├── app.module.ts
│   ├── config/              # env vars, constants
│   │   ├── app.config.ts
│   │   ├── database.config.ts
│   │   └── validation.schema.ts
│   ├── common/              # shared utilities
│   │   ├── decorators/
│   │   ├── filters/
│   │   ├── guards/
│   │   ├── interceptors/
│   │   └── pipes/
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── strategies/
│   │   │   ├── dto/
│   │   │   ├── auth.controller.ts
│   │   │   ├── auth.service.ts
│   │   │   └── auth.module.ts
│   │   ├── users/
│   │   ├── events/
│   │   ├── intents/
│   │   ├── quests/
│   │   │   ├── dto/
│   │   │   ├── services/
│   │   │   │   ├── tracking.service.ts        # ingesta dual-track
│   │   │   │   ├── reconciliation.service.ts  # engine crítico
│   │   │   │   └── verification.service.ts    # scoring
│   │   │   ├── quests.controller.ts
│   │   │   └── quests.module.ts
│   │   ├── badges/
│   │   ├── uploads/
│   │   ├── integrations/
│   │   │   ├── ticketmaster/
│   │   │   └── vision/
│   │   └── notifications/
│   ├── workers/             # BullMQ processors
│   │   ├── reconciliation.processor.ts
│   │   ├── badge-composition.processor.ts
│   │   ├── photo-processing.processor.ts
│   │   └── event-sync.processor.ts
│   ├── prisma/
│   │   └── prisma.service.ts
│   └── health/
│       └── health.controller.ts
├── prisma/
│   ├── schema.prisma
│   ├── migrations/
│   └── seed.ts
├── test/
├── .env.example
├── Dockerfile
├── nest-cli.json
├── package.json
└── tsconfig.json
```

---

## Convenciones de código

### Naming
- Archivos: `kebab-case.ts` (ej: `reconciliation.service.ts`)
- Clases: `PascalCase` (ej: `ReconciliationService`)
- Funciones y variables: `camelCase`
- Enums: `PascalCase` con valores en `SCREAMING_SNAKE_CASE`
- Constantes: `SCREAMING_SNAKE_CASE`

### Módulos NestJS
- Cada módulo tiene su folder con `*.module.ts`, `*.controller.ts`, `*.service.ts`
- DTOs en subfolder `dto/`
- Servicios auxiliares en subfolder `services/` si son muchos

### DTOs (obligatorio)
- Todo input validado con class-validator
- Todo output tipado con interfaces o classes
- Ejemplo:
```typescript
export class CreateIntentDto {
  @IsUUID()
  eventId: string;
}
```

### Servicios
- Lógica de negocio SIEMPRE en servicios, NUNCA en controllers
- Controllers solo: validar input, llamar servicio, retornar respuesta
- Servicios reciben DTOs, nunca `any`

### Error handling
- Usa excepciones de NestJS: `BadRequestException`, `NotFoundException`, `UnauthorizedException`, etc.
- Error messages en inglés, claros y accionables
- Nunca expongas stack traces al cliente en producción

### Testing
- Tests unitarios para servicios críticos (auth, reconciliation, verification)
- Tests e2e para flujos críticos (signup → intent → quest → badge)
- Mock de servicios externos (Ticketmaster, Vision API)

---

## Rutas de API (resumen)

Ver `docs/API.md` para especificación completa. Resumen:

```
/auth/*         — signup/signin/refresh
/me             — perfil propio
/users/*        — perfiles públicos, handle check
/events/*       — catálogo + detalle
/events/:id/intent — POST/DELETE intent
/quests/*       — sync dual-track + integrity + photo
/badges/*       — colección propia + detalle + share
/webhooks/*     — integraciones internas
```

---

## Módulos críticos

### `modules/quests/services/reconciliation.service.ts`

Este es el servicio más importante del backend. Implementa las 4 estrategias definidas en `docs/ARCHITECTURE.md` sección 3.

Input: `userId`, `eventId`
Output: `ReconciliationResult` con `primarySource`, `dwellMinutes`, `verificationScore`, `reason`

Debe ser 100% testeable con tests unitarios que cubran cada una de las 4 estrategias con fixtures representativos.

### `modules/quests/services/tracking.service.ts`

Recibe el batch `POST /quests/:id/sync` y hace:
1. Validar intent existe
2. Insertar en `locus_events` y `geolocator_pings`
3. Para cada punto, calcular `isInsidePolygon` via PostGIS (`ST_Contains`)
4. Retornar confirmación con counts

### `modules/quests/services/verification.service.ts`

Calcula `verificationScore` según la fórmula en `docs/ARCHITECTURE.md` sección 8. Input: `Checkin`, `Event`. Output: score 0-100.

### `workers/reconciliation.processor.ts`

BullMQ worker que procesa la queue `reconciliation`. Se dispara cuando un evento termina (cron `closeEndedEvents` lo encola).

Pipeline:
1. Fetch locusEvents + geolocatorPings
2. Llamar ReconciliationService
3. Upsert Checkin con resultados
4. Si score >= threshold, encolar `badge-composition`

### `workers/badge-composition.processor.ts`

Compone la imagen final de la insignia con sharp. Input: checkin + foto opcional + template. Output: dos imágenes (display 4:5 y share 9:16) subidas a Supabase Storage.

Ver `docs/ARCHITECTURE.md` sección 9 para el pipeline de sharp.

---

## PostGIS queries críticas

Ejemplo de check si un punto está dentro del polygon del evento:

```typescript
const result = await this.prisma.$queryRaw<[{ inside: boolean }]>`
  SELECT ST_Contains(
    (SELECT geofence_polygon FROM events WHERE id = ${eventId}::uuid),
    ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography
  ) as inside
`;
return result[0].inside;
```

---

## Seguridad

- **JWT secret:** min 64 chars random, rotado cada 90 días en producción
- **Rate limiting:** `@nestjs/throttler` en endpoints públicos (auth, events search)
- **CORS:** solo permitir orígenes conocidos (smwhr.quest, claude.ai dev)
- **SQL injection:** 0 raw queries excepto PostGIS. Todo vía Prisma
- **Secrets:** nunca en repo. Todo vía `.env` + Railway env vars
- **HTTPS only:** Railway provee. Nunca HTTP en producción

---

## Performance

- **Connection pooling:** Prisma con `connection_limit=20`
- **Cache:** Redis para eventos featured, counts cached
- **N+1 queries:** usa `include` o `select` explícito, nunca loops con queries
- **Batch operations:** Prisma `createMany` para inserts masivos (locus_events, geolocator_pings)

---

## Deployment

- **Entorno dev:** local con `docker-compose up`
- **Entorno staging:** Railway branch `staging`
- **Entorno prod:** Railway branch `main`
- **CI/CD:** GitHub Actions corre tests, si pasan → auto-deploy

---

## Anti-patterns backend

- ❌ Lógica de negocio en controllers
- ❌ `console.log` en código commiteado (usa Logger de Nest)
- ❌ Endpoints sin autenticación explícita (`@Public()` decorator para los raros)
- ❌ Prisma queries sin tipado
- ❌ Swallow errors (siempre logger.error + throw)
- ❌ Sync file operations en endpoints (usa Buffer + Supabase Storage)
- ❌ Raw SQL excepto PostGIS queries específicas
- ❌ Hardcode de URLs, IDs, configs

---

## First tasks (Día 1-2)

Ordered list de lo que el Backend Agent debe hacer Día 1-2:

1. `npx @nestjs/cli new api` dentro de `apps/`
2. Configurar `tsconfig.json` con strict mode
3. Instalar dependencies: prisma, @supabase/supabase-js, passport, bullmq, class-validator, sharp, @nestjs/swagger, @nestjs/schedule, @nestjs/throttler
4. Copiar `prisma/schema.prisma` del repo root
5. Ejecutar `npx prisma generate` + primera migración
6. Crear módulo `auth` con strategies Apple + Google + email magic link
7. Crear módulo `users` con endpoint `/me` y `/users/:handle`
8. Crear módulo `events` con endpoint `GET /events` (mock data primero)
9. Configurar Swagger en `/docs`
10. Health check endpoint en `GET /health`
11. Deploy inicial a Railway con health check respondiendo

Después de eso, pasar a módulos `intents` y `quests` en Día 3-4.
