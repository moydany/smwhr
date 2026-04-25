# smwhr — Agent Constitution

Esta es la fuente de verdad para cualquier agente (Claude Code, asistentes, devs humanos) trabajando en smwhr. Si algo en este documento contradice lo que crees saber del proyecto, este documento gana.

---

## Qué es smwhr

Una app móvil que verifica físicamente la asistencia de un usuario a eventos reales (conciertos, festivales, partidos, cumbres, eventos chicos) y emite una insignia digital coleccionable como prueba emocional y social de haber estado ahí.

**Tagline:** "You were somewhere."

**Concepto mental:** "Una carta Pokémon de tu vida real, verificada por GPS."

**Mercado primario:** México y LATAM hispanohablante.

---

## Por qué existe

Los eventos en vivo dejan memoria pero no evidencia. Los fans documentan su vida cultural (Gigs, Setlist.fm, Letterboxd para eventos como AC Momento) pero sin verificación real — cualquiera puede decir que estuvo en el show. smwhr resuelve esto combinando verificación técnica rigurosa (GPS + dwell time + device integrity + foto con EXIF) con diseño emocional (marco coleccionable + foto del usuario + share compartible).

**Diferenciador 1:** en smwhr, "I was there" no es autoreporte, es prueba.

**Diferenciador 2:** smwhr opera para LATAM con profundidad cultural y catálogo de eventos que competidores globales (AC Momento) nunca van a cubrir.

**Diferenciador 3:** smwhr es plataforma de 3 capas (verification + social + economy), no solo memoria.

---

## La visión a 3 capas

smwhr no es app, es plataforma con 3 capas que se construyen en secuencia:

1. **Capa 1 — The Record (R0.1, R0.2, R0.3):** verificación + insignias coleccionables
2. **Capa 1.5 — The Long Tail (R0.4, R0.5):** event creation self-serve para organizadores chicos
3. **Capa 2 — The Crowd (R1.0, R1.5):** chats P2P, comunidades, social discovery
4. **Capa 3 — The Economy (R2.0+):** drops post-evento, cashless, marketplace, B2B

Para detalle completo, ver `docs/ROADMAP.md`. Cualquier feature que se considere debe alinearse con la capa correspondiente. Si está fuera del scope del release actual, va al backlog del roadmap.

---

## Quién lo construye

- **Founder:** Moi, operador solo basado en Tulancingo, México. Full-stack engineer con background en Flutter, NestJS, hardware. Studio: Orbit M.
- **Agentes:** Claude Code agents ejecutando en scopes específicos (Backend, Mobile, Landing) bajo este documento.

---

## Estrategia del sprint actual: FRONTEND-FIRST

R0.1 se construye con esta estrategia explícita:

**Días 1-7:** App Flutter completa con datos mock. Repository pattern abstrae todo data access. App navegable end-to-end sin backend real.

**Días 8-12:** Backend NestJS construido contra los contratos definidos por el frontend (`docs/API.md`).

**Días 13-15:** Switch de mocks a real, integración, soft launch.

Para detalle: `docs/FRONTEND_FIRST_STRATEGY.md`.

---

## Reglas fundamentales (no negociables)

### Decisiones de producto

1. **Verificación es el corazón.** Cualquier feature que se pueda falsificar trivialmente no entra. Sin esto, smwhr es Gigs.
2. **El usuario es el héroe visual.** En insignias, fotos y shares, el usuario es el protagonista. El marco es escenario.
3. **Los eventos reales siempre primero.** Nada de quests ficticias, gamificación vacía, check-ins sin substrato físico.
4. **Privacy-by-design.** Cada data point capturado requiere justificación. Locus + geolocator trackean solo durante eventos activos.
5. **Cada release debe sobrevivir solo.** Nunca depender de features futuras. R0.1 es producto completo aunque R0.2 nunca exista.
6. **Estética premium, tono humilde.** smwhr se ve como producto Silicon Valley, habla como amigo cercano.
7. **Multi-vertical es ventaja, no distracción.** Cada vertical se lanza con la misma calidad que el primero.
8. **LATAM cultural antes que global escalable.** Construimos para México primero, expansion LATAM después.

### Decisiones técnicas

1. **Stack fijo:** Flutter + NestJS + Prisma + Supabase + Railway. No cambiar sin escalar a founder.
2. **Frontend-first con Repository pattern:** R0.1 se construye en Flutter primero con mocks. Backend espera.
3. **Dual-track geolocation:** Locus primary + geolocator shadow. Ambos corren en paralelo durante quests.
4. **Verificación sin terceros musicales.** No Spotify, no Apple Music API, no Last.fm. Data propietaria desde el minuto uno.
5. **IP compliance:** uso nominativo factual de nombres de artistas. Cero imágenes de artistas en insignias. Imágenes de eventos vía Ticketmaster API (licenciada).
6. **Cero dependencias de pago que podamos evitar.** SDKs comerciales solo post-tracción.

### Decisiones visuales

1. **Dark mode total.** Fondo negro profundo (#050505). No hay light mode en R0.1.
2. **Magenta neón como único acento.** #FF2D95. Usado con restricción máxima tipo Linear.
3. **Tipografía:** Space Grotesk (display), Inter (body), JetBrains Mono (mono/serial numbers).
4. **Iconografía:** line style, stroke 1.5px, inspiración Phosphor/Lucide/Tabler.
5. **Cero emojis en UI. Cero gradients gratuitos. Cero skeuomorfismo.**

### Decisiones estratégicas

1. **No competir feature-by-feature con AC Momento.** Competir por mercado (LATAM) y por categoría (3 capas vs 1).
2. **No levantar capital hasta R2.0.** Bootstrap con afiliación + smwhr+ + Sponsored Quests.
3. **No expansión a USA/Europa antes de R2.5.** Foco LATAM disciplinado.
4. **No pivots de stack ni de mercado durante el sprint.** Ejecutar lo que está documentado.

---

## Release 0.1 — Scope exacto

**Target:** 5 mayo 2026 (soft launch)
**Evento ancla:** 7, 9, 10 de mayo — tres shows BTS World Tour en Estadio GNP Seguros, CDMX

### IN scope (R0.1)

- Onboarding en 4 pantallas (Auth → Identity → Interests → Permissions)
- Home feed con catálogo de eventos LATAM
- Event detail con preview de insignia locked
- Intent ("I'll be there") por evento
- Quest activa con dual-track tracking (Locus + geolocator)
- Captura de foto in-app con EXIF validation
- Emisión automática de badge post-evento con ReconciliationEngine
- Reveal animado con serial number único
- Perfil público con colección de badges
- Share a Instagram Stories (1080x1920)
- Landing page con waitlist
- Monetización pasiva via Ticketmaster affiliate

### OUT of scope (NO construir en R0.1)

- Social layer (follow, feed de amigos, comentarios) → R1.0
- Mesh networking peer-to-peer → R1.5
- Cashless integration → R2.0
- Dashboard para promotores → R2.0
- Premium tier o monetización adicional → R0.3
- Audio fingerprinting → nunca probablemente
- Export de badges → R0.3
- Import de historial musical → cuestionable
- Beacons físicos → R2.5+
- Apple Music / YouTube Music integration → nunca
- Multi-idioma beyond ES/EN auto-detect
- Light mode
- Event creation UGC → R0.4

Cualquier feature fuera de scope va a `docs/ROADMAP.md`. NO se construye en R0.1 bajo ninguna circunstancia.

---

## Arquitectura dual-track geolocation (crítica)

**Locus = primary tracker** con features avanzadas (polygon geofences, motion recognition, headless execution).

**geolocator = shadow tracker** con timer periódico independiente cada 5 min.

**Ambos corren en paralelo** durante quests activas. Al terminar evento, `ReconciliationEngine` en backend decide qué dataset es ground truth.

**Lógica del engine:**
1. Si Locus es completo y consistente → úsalo
2. Si Locus parcial pero geolocator tiene data suficiente → fallback a geolocator
3. Si ambos tienen data → cross-validar. Alto agreement usa Locus + bonus. Divergencia usa el más conservador con penalización.
4. Si nada suficiente → marca como no verificado

Ver `docs/ARCHITECTURE.md` sección 3 para implementación completa.

---

## Documentos canónicos del proyecto

Estos documentos son la fuente de verdad. Si hay duda, leerlos antes de actuar:

| Documento | Propósito | Cuándo leerlo |
|-----------|-----------|---------------|
| `CLAUDE.md` (este) | Constitución | Siempre primero |
| `docs/ROADMAP.md` | Visión 3 años | Decisiones estratégicas |
| `docs/ARCHITECTURE.md` | Arquitectura técnica | Decisiones de implementación |
| `docs/FRONTEND_FIRST_STRATEGY.md` | Estrategia de implementación | Día a día del sprint |
| `docs/ONBOARDING_FLOW.md` | Specs detalladas onboarding | Construyendo pantallas 01-04 |
| `docs/API.md` | Contratos de API | Frontend o backend interactuando |
| `docs/CLAUDE_CODE_SETUP.md` | Setup para agentes | Iniciando un agente |
| `apps/api/CLAUDE.md` | Backend specifics | Backend Agent only |
| `apps/mobile/CLAUDE.md` | Mobile specifics | Mobile Agent only |
| `apps/landing/CLAUDE.md` | Landing specifics | Landing Agent only |
| `scripts/DAY_1_CHECKLIST.md` | Día 1 hora por hora | El primer día del sprint |

---

## Comunicación entre agentes

Cada agente tiene scope específico:

- **Backend Agent:** `apps/api/*` — lee `apps/api/CLAUDE.md`
- **Mobile Agent:** `apps/mobile/*` — lee `apps/mobile/CLAUDE.md`
- **Landing Agent:** `apps/landing/*` — lee `apps/landing/CLAUDE.md`

**Regla de oro:** si una tarea toca más de un scope, PARA y escala al founder. No improvises cross-boundary.

**Protocolo de commits:**
- Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`
- Commits pequeños y frecuentes
- Nunca commits con `console.log`, `print`, `debug` residual
- Nunca commits con credenciales (`.env` está en `.gitignore`)

**Protocolo de decisiones:**
- Si aparece ambigüedad en requirement, PREGUNTA antes de asumir
- Si aparece oportunidad de mejora fuera de scope, documenta en `docs/ROADMAP.md` pero NO lo implementes
- Si algo en este documento te parece incorrecto, escala al founder para actualizar el documento ANTES de desviarte

---

## Gates de decisión del sprint

- **Gate 1 (Día 5):** dual-track + reconciliation funcionan end-to-end → si no, simplificar o retrasar
- **Gate 2 (Día 7):** frontend completo navegable con mocks → si no, evaluar scope cut
- **Gate 3 (Día 12):** backend integrado con frontend, app real funcional → si no, retrasar lanzamiento
- **Gate 4 (4 mayo):** 50+ descargas soft launch → si no, revisar comunicación
- **Gate 5 (11 mayo):** 100+ badges verified post-BTS → si no, root cause antes de R0.2

---

## Anti-patterns que NUNCA se hacen

- ❌ Scope creep ("mientras estamos aquí, agreguemos...")
- ❌ Premature optimization (optimizar algo antes de tener data real)
- ❌ Stack hopping (cambiar tecnología a mitad de sprint)
- ❌ Perfectionism sobre deadline (pulir en vez de enviar)
- ❌ Mock data en producción (todo seed data marcado claramente)
- ❌ Hardcoded secrets (todo vía env vars)
- ❌ Inventar requirements cuando hay ambigüedad (siempre preguntar)
- ❌ Asumir conocimiento previo del founder sobre lo que hizo otro agente
- ❌ Reabrir decisiones cerradas (stack, design tokens, scope R0.1)
- ❌ Replicar features de Momento por reacción competitiva
- ❌ Llamadas HTTP directas en widgets Flutter (siempre via Repository)
- ❌ Hardcoded colors o sizes en widgets (siempre via AppColors/AppSpacing)
- ❌ NFTs, crypto tokens, ads invasivos, ticketing transaccional propio

---

## Filosofía final

smwhr se lanza el 5 de mayo 2026. Lo que exista ese día es el producto. Lo que no exista, no existe. La disciplina de execution > perfection es el único camino.

Pero también: **smwhr es proyecto a 3-5 años**, no a 15 días. R0.1 es ladrillo, no edificio. La visión completa (3 capas, LATAM, long tail, social, economy) vive en `docs/ROADMAP.md` y se construye release por release.

Ship small, ship often, ship on time. Y nunca pierdas de vista que estás construyendo algo que va a importar para personas reales que se mueven, salen, y viven momentos que merecen ser registrados.

*"You were somewhere." — y smwhr estará ahí para probarlo.*
