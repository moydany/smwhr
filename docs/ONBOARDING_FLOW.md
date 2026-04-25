# smwhr — Onboarding Flow Specification

**Versión:** v1.0
**Fecha:** 22 abril 2026

Especificación detallada del flujo de onboarding de smwhr. 4 pantallas, ~60 segundos de duración total, friction mínima.

---

## Principios del onboarding

1. **30 segundos al primer "wow"** — el usuario debe sentir el valor antes del minuto.
2. **Friction inversa al riesgo** — primero pides poco, luego pides más cuando ya hay confianza.
3. **Default a privacy-friendly** — todo lo opt-in, nada lo opt-out.
4. **Skip-able cuando posible** — los users impacientes pueden saltarse pasos no críticos.
5. **Sin tutoriales** — el producto debe ser self-explanatory en su primera pantalla.

---

## Pantalla 01 — Splash / Auth

**Propósito:** Establecer marca + autenticar.

### Estructura visual

```
┌─────────────────────────┐
│         (status bar)     │
│                         │
│                         │
│                         │
│        smwhr            │  ← wordmark grande, magenta neón, glow radial
│  You were somewhere.    │  ← tagline blanco, Inter regular
│                         │
│   ● 20.0850° N          │  ← geo coords sutiles, JetBrains Mono gris
│     -98.3630° W         │
│                         │
│                         │
│                         │
│  ┌───────────────────┐  │
│  │  🍎 Continue with  │  │  ← Apple button, blanco sólido
│  │      Apple        │  │
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │  G  Continue with │  │  ← Google button, gris oscuro
│  │      Google       │  │
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │  Continue with    │  │  ← Email button, outline
│  │      email        │  │
│  └───────────────────┘  │
│                         │
│  By continuing you      │  ← legal copy
│  agree to Terms and     │
│  Privacy.               │
└─────────────────────────┘
```

### Comportamiento

- **Splash duration:** 1.5s al abrir app (logo aparece con fade-in + scale).
- **Geo coords:** se obtienen via `geolocator` en background, muestran ciudad detectada o coords default (Tulancingo) si fail.
- **Buttons:**
  - Apple → Sign in with Apple flow nativo
  - Google → Google Sign-In flow nativo
  - Email → push a screen de "Enter email" con magic link

### Mock implementation

```dart
class MockAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> signInWithApple() async {
    await Future.delayed(Duration(milliseconds: 1200));
    return AuthSession(
      user: User(
        id: 'user-mock-001',
        email: 'mock@apple.com',
        // sin handle todavía, va a onboarding
      ),
      accessToken: 'mock-token',
    );
  }
  // ... mismo para Google y email
}
```

---

## Pantalla 02 — Identity

**Propósito:** capturar handle + display name + ciudad.

### Estructura visual

```
┌─────────────────────────┐
│ ←                01/03  │  ← back button + step indicator
│                         │
│  Claim your             │  ← title display
│  somewhere.             │
│                         │
│  Takes 30 seconds.      │  ← subtitle Inter
│  Promise.               │
│                         │
│  YOUR HANDLE            │  ← label uppercase JetBrains Mono
│  ┌───────────────────┐  │
│  │ @ yourname        │  │  ← input con prefix @
│  └───────────────────┘  │
│  This is your smwhr     │  ← helper text
│  URL. Make it yours.    │
│                         │
│  DISPLAY NAME           │
│  ┌───────────────────┐  │
│  │ How should we     │  │
│  │    call you?      │  │
│  └───────────────────┘  │
│                         │
│  WHERE ARE YOU BASED?   │
│  ┌───────────────────┐  │
│  │ 📍 Tulancingo, MX │  │  ← auto-detected
│  │            AUTO   │  │
│  └───────────────────┘  │
│  We use this to show    │
│  events near you.       │
│                         │
│                         │
│  ┌───────────────────┐  │
│  │   Continue →      │  │  ← disabled hasta validar
│  └───────────────────┘  │
└─────────────────────────┘
```

### Validaciones

**Handle:**
- 3-20 caracteres
- Solo `[a-z0-9_]` (lowercase, números, underscore)
- Único globalmente
- Validación en vivo con debounce de 500ms
- Mock devuelve "available" salvo handles reservados ('admin', 'smwhr', 'support', 'moi' [reservado para founder])

**Display name:**
- 1-40 caracteres
- Cualquier carácter incluyendo emojis
- No puede ser solo espacios

**City:**
- Auto-detected via geolocator + reverse geocoding
- Fallback a manual entry si fails
- Para R0.1 lista predefinida: ['Ciudad de México', 'Guadalajara', 'Monterrey', 'Puebla', 'Tijuana', 'Querétaro', 'Tulancingo', 'Other']

### Estados

- **Loading inicial:** auto-detect de ciudad, spinner pequeño
- **Handle taken:** mensaje rojo "@yourname is already taken"
- **Handle invalid:** mensaje gris "Use lowercase letters, numbers, and _"
- **Handle valid:** check verde
- **Continue disabled** hasta los 3 campos válidos
- **Continue enabled** transición a magenta sólido

---

## Pantalla 03 — Interests

**Propósito:** capturar categorías para personalizar feed.

### Estructura visual

```
┌─────────────────────────┐
│ ←                02/03  │
│                         │
│  What do you            │
│  collect?               │
│                         │
│  Pick everything that   │
│  moves you. You can     │
│  always add more.       │
│                         │
│  ┌─────────┐ ┌─────────┐│
│  │ Live    │ │ Sports  ││  ← cards 2 columns
│  │ music   │ │         ││
│  │         ○│ │        ○││  ← radio top-right
│  │ Concerts│ │Stadiums,││
│  │ intimate│ │ arenas, ││
│  │ shows   │ │ matches ││
│  └─────────┘ └─────────┘│
│                         │
│  ┌─────────┐ ┌─────────┐│
│  │Festivals│ │ Outdoor ││
│  │        ○│ │        ○││
│  │Multi-day│ │  Peaks, ││
│  │multi-st.│ │  trails ││
│  └─────────┘ └─────────┘│
│                         │
│  ┌─────────────────────┐│
│  │  Culture & arts     ││
│  │                    ○││
│  │  Theater, exhib.    ││
│  └─────────────────────┘│
│                         │
│  ┌─────────────────────┐│
│  │  Everything         ││
│  │                    ○││  ← single column
│  │  Don't limit me     ││
│  └─────────────────────┘│
│                         │
│  PICK AT LEAST ONE      │  ← helper si vacío
│  ┌───────────────────┐  │
│  │   Continue →      │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

### Comportamiento

**Selecciones:**
- Multi-select (no radio, son checkboxes)
- "Everything" es exclusivo: si lo seleccionas, deselecciona los demás (y vice versa)
- Al menos 1 selección requerida para continuar

**Visual feedback:**
- Tap → border magenta + radio fills magenta
- Untap → border gris + radio empty
- Hover/press → ligero scale 0.98 (haptic feedback iOS)

**Persistencia:**
- Selecciones se guardan en local mientras se navega
- Si user hace back y vuelve, mantiene selección

---

## Pantalla 04 — Permissions

**Propósito:** habilitar push notifications (no location todavía, eso viene cuando crea primer intent).

### Estructura visual

```
┌─────────────────────────┐
│ ←                03/03  │
│                         │
│        🔔   ●           │  ← bell icon + magenta dot
│                         │
│  Never miss             │
│  a quest.               │
│                         │
│  We'll ping you when a  │
│  quest starts at your   │
│  location, when it's    │
│  complete, and nothing  │
│  else. Zero spam. Ever. │
│                         │
│  ┌───────────────────┐  │
│  │ ●  Quest active   │  │  ← list with magenta checks
│  │    When you arrive│  │
│  │    at a venue     │  │
│  │                   │  │
│  │ ●  Quest complete │  │
│  │    When your badge│  │
│  │    is ready       │  │
│  │                   │  │
│  │ ●  Reminders      │  │
│  │    24h before your│  │
│  │    next event     │  │
│  └───────────────────┘  │
│                         │
│                         │
│  ┌───────────────────┐  │
│  │ Enable notif. →   │  │  ← magenta button
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │   Maybe later     │  │  ← secondary, white text
│  └───────────────────┘  │
└─────────────────────────┘
```

### Comportamiento

**Enable button:**
- Trigger native iOS/Android permission dialog
- Si usuario acepta: registra push token, navega a Home Feed
- Si usuario rechaza: navega a Home Feed pero recordatorio aparecerá en 7 días
- Si error: navega a Home Feed silenciosamente

**Maybe later button:**
- Naviga a Home Feed sin pedir permission
- Recordatorio aparecerá la próxima vez que el usuario marque intent en un evento

### Edge cases

- **Permission denied previamente:** mostrar copy "Open settings" en vez de "Enable"
- **Already enabled:** auto-skip esta pantalla, navegar a Home directamente

---

## Estados globales del onboarding

### Progress indicator

Cada pantalla muestra `01/03`, `02/03`, `03/03` arriba derecha. Splash/Auth no cuenta como step.

### Back navigation

- Pantalla 02 → back regresa a Splash/Auth (cierra sesión auth)
- Pantalla 03 → back regresa a 02 (mantiene datos)
- Pantalla 04 → back regresa a 03 (mantiene datos)

### Skip global

Botón pequeño "Skip" en pantalla 03 y 04 (no en 02 porque handle es requerido). Skip llena con defaults:
- Interests: ['everything']
- Notifications: not enabled

### Persistencia

Si usuario sale del app durante onboarding, al regresar:
- Si autenticado pero onboarding no completado → re-empezar desde donde quedó
- Si onboarding completado → ir directo a Home Feed

---

## Mock data del onboarding

```dart
// apps/mobile/lib/features/onboarding/providers/onboarding_state.dart

class OnboardingState {
  final String? handle;
  final String? displayName;
  final String? city;
  final List<String> interests;
  final bool notificationsEnabled;
  
  bool get isComplete => 
    handle != null && 
    displayName != null && 
    city != null && 
    interests.isNotEmpty;
}
```

```dart
// Reserved handles que el mock auth rechaza
const reservedHandles = [
  'admin', 'smwhr', 'support', 'moi', 'help',
  'official', 'staff', 'team', 'api', 'root',
  'test', 'demo', 'example', 'user',
];
```

---

## Animaciones del onboarding

### Transiciones entre pantallas

- Slide horizontal estándar (next: slide left, back: slide right)
- Duration: 300ms
- Curve: `Curves.easeInOutCubic`

### Splash → Auth

- Logo wordmark fade-in con scale de 0.95 a 1.0 (400ms)
- Glow radial fade-in detrás del wordmark (600ms)
- Tagline fade-in con delay 200ms
- Buttons fade-in con stagger de 100ms cada uno

### Auth → Identity

- Transición fade through (no slide, esto es un "deeper level")
- Duration: 500ms

### Permissions → Home Feed

- Cross-dissolve elegant (no slide, marca "you arrived")
- Duration: 600ms
- Bonus: home feed entra con stagger de cards (cada card aparece 50ms después de la anterior)

---

## Métricas de éxito del onboarding

A trackear con PostHog:

- **Completion rate:** % usuarios que llegan a Home Feed después de Auth
- **Drop-off por pantalla:** dónde se pierden
- **Time to complete:** mediana de tiempo desde Auth hasta Home Feed
- **Notifications opt-in rate:** % que aceptan permissions
- **Handle taken rate:** cuántos intentos hasta encontrar handle disponible

Targets R0.1:
- Completion rate > 80%
- Time to complete < 90 segundos median
- Notifications opt-in > 60%

---

*El onboarding es la primera impresión. Pulir cada animación, cada copy, cada validación. Aquí se juega si el usuario va a quedarse o no.*
