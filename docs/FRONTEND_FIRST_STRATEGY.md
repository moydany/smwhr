# smwhr — Frontend-First Implementation Strategy

**Versión:** v1.0
**Fecha:** 22 abril 2026
**Owner:** Moi

Este documento describe la estrategia de construcción de smwhr donde el frontend (Flutter app) se construye PRIMERO con datos mock, y el backend (NestJS) se construye DESPUÉS contra contratos definidos por el frontend.

---

## Por qué frontend-first

1. **Validación visual rápida.** En 7 días, app navegable end-to-end sin backend.
2. **Contratos claros.** El backend cumple lo que la app pide, no al revés.
3. **Menos refactor.** Si la app cambia, no rehacemos endpoints aún no construidos.
4. **Plan B de emergencia.** Si BTS se acerca y backend no está listo, app puede operar con datos curados manualmente y Supabase Auth nativo.
5. **Foco mental.** Trabajas con un solo agente (Mobile) en vez de orquestar tres.

---

## El patrón Repository (la clave de todo)

Toda la app accede a datos a través de interfaces abstractas. La implementación se intercambia transparentemente entre mock y real.

### Definición de contratos

```dart
// apps/mobile/lib/data/repositories/event_repository.dart

abstract class EventRepository {
  Future<List<Event>> getUpcomingEvents({
    String? city,
    String? category,
    bool? featured,
  });
  
  Future<Event> getEventBySlug(String slug);
  
  Future<void> createIntent(String eventId);
  Future<void> deleteIntent(String eventId);
  
  Future<EventStats> getEventStats(String eventId);
}

abstract class AuthRepository {
  Future<AuthSession> signInWithApple();
  Future<AuthSession> signInWithGoogle();
  Future<void> requestEmailMagicLink(String email);
  Future<AuthSession> verifyEmailToken(String token);
  Future<void> signOut();
  Future<User?> getCurrentUser();
}

abstract class QuestRepository {
  Stream<QuestStatus> watchQuestStatus(String eventId);
  Future<void> startQuest(String eventId);
  Future<void> stopQuest(String eventId);
  Future<void> uploadPhoto(String questId, File photo);
  Future<void> syncTrackingBatch({
    required String eventId,
    required List<LocusEvent> locusEvents,
    required List<GeolocatorPing> geolocatorPings,
  });
}

abstract class BadgeRepository {
  Future<List<Badge>> getMyBadges();
  Future<Badge> getBadgeById(String id);
  Future<String> getShareImageUrl(String badgeId);
}

abstract class UserRepository {
  Future<User> getProfile(String handle);
  Future<List<Badge>> getCollection(String handle);
  Future<bool> checkHandleAvailability(String handle);
  Future<User> updateProfile(UpdateProfileDto dto);
  Future<User> completeOnboarding(OnboardingDto dto);
}
```

### Implementaciones mock

```dart
// apps/mobile/lib/data/mock/mock_event_repository.dart

class MockEventRepository implements EventRepository {
  @override
  Future<List<Event>> getUpcomingEvents({
    String? city,
    String? category,
    bool? featured,
  }) async {
    // Simula latencia de red real
    await Future.delayed(Duration(milliseconds: 600 + Random().nextInt(400)));
    
    var events = mockEvents;
    
    if (city != null) {
      events = events.where((e) => e.city == city).toList();
    }
    if (category != null) {
      events = events.where((e) => e.category == category).toList();
    }
    if (featured == true) {
      events = events.where((e) => e.isFeatured).toList();
    }
    
    return events;
  }

  @override
  Future<Event> getEventBySlug(String slug) async {
    await Future.delayed(Duration(milliseconds: 400));
    final event = mockEvents.firstWhere(
      (e) => e.slug == slug,
      orElse: () => throw Exception('Event not found'),
    );
    return event;
  }

  @override
  Future<void> createIntent(String eventId) async {
    await Future.delayed(Duration(milliseconds: 300));
    // Mock: actualizar local state de "I'll be there"
  }

  // ... resto de métodos
}
```

### Implementaciones reales (después)

```dart
// apps/mobile/lib/data/api/api_event_repository.dart

class ApiEventRepository implements EventRepository {
  final Dio _dio;
  ApiEventRepository(this._dio);

  @override
  Future<List<Event>> getUpcomingEvents({
    String? city,
    String? category,
    bool? featured,
  }) async {
    final response = await _dio.get('/events', queryParameters: {
      if (city != null) 'city': city,
      if (category != null) 'category': category,
      if (featured != null) 'featured': featured,
    });
    
    return (response.data as List)
        .map((json) => Event.fromJson(json))
        .toList();
  }

  // ... resto de métodos siguen el mismo contrato
}
```

### Provider que decide cuál usar

```dart
// apps/mobile/lib/data/providers/repository_providers.dart

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  if (kAppConfig.useMocks) {
    return MockEventRepository();
  }
  return ApiEventRepository(ref.read(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (kAppConfig.useMocks) {
    return MockAuthRepository();
  }
  return SupabaseAuthRepository(ref.read(supabaseClientProvider));
});

// ... mismo patrón para todos los repositories
```

```dart
// apps/mobile/lib/core/config/app_config.dart

class AppConfig {
  final bool useMocks;
  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;

  const AppConfig({
    required this.useMocks,
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  factory AppConfig.fromEnv() {
    return AppConfig(
      useMocks: const bool.fromEnvironment('USE_MOCKS', defaultValue: true),
      apiBaseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:3000',
      ),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
      supabaseAnonKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: '',
      ),
    );
  }
}

const kAppConfig = AppConfig.fromEnv();
```

Para correr con mocks: `flutter run --dart-define=USE_MOCKS=true`
Para correr con backend real: `flutter run --dart-define=USE_MOCKS=false --dart-define=API_BASE_URL=https://api.smwhr.quest`

---

## Estructura de mock data

```
apps/mobile/lib/data/mock/
├── mock_users.dart          # Current user @moi + 8 perfiles ficticios
├── mock_events.dart         # 16 eventos LATAM 2026
├── mock_badges.dart         # 6-8 badges en colección @moi
├── mock_intents.dart        # Intents de @moi en eventos próximos
├── mock_quest_states.dart   # Estados simulados de quest activa
└── mock_*_repository.dart   # Implementación de cada repo
```

### Mock data: @moi como current user

```dart
// apps/mobile/lib/data/mock/mock_users.dart

final mockCurrentUser = User(
  id: 'user-moi-001',
  handle: 'moi',
  displayName: 'Moi',
  email: 'moi@orbit-m.dev',
  avatarUrl: null,
  bio: 'Founder. Maker. Sometimes lost in concerts.',
  city: 'Tulancingo',
  countryCode: 'MX',
  interests: ['music', 'sports', 'outdoor'],
  language: 'es',
  onboardingCompletedAt: DateTime(2026, 4, 22),
  createdAt: DateTime(2026, 4, 1),
  // Stats
  questsCount: 23,
  venuesCount: 8,
  artistsCount: 14,
);

final mockOtherUsers = [
  User(id: 'user-002', handle: 'sofia', displayName: 'Sofía', /* ... */),
  User(id: 'user-003', handle: 'carlos', displayName: 'Carlos', /* ... */),
  // ... 6 más
];
```

### Mock badges en colección de @moi

```dart
// apps/mobile/lib/data/mock/mock_badges.dart

final mockMyBadges = [
  Badge(
    id: 'badge-001',
    serialNumber: 1247,
    totalForEvent: 47832,
    eventTitle: 'World Tour 2026',
    eventArtist: 'BTS',
    venueName: 'Estadio GNP Seguros',
    city: 'Ciudad de México',
    awardedAt: DateTime(2026, 5, 7, 23, 30),
    category: 'music',
    composedImageUrl: 'https://picsum.photos/seed/badge-bts/600/750',
    isVerified: true,
  ),
  Badge(
    id: 'badge-002',
    serialNumber: 892,
    totalForEvent: 12000,
    eventTitle: 'Bahidorá 2026',
    eventArtist: 'Multiple Artists',
    venueName: 'Las Estacas',
    city: 'Morelos',
    awardedAt: DateTime(2026, 4, 18),
    category: 'festivals',
    composedImageUrl: 'https://picsum.photos/seed/badge-bahidora/600/750',
    isVerified: true,
  ),
  // ... 4-6 más mezclando categorías
];
```

### Mock images source

Para todas las imágenes mock, usa **Picsum con seeds consistentes**:

```dart
// Función helper en mock_images.dart
String mockImage(String seed, {int width = 800, int height = 600}) {
  return 'https://picsum.photos/seed/$seed/$width/$height';
}

// Uso:
final btsHeroImage = mockImage('bts-cdmx-2026', width: 800, height: 600);
final coronaCapitalHero = mockImage('corona-capital-2026', width: 800, height: 600);
```

Esto garantiza que las imágenes son consistentes entre runs y look real (no placeholders genéricos).

---

## Mock del Quest activo (la magia)

El quest activo es la pantalla más mágica de la app. En modo mock, simulamos el comportamiento completo.

```dart
// apps/mobile/lib/data/mock/mock_quest_repository.dart

class MockQuestRepository implements QuestRepository {
  Timer? _timer;
  final _statusController = StreamController<QuestStatus>.broadcast();
  
  QuestStatus _currentStatus = QuestStatus.notStarted;
  int _dwellMinutes = 0;
  
  @override
  Stream<QuestStatus> watchQuestStatus(String eventId) {
    return _statusController.stream;
  }

  @override
  Future<void> startQuest(String eventId) async {
    await Future.delayed(Duration(milliseconds: 800));
    
    _currentStatus = QuestStatus(
      isActive: true,
      dwellMinutes: 0,
      checks: QuestChecks(
        gpsVerified: true,
        deviceTrusted: true,
        integrityActive: true,
        photoCapture: false,
      ),
      eventId: eventId,
    );
    _statusController.add(_currentStatus);
    
    // Simular progresión de dwell time cada segundo (1 sec = 1 minute mock)
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      _dwellMinutes++;
      _currentStatus = _currentStatus.copyWith(dwellMinutes: _dwellMinutes);
      _statusController.add(_currentStatus);
      
      if (_dwellMinutes >= 60) {
        _timer?.cancel();
      }
    });
  }

  @override
  Future<void> stopQuest(String eventId) async {
    _timer?.cancel();
    _currentStatus = _currentStatus.copyWith(isActive: false);
    _statusController.add(_currentStatus);
  }

  @override
  Future<void> uploadPhoto(String questId, File photo) async {
    await Future.delayed(Duration(milliseconds: 1500));
    _currentStatus = _currentStatus.copyWith(
      checks: _currentStatus.checks.copyWith(photoCapture: true),
    );
    _statusController.add(_currentStatus);
  }

  @override
  Future<void> syncTrackingBatch({
    required String eventId,
    required List<LocusEvent> locusEvents,
    required List<GeolocatorPing> geolocatorPings,
  }) async {
    await Future.delayed(Duration(milliseconds: 500));
    // Mock: data se "sube" al backend simulado
  }
}
```

Esta implementación te permite:
- Probar la pantalla de quest activa visualmente
- Ver el timer avanzando en tiempo real
- Simular completion de checks
- Probar el flow de captura de foto
- TODO sin backend real

---

## Cronograma frontend-first detallado

### Día 1 (Mié 22 abril) — Foundation

**Mañana: Setup operativo (no código)**
- Dominio, cuentas, Supabase básico
- Repo GitHub clonado
- Starter kit descomprimido

**Tarde: Bootstrap Flutter**
- `flutter create` con bundle ID `quest.smwhr.app`
- Pubspec con todas las dependencias
- Design tokens completos (colors, typography, spacing)
- Theme configurado
- Router base con go_router
- Splash screen funcional

**Output esperado:** app que abre, muestra splash con wordmark magenta, transiciona a auth screen.

### Día 2 (Jue 23) — Onboarding completo

**Construir:**
- Splash/Auth screen completo con 3 botones
- Pantalla 02 Identity (handle + display name + city)
- Pantalla 03 Interests (5 categorías + "Everything")
- Pantalla 04 Permissions (notifications)
- Mock auth repository
- Validación de handle en vivo (mock con delay)

**Output:** flow de onboarding completo navegable hasta home feed (vacío todavía).

### Día 3 (Vie 24) — Home feed + Event detail

**Construir:**
- Home feed con featured card grande
- Cards secundarios scrolleables
- Mock event repository con 16 eventos LATAM
- Filtros por categoría
- Event detail screen completa
- Animaciones de transición (Hero)
- Mock intent toggle ("I'll be there")

**Output:** navegación completa de descubrir → ver evento → marcar intent.

### Día 4 (Sáb 25) — Active Quest screen

**Construir:**
- Active quest screen con timer mock
- Verification checks animados
- Glow magenta atmospheric
- Botón "Capture your moment"
- Mock quest repository con timer simulado
- Estados: not started, active, photo captured, completed

**Output:** pantalla de quest activa con timer corriendo en tiempo real.

### Día 5 (Dom 26) — Camera + Reveal

**Construir:**
- Camera screen con preview de frame overlay
- Captura de foto (usando paquete camera real, no mock)
- Procesamiento mock de la foto
- Reveal screen con animación Lottie
- Generación mock de badge con datos del usuario

**Output:** flow completo de captura → reveal → save to collection.

### Día 6 (Lun 27) — Profile + Collection + Share

**Construir:**
- Profile screen con stats (Quests, Venues, Artists)
- Tabs: Collection, Wanted, Friends
- Grid de badges en colección
- Badge detail screen
- Share screen con preview a Instagram Stories
- Generación de imagen 1080x1920 con texto overlay

**Output:** colección visualizable, badges compartibles a Stories.

### Día 7 (Mar 28) — Pulido visual

**Pulir:**
- Micro-interacciones (haptic feedback, ripples)
- Animaciones entre pantallas
- Empty states bonitos
- Error states (sin internet, etc.)
- Loading skeletons en vez de spinners genéricos
- Tipografía y espaciado fino-tuned vs mocks

**Output:** app que se siente como producto pulido. Lista para mostrar a beta testers.

### Días 8-12 — Backend real (siguiendo doc original)

NestJS bootstrap, Prisma migrations, módulos, dual-track, reconciliation, badge composition.

### Días 13-15 — Integración y soft launch

Switch de mocks a real, fix breaking changes, testing en device, deploy a TestFlight, soft launch.

---

## Reglas de oro frontend-first

### 1. Cero llamadas HTTP directas en widgets

Toda data viene de un Repository via Riverpod. Si un widget hace `dio.get()` directamente, está mal.

### 2. Modelos en Dart son source of truth

`Event`, `Badge`, `User` se definen como classes Dart con `fromJson`/`toJson`. Los DTOs del backend después tienen que respetar esos schemas.

### 3. Errores de red son features, no bugs

Diseña empty states, loading skeletons, retry buttons. La app debe funcionar bien en mala señal mexicana.

### 4. Latencia simulada realista

Todos los mocks tienen `Future.delayed(...)` con tiempos plausibles. App sin latencia se siente fake. App con latencia se siente real.

### 5. El switch a backend real debe ser una variable de entorno

`flutter run --dart-define=USE_MOCKS=false`. Cero refactor adicional. Si no funciona así, el patrón está mal implementado.

---

## Cuándo el frontend está listo para conectar backend

Checklist de "frontend done":

- [ ] Las 11 pantallas implementadas y navegables
- [ ] Mock data realista para todos los repositories
- [ ] Animaciones y transiciones smooth
- [ ] Empty states diseñados
- [ ] Error states diseñados
- [ ] Loading states con skeletons
- [ ] Validaciones inline (handle, email)
- [ ] Permissions flow funcional (location, notifications, camera)
- [ ] Camera real funcionando (foto se guarda en mock storage)
- [ ] Quest timer corriendo en tiempo real
- [ ] Profile con stats
- [ ] Collection grid
- [ ] Share a Stories funcional
- [ ] App tested en iOS y Android device real

Una vez todos estos checkmarks, comienzas Día 8 con backend.

---

*Frontend-first es disciplina. La tentación de "voy a hacer el endpoint rápido en NestJS" durante Días 1-7 mata el approach. Quédate en Flutter. El backend espera su turno.*
