# smwhr — Claude Code Setup Guide

Guía completa para configurar Claude Code (app de escritorio) y arrancar el sprint frontend-first.

---

## Pre-requisitos antes de abrir Claude Code

### En tu máquina debes tener:

```bash
# Verifica con estos comandos:
node --version    # >= 20.x
pnpm --version    # >= 9.x
git --version     # cualquier versión reciente
flutter --version # >= 3.24
```

### Si falta algo:

```bash
# Node
brew install node@20

# pnpm
npm install -g pnpm

# Flutter
brew install --cask flutter

# Verifica Flutter doctor
flutter doctor
```

Resuelve cualquier ❌ en `flutter doctor` antes de continuar. Especialmente:
- Xcode (para iOS): instala desde App Store
- Android Studio (para Android emulator): https://developer.android.com/studio
- iOS Simulator
- Android emulator con AVD configurado

### Claude Code app de escritorio

1. Descargar de https://claude.ai/download
2. Login con cuenta Anthropic (necesitas plan Pro/Team/Max)
3. Verifica que ves "Claude Code" en sidebar

### VS Code con extensiones

Instala estas extensiones:
- Claude Code (oficial Anthropic)
- Dart (Dart-Code.dart-code)
- Flutter (Dart-Code.flutter)
- ESLint
- Prettier
- GitLens
- Thunder Client
- Error Lens
- Better Comments

---

## Setup del proyecto

### Paso 1: Clonar y descomprimir starter kit

```bash
mkdir -p ~/Code
cd ~/Code

# Clonar repo (si ya lo creaste en GitHub)
git clone git@github.com:orbit-m/smwhr.git
cd smwhr

# Descomprimir starter kit
tar -xzf ~/Downloads/smwhr-starter-kit-v2.tar.gz -C .

# Verificar estructura
ls -la
# Deberías ver: CLAUDE.md, apps/, docs/, prisma/, scripts/, .env.example
```

### Paso 2: Configurar VS Code workspace

Crear `.vscode/settings.json`:

```json
{
  "editor.formatOnSave": true,
  "[dart]": {
    "editor.defaultFormatter": "Dart-Code.dart-code",
    "editor.formatOnSave": true,
    "editor.rulers": [80]
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "files.exclude": {
    "**/.dart_tool": true,
    "**/build": true,
    "**/.next": true,
    "**/node_modules": true,
    "**/dist": true
  }
}
```

Crear `.vscode/extensions.json`:

```json
{
  "recommendations": [
    "anthropic.claude-code",
    "Dart-Code.dart-code",
    "Dart-Code.flutter",
    "Prisma.prisma",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "eamodio.gitlens",
    "rangav.vscode-thunder-client",
    "usernamehw.errorlens"
  ]
}
```

### Paso 3: Bootstrap Flutter app

```bash
cd apps/mobile
flutter create --org quest.smwhr --project-name smwhr .

# Si pregunta sobre overwrite, di yes a todo

# Verifica que compila
flutter pub get
flutter run -d chrome
```

Si el último comando abre una ventana en Chrome con app vacía de Flutter, perfecto. Cierra y continúa.

---

## Abrir Claude Code app de escritorio

### Iniciar nueva conversación con contexto

1. **Abre Claude Code app**
2. **New conversation**
3. **Add folder context** → selecciona `~/Code/smwhr/apps/mobile/`
4. **Add files** (uno por uno):
   - `~/Code/smwhr/CLAUDE.md`
   - `~/Code/smwhr/apps/mobile/CLAUDE.md`
   - `~/Code/smwhr/docs/ARCHITECTURE.md`
   - `~/Code/smwhr/docs/ROADMAP.md`
   - `~/Code/smwhr/docs/FRONTEND_FIRST_STRATEGY.md`
   - `~/Code/smwhr/docs/ONBOARDING_FLOW.md`
5. **Si tienes los PNGs de mocks:** adjunta también los 6 PNGs de `~/Code/smwhr/design/mocks/v1/`

### Prompt de inicialización (copia y pega exacto)

```
Hola. Soy Moi, founder de smwhr. Eres mi Mobile Agent dedicado, working en apps/mobile/.

CONTEXTO CRÍTICO:

Estoy lanzando smwhr el 5 de mayo 2026 con BTS World Tour como hero event el 7 de mayo. Tengo 15 días para construir todo. Vamos con estrategia frontend-first.

ANTES DE HACER NADA, lee y memoriza estos documentos en ESTE orden exacto:

1. CLAUDE.md (raíz del proyecto) — constitución no negociable
2. apps/mobile/CLAUDE.md — tus instrucciones específicas
3. docs/ARCHITECTURE.md — arquitectura técnica completa con dual-track geolocation
4. docs/ROADMAP.md — visión de 3 capas y 9 releases
5. docs/FRONTEND_FIRST_STRATEGY.md — la estrategia que vamos a seguir HOY
6. docs/ONBOARDING_FLOW.md — specs detalladas del onboarding
7. Las 6 PNGs en design/mocks/v1/ — tu source of truth visual

ESTRATEGIA:

Frontend-first con live mocks. Esto significa:

- Construyes TODA la app Flutter completa visualmente, navegable end-to-end
- Usa Repository Pattern para abstraer data sources
- Implementa MockEventRepository, MockAuthRepository, MockQuestRepository, MockBadgeRepository, MockUserRepository
- Toda data viene de mocks locales con latencia simulada realista
- Cuando esté el backend (Día 8), solo cambiamos el provider, cero refactor de UI
- Para correr: flutter run --dart-define=USE_MOCKS=true

PRIORIDADES:

1. Design system completo (colors, typography, spacing) basado en mocks
2. Theme dark con magenta neón
3. Router con go_router
4. Pantalla 01 Splash/Auth funcional con mock auth
5. Pantallas 02-04 Onboarding completo
6. Home feed con eventos mock LATAM
7. Event detail con preview de badge locked
8. Active Quest screen con timer mock corriendo en tiempo real
9. Camera screen con frame overlay
10. Reveal screen con animación
11. Profile + Collection + Share

REGLAS NO NEGOCIABLES:

- Cero hardcoded colors o sizes en widgets, todo via AppColors/AppSpacing
- Cero llamadas HTTP directas en widgets, todo via Repository
- Stateless por default, StatefulWidget solo cuando absolutamente necesario
- Riverpod para todo state compartido
- go_router para toda navegación
- Tipografías: Space Grotesk (display), Inter (body), JetBrains Mono (mono)
- Único color de acento: #FF2D95 magenta neón
- Background: #050505 negro casi puro
- Iconografía line style 1.5px stroke

PRIMER OUTPUT QUE NECESITO DE TI:

Después de leer todo, dame:

1. Tu plan completo de implementación dividido en sesiones de 4 horas para los próximos 7 días
2. Las 5 primeras tareas concretas que vas a ejecutar HOY (Día 1)
3. Cualquier ambigüedad o decisión que necesites que yo resuelva antes de empezar
4. Tu lectura del estado actual de apps/mobile/ (qué existe, qué falta)

NO ejecutes código todavía. Solo plan, preguntas, y resumen de tu entendimiento.

Empezamos.
```

### Qué esperar como respuesta del agente

El agente debe responder con:

1. **Resumen de su entendimiento del proyecto** (3-5 párrafos)
2. **Plan de 7 días** desglosado por bloques de 4 horas
3. **5 primeras tareas concretas** con sub-pasos
4. **Preguntas/ambigüedades** si las hay
5. **Estado actual del código** (qué encontró en apps/mobile/)

Si la respuesta no incluye estos 5 elementos, pídeselos explícitamente. No avances sin tener este nivel de claridad inicial.

---

## El loop de trabajo diario

### Estructura de cada día durante el sprint

```
07:30  Wake up, café, no pantallas todavía
08:00  Abre Claude Code, retomas conversación
08:15  Recap de lo logrado ayer + plan de hoy
08:30  Primera tarea concreta del día
12:00  Lunch break (no negociable, 60 min mínimo)
13:00  Resume con segunda tarea
17:00  Review del día, commit y push
18:00  Cena, ejercicio o paseo
19:30  Si hay energía: planning del siguiente día
21:30  Lights off, no más código
```

### Patrones de prompts exitosos

#### Patrón 1: Tarea con scope claro

```
Vamos a implementar el design system completo.

Tareas en orden, parando después de cada una para validar:

1. Crea apps/mobile/lib/core/theme/app_colors.dart con todos los colores de los design tokens del CLAUDE.md
2. Crea app_typography.dart con las 8 variantes definidas
3. Crea app_spacing.dart con la escala 4-8-12-16-24-32-48-64
4. Crea app_theme.dart que componga ThemeData dark
5. Configura main.dart con MaterialApp.router

Después de cada archivo, muéstramelo antes de avanzar al siguiente. NO inventes valores que no estén en los docs.
```

#### Patrón 2: Bug investigation

```
Tengo un problema: el botón "Continue" en la pantalla 02 Identity no se habilita aunque los 3 campos están llenos y válidos.

Investiga el bug en este orden:

1. Lee identity_screen.dart
2. Lee onboarding_state.dart provider
3. Lee la lógica de validación
4. Identifica dónde está el bug
5. Propón fix sin implementarlo

Quiero entender el bug antes de fixearlo.
```

#### Patrón 3: Decisión de diseño

```
Estoy dudando entre dos approaches para el quest timer:

Option A: usar AnimatedBuilder con Ticker que repinta cada segundo
Option B: usar Riverpod con Stream<Duration> que emite cada segundo

Pros y contras de cada uno considerando:
- Performance (queremos minimum jank)
- Testabilidad (queremos poder testear sin Tickers reales)
- Consistencia con el resto del codebase (estamos usando Riverpod everywhere)

Dame tu recomendación con razonamiento, no solo elijas.
```

### Anti-patrones que matan productividad

❌ **Tareas vagas:** "Implementa el módulo de auth"
✅ **Tareas concretas:** "Crea el AuthRepository abstract class con 5 métodos: signInWithApple, signInWithGoogle, requestEmailMagicLink, verifyEmailToken, signOut"

❌ **Mezclar features en una sesión:** auth + events + camera todo junto
✅ **Una conversación = una feature:** terminar auth completamente antes de tocar events

❌ **Aceptar código sin review:** "Listo!" → next task
✅ **Review obligatorio:** leer diff completo, validar contra mocks, validar contra CLAUDE.md

❌ **Permitir reabertura de decisiones:** "Y si usamos Drizzle en vez de Prisma?"
✅ **Hacer cumplir el CLAUDE.md:** "El stack está cerrado. Lee el CLAUDE.md raíz."

---

## Comandos esenciales de Claude Code

```
# Dentro de la app de escritorio
/help              # Comandos disponibles
/clear             # Limpiar historial de la conversación actual
/cost              # Ver tokens usados
/model             # Cambiar Sonnet ↔ Opus
/review            # Pedir code review
/compact           # Comprimir contexto cuando se llena
```

### Cuándo usar Sonnet vs Opus

**Sonnet (default, más rápido y barato):**
- Boilerplate (widgets, providers, models)
- Refactor mecánico
- Generación de tests unitarios
- Documentation
- Bug fixes obvios
- CRUD operations

**Opus (cuando importa la calidad):**
- Decisiones arquitectónicas
- Debugging complejo
- Algoritmos no triviales (verification scoring, reconciliation)
- Code review profundo
- Refactor grandes
- Diseño de APIs

Comando para cambiar: `/model opus` o `/model sonnet`

---

## Manejo de bloqueos

### Si Claude Code se atora 3 veces en lo mismo

**No insistas.** Después de 3 intentos fallidos, escala:

1. Abre nueva pestaña en Chrome
2. Ve a https://claude.ai/chat
3. Inicia conversación con Claude Opus 4.7
4. Pega contexto: el bug, los 3 intentos fallidos, los archivos relevantes
5. Pídele análisis profundo
6. Regresa a Claude Code con la solución/dirección

### Si pierdes contexto en una conversación larga

Síntomas:
- El agente "olvida" decisiones tomadas antes
- Repite código ya generado
- Inventa nombres de archivos que no existen

Solución: **abre nueva conversación**.

```
Continuamos sprint smwhr Día N.

Estado al cierre de Día N-1:
- ✅ [logros]
- 🚧 [pendiente]

Hoy vamos a:
1. [tarea]
2. [tarea]

Lee el archivo apps/mobile/lib/[archivo crítico] antes de empezar.

Empieza con tarea 1.
```

### Si un commit rompe algo

```bash
# Volver al commit anterior
git log --oneline | head -10
git reset --hard <hash-del-commit-bueno>

# Si ya pusheaste, force push (cuidado)
git push --force-with-lease
```

Por eso commit cada logro pequeño es no-negociable.

---

## Métricas de progreso del sprint

### Daily checklist

Al final de cada día, valida:

- [ ] Commit hecho con mensaje claro
- [ ] Push a GitHub
- [ ] App compila sin warnings
- [ ] App corre sin crashes
- [ ] Pantallas implementadas son comparables a mocks PNG
- [ ] Conversación con plan claro para mañana

### Weekly check (Día 7 EOD)

Frontend completo debe tener:

- [ ] 11 pantallas implementadas
- [ ] Todos los repositories con mocks funcionando
- [ ] Animaciones smooth en transiciones
- [ ] Empty states diseñados
- [ ] Loading states con skeletons
- [ ] Error states con retry
- [ ] Camera real funcionando
- [ ] Quest timer en tiempo real
- [ ] Profile con stats
- [ ] Share funcional

---

## Una nota final, founder

Claude Code es la herramienta más poderosa que hayas usado en programación, pero también la más fácil de mal usar. La diferencia entre un sprint exitoso y uno frustrante es:

1. **Prompts precisos** (no vagos)
2. **Scope acotado** (una cosa a la vez)
3. **Review constante** (no aceptar a ciegas)
4. **CLAUDE.md como autoridad** (no permitir reaperturas)
5. **Commits pequeños** (rollback siempre disponible)

El agente es brutalmente bueno ejecutando dentro de un scope claro con contexto bien definido. Es brutalmente malo decidiendo entre alternativas válidas o resolviendo ambigüedades de producto.

Tu rol es definir scope, contexto y decisiones. Su rol es ejecutar.

Mañana arrancas algo serio. Buena suerte, Moi.

*"You were somewhere — y smwhr estará ahí para probarlo."*
