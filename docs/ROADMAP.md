# smwhr — Product Roadmap

**Versión:** v1.0
**Última actualización:** 22 abril 2026
**Owner:** Moi (Founder, Orbit M)

Este documento es la fuente canónica de la dirección estratégica de smwhr. Se actualiza trimestralmente o cuando una decisión mayor cambia el plan. Si una feature no está aquí, no existe aún en el roadmap formal.

---

## Visión a 3-5 años

smwhr es la infraestructura de vida social en eventos en vivo para LATAM. Conectamos a personas que físicamente se encuentran en el mismo lugar al mismo tiempo, transformamos sus asistencias en memoria coleccionable verificada, y desbloqueamos economías nuevas alrededor de la presencia real.

**Tagline actual:** *"You were somewhere."*
**Tagline aspiracional (2028):** *"The platform for people who show up."*

**Mercado primario:** México (CDMX, GDL, MTY, Tulum, ciudades medias).
**Expansión LATAM (2027+):** Argentina, Colombia, Chile, España.
**Expansión global (2028+):** solo si tracción LATAM lo justifica.

---

## Arquitectura del producto — 3 capas

smwhr no es una app. Es una plataforma con tres capas que se construyen en secuencia pero operan juntas una vez maduras.

### Capa 1 — The Record

**Qué es:** verificación de asistencia + insignias coleccionables.
**Propósito:** hook emocional y punto de entrada. Resuelve *"quiero tener prueba de lo que viví"*.
**Releases:** R0.1, R0.2, R0.3

### Capa 1.5 — The Long Tail

**Qué es:** event creation self-serve para organizadores pequeños.
**Propósito:** expandir mercado de "eventos Ticketmaster-grade" a "cualquier momento colectivo". Resuelve *"mi bar / mi torneo / mi excursión merecen insignias también"*.
**Releases:** R0.4, R0.5

### Capa 2 — The Crowd

**Qué es:** sociedad y conexión entre asistentes.
**Propósito:** transformar eventos de experiencia solitaria a experiencia compartida. Resuelve *"quiero conocer a los que sí estuvieron"*.
**Releases:** R1.0, R1.5

### Capa 3 — The Economy

**Qué es:** monetización profunda sobre data de asistencia verificada.
**Propósito:** infraestructura de comercio con fans reales. Resuelve *"mi historial de asistencia debe darme acceso a cosas exclusivas"*.
**Releases:** R2.0+

---

## Release 0.1 — Music [MAYO 2026]

**Fecha target:** 5 mayo 2026 (soft launch), 7 mayo (hero event BTS en Estadio del Centro CDMX)
**Scope mental:** Capa 1 en su forma más pura, categoría única, validación técnica de verificación.

### IN scope
- Onboarding 4 pantallas (Auth → Identity → Interests → Permissions)
- Home feed con catálogo Ticketmaster México (música)
- Event detail con preview de insignia locked
- Intent ("I'll be there")
- Quest activa con dual-track geolocation (Locus + geolocator)
- Captura de foto in-app con EXIF validation
- Emisión automática de badge post-evento con ReconciliationEngine
- Reveal animado con serial number único
- Perfil público con colección de badges
- Share a Instagram Stories (1080x1920)
- Landing page con waitlist
- Monetización via Ticketmaster affiliate (pasivo, $0 setup)

### OUT of scope
Ver `CLAUDE.md` raíz sección "Qué NO está en scope de R0.1". Foco absoluto en verificación y primera experiencia de badge.

### Gates de decisión
- **Día 5:** dual-track funcionando end-to-end
- **Día 6:** flow completo en device real
- **4 mayo:** 50+ descargas soft launch
- **11 mayo post-BTS:** 100+ badges verified

### Métricas de éxito
- 500-1,500 usuarios registrados en primeras 2 semanas
- 100-300 badges verified emitidas en ventana BTS
- Retention D7 ≥ 30%
- Agreement score promedio Locus vs geolocator ≥ 0.85
- App Store rating ≥ 4.5

### Aprendizajes críticos a extraer
- ¿Dual-track funciona en devices mexicanos reales (Xiaomi, Samsung, iPhone)?
- ¿El umbral de 60 min de dwell time es correcto o bajo?
- ¿Usuarios entienden "quest" como concepto o confunde?
- ¿Share rate a Instagram Stories es >15%?

---

## Release 0.2 — Sports [JUNIO 2026]

**Fecha target:** 4 junio 2026 (antes del Mundial)
**Scope mental:** validar que el producto funciona multi-vertical sin re-arquitectura.

### IN scope nuevo
- Categoría Sports activada en feed
- Integración con Liga MX (via Ticketmaster + SofaScore API)
- Cobertura completa del Mundial 2026 (sede México)
- Templates de insignia para deportes (verde ambient, iconografía de estadio)
- Notifications mejoradas (marcador final, alerta de overtime, etc.)

### IN scope expansivo
- Mejoras iterativas basadas en feedback R0.1
- Fix de bugs conocidos de R0.1
- Optimización de batería del dual-track

### OUT of scope
- Social layer (aún)
- Event creation UGC (aún)
- Cashless (aún)

### Hero event
**Mundial 2026 — apertura 11 junio en Estadio Azteca**. Máxima oportunidad de adquisición orgánica de usuarios mexicanos. Target: 10,000+ usuarios nuevos en ventana Mundial.

### Métricas de éxito
- 5,000-15,000 usuarios totales al cierre de R0.2
- 1,000+ badges de partidos Mundial
- Retention D30 ≥ 25%
- Churn negativo entre R0.1 → R0.2 (los de R0.1 deberían reactivarse)

---

## Release 0.3 — Festivals [AGOSTO 2026]

**Fecha target:** 1 agosto 2026 (antes de Corona Capital + Bahidorá 2026 temporada festiva)
**Scope mental:** consolidar Capa 1 completa, introducir monetización premium.

### IN scope nuevo
- Categoría Festivals completa
- Cobertura de festivales mexicanos: Corona Capital, Vive Latino, Pa'l Norte, Hipnosis, Bahidorá, Ceremonia
- Multi-day events (badge por día + badge consolidado del festival)
- Timeline del festival con set times
- **smwhr+ launch** (suscripción premium $59-99 MXN/mes)
    - Variantes de frames edición limitada
    - Analytics personales "Your Year So Far"
    - Export alta resolución
    - Badge "FOUNDER" para early subscribers
- Cobertura outdoor básica (ciclismo, running, senderismo popular)

### IN scope expansivo
- Onboarding optimizado con A/B tests de R0.1-R0.2
- Fix de patrones de uso no anticipados

### OUT of scope
- Chats P2P (R1.0)
- Comunidades (R1.0)
- Event UGC (R0.4)

### Hero events
- Corona Capital (17-19 octubre 2026)
- Bahidorá (febrero 2027)
- Vive Latino (marzo 2027)

### Métricas de éxito
- 20,000-40,000 usuarios activos
- 3-5% conversión a smwhr+ = 600-2,000 suscriptores
- MRR $50,000-150,000 MXN
- 2+ Sponsored Quests firmadas para hero festivales

---

## Release 0.4 — Event Creation (Long Tail) [SEPTIEMBRE 2026]

**Fecha target:** 15 septiembre 2026
**Scope mental:** apertura del mercado 100x — de eventos oficiales a cualquier evento real.

### Por qué esta capa es estratégica

Momento y competidores globales dependen de licencias con proveedores de data (JamBase, SportRadar). Solo pueden cubrir eventos "oficiales" con presencia en esos catálogos. El bar de barrio con su noche de jazz, el torneo amateur de fútbol, la rave itinerante, la boda, el cumpleaños temático, el retiro de yoga — todo eso es invisible para ellos.

smwhr con Capa 1.5 se vuelve accesible a cualquier persona que organice cualquier momento colectivo. Esto no es incremental — es una **expansión categórica** que cambia el TAM del producto.

### IN scope nuevo
- **Event creation self-serve:**
    - Flow de creación en app para cualquier usuario
    - Campos mínimos: título, venue, fecha, hora, categoría, geofence (mapa tap)
    - Opción de "evento privado" (solo con link) o "público" (aparece en discovery por cercanía)
- **Template engine constrained:**
    - 15-20 templates oficiales de frames por categoría
    - Cero upload de imágenes custom como frame (estética protegida)
    - Opciones: paleta ambient, nombre del evento, logo del organizador (con guardrails)
- **Badge de "Community Event":**
    - Insignias de eventos UGC visualmente distinguibles de oficiales
    - Badge tag "Community" vs "Verified Event" (como Twitter blue check)
- **Anti-fraud básico:**
    - Eventos con único asistente: insignia emitida pero con tag "Participated" no "Verified"
    - Eventos con <3 asistentes verificados: misma lógica
    - Threshold ajustable por backend según aprendizajes
- **Organizer profile básico:**
    - Usuario que crea eventos tiene sub-perfil de organizer
    - Stats: eventos creados, asistentes totales, rating promedio

### IN scope expansivo
- Discovery local: "eventos cerca de ti esta semana"
- Filtros de búsqueda por categoría + ciudad
- Bookmarking de eventos

### OUT of scope
- Custom frames completamente libres (R1.5)
- Trusted Organizer tier (R1.0)
- Monetización de event creation (R2.0)

### Riesgos a mitigar
- **Spam/fraude:** reports + moderación + thresholds automáticos
- **Calidad visual:** templates constrained, nunca free-form
- **Legal:** TOS claro sobre uso aceptable, DMCA process

### Métricas de éxito
- 500+ eventos creados en primer mes
- 30% de nuevos usuarios provienen de links de eventos UGC
- <5% de eventos flagged como fraudulentos
- Rating promedio de organizers ≥ 4.2

---

## Release 0.5 — Organizer Tools [OCTUBRE 2026]

**Fecha target:** 20 octubre 2026
**Scope mental:** los organizers activos merecen herramientas, no solo una interfaz de creación.

### IN scope nuevo
- **Organizer dashboard:**
    - Lista de eventos pasados y futuros
    - Analytics por evento (asistentes verificados, demographics agregados anónimos, rating)
    - Feed de feedback de asistentes (texto opcional post-event)
- **Trusted Organizer tier:**
    - Criterios: 5+ eventos exitosos, rating ≥ 4.3, <2% fraud reports
    - Beneficios: insignia "Trusted Organizer" en perfil, prioridad en discovery, acceso a custom frames (preview R1.5)
- **Event duplication:**
    - "Repetir evento" para eventos recurrentes (ej: noche semanal en un bar)
    - Templates personales guardados
- **Asistentes tagging:**
    - Organizer puede etiquetar roles (DJ, staff, bartender) con insignias especiales
    - Reconocimiento público de contribuidores al evento

### OUT of scope
- Ticketing integrado (R2.0)
- Facturación a organizers (R2.0)
- Custom branding completo (R1.5)

### Métricas de éxito
- 10% de creadores activos son "Trusted Organizers"
- Retention de organizers ≥ 60% mes a mes
- Eventos recurrentes representan 30%+ del total

---

## Release 1.0 — The Crowd [Q4 2026]

**Fecha target:** 1 diciembre 2026
**Scope mental:** smwhr deja de ser solo colección individual y se vuelve red social basada en asistencia real.

### IN scope nuevo
- **Communities per event:**
    - Cada evento tiene feed de posts de asistentes verificados
    - Fotos, videos, texto, reacciones
    - Moderación automática + manual
    - Comunidades quedan activas post-evento para nostalgia compartida
- **Tagging de amigos:**
    - En el badge post-evento, puedes etiquetar a quienes fueron contigo
    - Los tagged reciben notificación + opción de verificar ellos también
- **Follow / Follower graph:**
    - Perfiles privados o públicos (opcional)
    - Feed de actividad de amigos
- **Discovery de fans:**
    - "Otros fans que vienen a este evento"
    - Match con usuarios con gustos similares basado en historial de eventos
- **Chats 1-to-1:**
    - Mensajería privada entre usuarios conectados
    - No en grupos todavía
- **Sponsored Quests (monetización B2B):**
    - Marcas patrocinan categorías de eventos con badge edition especial
    - Formato: 1-3 campañas activas a la vez, curado

### IN scope expansivo
- Push notifications de actividad social
- Deeplinks y share mejorado

### OUT of scope
- Chats P2P en festivales (R1.5 — requiere infraestructura técnica distinta)
- Mesh networking (R2.0+)
- Cashless (R2.0)

### Por qué ahora y no antes

Agregar social antes de tener 20,000 usuarios activos crea un "empty restaurant" effect. Con R0.3 alcanzamos densidad suficiente para que communities sean vivas desde día uno. Antes de eso, el social layer se siente vacío.

### Métricas de éxito
- 50,000+ usuarios activos totales
- 40%+ de usuarios publican en al menos una community
- DAU/MAU ≥ 25% (señal de engagement social real)
- $200-500k MXN MRR entre smwhr+ y Sponsored Quests

---

## Release 1.5 — Custom Branding + Festival Features [Q1 2027]

**Fecha target:** marzo 2027
**Scope mental:** unlockear herramientas profesionales para organizers serios + chats P2P para festivales grandes.

### IN scope nuevo
- **Custom frames para Trusted Organizers:**
    - Editor de frame con design system constrained (tipografías oficiales, paletas aprobadas)
    - Preview en tiempo real
    - Moderación manual antes de activar
- **Festival mode:**
    - Map interactivo del festival en app
    - Set times + notificaciones de artistas favoritos
    - **Chats P2P mesh para cuando cobertura celular satura** (via WiFi Direct o Nearby Connections)
    - Meetup points con amigos
- **Grupos en chats:**
    - Crear grupos por evento o custom
    - Share de fotos grupales, quedadas
- **Organizer Pro tier:**
    - Suscripción mensual para organizers ($500-1,500 MXN/mes)
    - Analytics avanzados, export de data de asistentes (con consent), email campaigns a asistentes pasados

### OUT of scope
- Cashless (R2.0)
- Marketplace (R2.0)
- Ticketing integrado (R2.0)

### Hero context
- Festivales de primavera 2027 (Vive Latino, Pa'l Norte, Tecate Emblema)
- Temporada alta de conciertos con artistas internacionales

### Métricas de éxito
- 100+ Trusted Organizers activos con custom frames
- 20%+ de festivals users usan chats P2P durante eventos
- 50+ Organizer Pro suscriptores

---

## Release 2.0 — The Economy [Q3 2027]

**Fecha target:** agosto 2027
**Scope mental:** smwhr se vuelve infraestructura económica real, no solo app de memorias.

### IN scope nuevo
- **Drops post-evento:**
    - Artistas/eventos venden merch limitado solo a verified attendees
    - Marketplace integrado con payment processor (Mercado Pago, Conekta)
    - Comisión smwhr: 10-15%
- **Cashless para partners:**
    - Wallet interno vinculado a tarjeta del usuario
    - Compra en bares de venues partners sin salir del app
    - Comisión smwhr: 2-3% por transacción
- **Preventas exclusivas:**
    - Verified attendees de shows pasados de un artista acceden a preventa del próximo tour
    - Integración con ticketing partners
- **B2B Event Hosting:**
    - Producto formal vendido a promotores: "smwhr as your event platform"
    - Pricing: $15-30 MXN por asistente verificado
    - Data completa, dashboard, branding co-oficial
- **Data licensing agregada:**
    - Insights anónimos vendidos a marcas, venues, promotores
    - Strict opt-in, full anonymization

### OUT of scope
- Emisión de tokens / crypto (no es nuestro juego)
- NFTs transferibles (no ese camino)
- International expansion aggressive (sigue LATAM-first)

### Métricas de éxito
- $2M+ USD ARR
- 200,000+ usuarios activos mensuales
- 30+ eventos B2B hosted
- 5+ marcas con partnerships recurrentes

---

## Release 2.5+ — Platform [2028+]

**Fecha target:** 2028
**Scope mental:** smwhr se vuelve infraestructura que otros construyen encima.

### Potencial scope
- **API pública:** otras apps integran "Verified Attendance" como servicio
- **White label:** promotores licencian la tech con su propio branding
- **Hardware integration:** beacons, wristbands, wearables en partnership
- **Expansión LATAM completa:** Colombia, Argentina, Chile, Perú, España
- **Adyacencias:** outdoor exploration, travel verification, sports leagues amateur

### Decisión de inflexión
En R2.5 decidimos: ¿levantamos serie A y agresivo crecimiento, o mantenemos rentabilidad con crecimiento orgánico?

Criterios para serie A:
- ≥ 500k usuarios activos mensuales
- ≥ $5M USD ARR con crecimiento >100% YoY
- Unit economics claros (CAC < LTV/3)
- Ventana competitiva abierta (Momento no entra a LATAM seriamente)

---

## Principios de decisión estratégica

Estos principios gobiernan cualquier duda entre releases. Si una propuesta los viola, no entra.

### 1. LATAM-first, no LATAM-only
Enfoque cultural en México y LATAM, pero arquitectura que no nos encasille. Si un fan español quiere crear cuenta y tracker eventos en Madrid, puede hacerlo. No construimos muros geográficos.

### 2. Verificación antes que volumen
Prefiero 1,000 badges verificadas reales sobre 100,000 auto-reportes falsos. El core de confianza no se negocia por métricas de vanidad.

### 3. Diseño premium, mercado popular
smwhr se ve como Linear/Arc pero está diseñado para funcionar para un asistente de un festival rave en Tepoztlán, no solo para un tech worker de CDMX. Estética aspiracional, accesibilidad real.

### 4. Self-serve siempre que sea posible
Evitamos modelos que requieran sales manual o onboarding asistido. El producto debe ser instalable y funcional sin intervención humana del lado de smwhr.

### 5. Privacy-by-design, no opt-out
Cada feature nueva se diseña con la pregunta *"¿qué data mínima necesita para funcionar?"*. Default settings = máxima privacy. El usuario elige compartir más, no menos.

### 6. Lanzar con imperfección antes que retrasar por pulir
Un producto feo pero funcional que lanza a tiempo gana a uno hermoso que llega tarde. Excepción: errores que rompan confianza (fraude, privacy leaks, badges incorrectos) nunca se lanzan.

### 7. Construir moats a través de data propietaria
Cada asistencia verificada es un punto de data que Momento nunca tendrá. Nuestro moat se compone por acumulación, no por features flashy.

### 8. No competir por features, competir por mercado
No intentamos tener feature parity con Momento. Intentamos tener soberanía cultural y operacional en LATAM. Son juegos distintos.

### 9. Revenue diversificado desde temprano
Afiliación desde R0.1, smwhr+ en R0.3, Sponsored Quests en R1.0, B2B en R2.0. Nunca depender de una sola fuente de ingresos.

### 10. La visión no se sacrifica por el sprint
Cuando ejecuto R0.1 me enfoco en R0.1. Cuando decido roadmap miro la visión. Las dos coexisten pero no se mezclan.

---

## Cosas que NUNCA haremos (mejor documentado que debatido cada vez)

- ❌ NFT marketplace con crypto nativa
- ❌ Ads invasivos en feed o insignias
- ❌ Tokens transferibles / economía especulativa
- ❌ Compra de data de usuarios sin consent explícito
- ❌ Replicar a Momento feature por feature
- ❌ Ticketing transaccional propio (Ticketmaster/Ocesa lo hacen bien, somos partners no competencia)
- ❌ Streaming de eventos en vivo (es otro negocio)
- ❌ Cobrar a asistentes por crear perfil
- ❌ Gating de insignias básicas detrás de paywall
- ❌ Algoritmo de feed optimizado para engagement adictivo

---

## Cronograma visual resumen

```
2026
├── Abr-May   R0.1 Music (BTS hero)
├── Jun       R0.2 Sports (Mundial hero)
├── Jul-Ago   R0.3 Festivals + smwhr+ launch
├── Sep       R0.4 Event Creation (Long Tail)
├── Oct       R0.5 Organizer Tools
└── Nov-Dic   R1.0 The Crowd (social)

2027
├── Q1        R1.5 Custom Branding + Festival Features
├── Q2        Consolidación + preparación R2.0
└── Q3-Q4     R2.0 The Economy

2028+
└── R2.5+ Platform mode + expansión LATAM completa
```

---

## Criterios de decisión para levantar capital

Por default, smwhr se construye bootstrapped hasta R2.0. Revenue + smwhr+ + Sponsored Quests + B2B deberían sostener operación.

**Levantamos capital solo si se cumple lo siguiente:**

1. Oportunidad de mercado con ventana temporal (ej: si Momento entra agresivamente a LATAM y necesitamos defender rápido)
2. Unit economics probados y necesidad real de acelerar CAC
3. Founder tiene claridad de qué hacer con cada dólar (no capital como validación externa)
4. Términos que mantienen control (founder friendly, no crushing prefs)

Ronda teórica si pasa todo lo anterior: **seed $1-2M USD a $15-25M valuation** en 2027 post-R1.0 con tracción probada.

---

## Notas de reflexión estratégica

### Sobre AC Momento

Momento es el competidor más parecido en el mundo. Pero opera en USA + Europa, cubre solo eventos "oficiales", y tiene modelo retrospectivo (recordar lo pasado). smwhr opera LATAM-first, cubre el long tail, y tiene modelo presente-futuro (mejorar la experiencia viva, la memoria es resultado).

La coexistencia es posible durante años. Si Momento entra a LATAM agresivamente, para entonces tenemos moat local construido.

### Sobre Festiverse

smwhr nace como evolución de la idea original de Festiverse pero con enfoque más profundo: verificación real en vez de self-reporting, y expansión más allá de festivales a cualquier evento en vivo.

### Sobre Orbit M y el ecosistema

smwhr es un producto del estudio Orbit M. Las otras ventures (Notabl, URBM) no bloquean smwhr pero tampoco lo subsidian. Cada producto corre su propio track. Sin embargo, las capacidades se comparten: la experiencia con hardware (URBM) puede servir para futuros dispositivos smwhr (beacons, wearables); la experiencia fintech (Notabl) puede servir para cashless de R2.0.

---

*Este roadmap es documento vivo. Se actualiza cuando la realidad cambia el plan. Pero también es compromiso: lo que está aquí es lo que construimos, en ese orden, salvo excepción justificada.*

*"You were somewhere — y smwhr estará ahí para probarlo."*
