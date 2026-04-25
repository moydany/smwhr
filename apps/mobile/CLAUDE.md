# Mobile Agent — apps/mobile

Scope: Flutter app iOS + Android de smwhr.

Lee primero el `CLAUDE.md` raíz. Este documento complementa, no reemplaza.

---

## Stack

- **Framework:** Flutter stable (Dart 3.5+)
- **State management:** Riverpod ^2.5
- **Navigation:** go_router ^14.0
- **HTTP:** dio ^5.4 con interceptors
- **Secure storage:** flutter_secure_storage ^9.0
- **Local DB:** hive_flutter ^1.1 (dual-track logs)
- **Supabase client:** supabase_flutter ^2.0

**Geolocation dual-track:**
- **locus ^2.0** — primary tracker
- **geolocator ^12.0** — shadow tracker
- **permission_handler ^11.0** — manejo uniforme de permisos
- **workmanager ^0.5** — background execution adicional

**Media:**
- **camera ^0.11** — captura in-app (no galería)
- **native_exif ^0.6** — metadata de fotos

**Auth y push:**
- **sign_in_with_apple ^6.0** — Apple Sign-In
- **google_sign_in ^6.2** — Google Sign-In
- **firebase_messaging ^15.0** — push notifications
- **flutter_local_notifications ^17.0**

**UI utilities:**
- **flutter_svg ^2.0** — iconografía custom
- **lottie ^3.1** — animación de reveal
- **cached_network_image ^3.3** — optimización de imágenes

---

## Estructura de folders

```
apps/mobile/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   ├── app_colors.dart         # #050505, #FF2D95, etc.
│   │   │   ├── app_typography.dart     # Space Grotesk, Inter, JetBrains Mono
│   │   │   └── app_spacing.dart        # 4, 8, 12, 16, 24, 32, 48, 64
│   │   ├── router/
│   │   │   └── app_router.dart
│   │   └── constants/
│   │       └── api_constants.dart
│   ├── shared/
│   │   ├── widgets/
│   │   │   ├── primary_button.dart
│   │   │   ├── secondary_button.dart
│   │   │   ├── smwhr_text_field.dart
│   │   │   ├── status_bar.dart
│   │   │   └── progress_indicator.dart
│   │   └── utils/
│   ├── features/
│   │   ├── auth/
│   │   │   ├── providers/
│   │   │   ├── screens/
│   │   │   │   └── splash_auth_screen.dart
│   │   │   └── services/
│   │   ├── onboarding/
│   │   │   ├── providers/
│   │   │   ├── screens/
│   │   │   │   ├── identity_screen.dart
│   │   │   │   ├── interests_screen.dart
│   │   │   │   └── permissions_screen.dart
│   │   │   └── widgets/
│   │   ├── events/
│   │   │   ├── providers/
│   │   │   ├── screens/
│   │   │   │   ├── home_feed_screen.dart
│   │   │   │   └── event_detail_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── event_card.dart
│   │   │   │   ├── featured_card.dart
│   │   │   │   └── badge_preview.dart
│   │   │   └── models/
│   │   ├── quest/
│   │   │   ├── providers/
│   │   │   │   └── quest_state_provider.dart
│   │   │   ├── screens/
│   │   │   │   └── active_quest_screen.dart
│   │   │   ├── services/
│   │   │   │   ├── quest_tracker.dart       # orchestrator
│   │   │   │   ├── locus_tracker.dart       # primary
│   │   │   │   ├── geolocator_tracker.dart  # shadow
│   │   │   │   └── tracking_sync.dart       # batch upload
│   │   │   └── widgets/
│   │   │       ├── quest_timer.dart
│   │   │       └── verification_checks.dart
│   │   ├── camera/
│   │   │   ├── screens/
│   │   │   │   └── camera_screen.dart
│   │   │   └── widgets/
│   │   │       └── badge_frame_overlay.dart
│   │   ├── badges/
│   │   │   ├── providers/
│   │   │   ├── screens/
│   │   │   │   ├── reveal_screen.dart
│   │   │   │   └── badge_detail_screen.dart
│   │   │   └── widgets/
│   │   │       └── badge_card.dart
│   │   ├── profile/
│   │   │   ├── providers/
│   │   │   ├── screens/
│   │   │   │   └── profile_screen.dart
│   │   │   └── widgets/
│   │   │       ├── profile_stats.dart
│   │   │       └── collection_grid.dart
│   │   └── share/
│   │       ├── screens/
│   │       │   └── share_screen.dart
│   │       └── services/
│   │           └── share_image_generator.dart
│   ├── data/
│   │   ├── local/
│   │   │   ├── tracking_db.dart          # Hive local DB para dual-track
│   │   │   ├── models/
│   │   │   │   ├── locus_event_hive.dart
│   │   │   │   └── geolocator_ping_hive.dart
│   │   │   └── adapters/
│   │   └── remote/
│   │       ├── api_client.dart
│   │       ├── auth_api.dart
│   │       ├── events_api.dart
│   │       ├── quest_api.dart
│   │       └── badges_api.dart
│   └── domain/
│       ├── entities/
│       │   ├── user.dart
│       │   ├── event.dart
│       │   ├── badge.dart
│       │   └── quest.dart
│       └── repositories/
├── android/
│   └── app/
│       └── src/
│           └── main/
│               └── AndroidManifest.xml  # permisos background location
├── ios/
│   └── Runner/
│       └── Info.plist                   # permisos y background modes
├── assets/
│   ├── badges/                          # SVG frames por categoría
│   │   ├── frame_music.svg
│   │   ├── frame_sports.svg
│   │   ├── frame_festivals.svg
│   │   ├── frame_outdoor.svg
│   │   └── frame_culture.svg
│   ├── fonts/
│   ├── animations/
│   │   └── reveal.json                  # Lottie
│   └── icons/
└── pubspec.yaml
```

---

## Design tokens (hardcoded, coherente con los mocks v1)

```dart
// lib/core/theme/app_colors.dart
class AppColors {
  // Backgrounds
  static const bg = Color(0xFF050505);
  static const surface = Color(0xFF111111);
  static const surfaceElevated = Color(0xFF1A1A1A);
  static const border = Color(0xFF2A2A2A);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF888888);
  static const textTertiary = Color(0xFF555555);
  static const textDisabled = Color(0xFF333333);

  // Accent (magenta único)
  static const accent = Color(0xFFFF2D95);
  static const accentMuted = Color(0xFF8B1A51);
  static const accentGlow = Color(0x26FF2D95); // 15% alpha

  // Category ambient colors (para glows en cards y reveal)
  static const musicAmbient = Color(0xFFFF2D95);
  static const sportsAmbient = Color(0xFF2DFF95);  // verde
  static const festivalsAmbient = Color(0xFFFF9D2D); // naranja
  static const outdoorAmbient = Color(0xFF2DC8FF);   // azul
  static const cultureAmbient = Color(0xFF9D2DFF);   // morado
}

// lib/core/theme/app_typography.dart
class AppTypography {
  static const String displayFont = 'Space Grotesk';
  static const String bodyFont = 'Inter';
  static const String monoFont = 'JetBrains Mono';

  // Display
  static const displayLarge = TextStyle(
    fontFamily: displayFont,
    fontWeight: FontWeight.w700,
    fontSize: 32,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  // Body
  static const bodyLarge = TextStyle(
    fontFamily: bodyFont,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const bodyMedium = TextStyle(
    fontFamily: bodyFont,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  // Label (uppercase)
  static const label = TextStyle(
    fontFamily: bodyFont,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    letterSpacing: 1.2,
    color: AppColors.textSecondary,
  );

  // Mono (serials, timers)
  static const mono = TextStyle(
    fontFamily: monoFont,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    letterSpacing: 0.5,
  );

  static const monoLarge = TextStyle(
    fontFamily: monoFont,
    fontWeight: FontWeight.w500,
    fontSize: 48,
    letterSpacing: 1.0,
    color: AppColors.textPrimary,
  );
}

// lib/core/theme/app_spacing.dart
class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  static const double radiusSmall = 8;
  static const double radiusBadge = 12;
  static const double radiusCard = 16;
  static const double radiusFrame = 54;
}
```

---

## Arquitectura dual-track (crítico para Día 4-5)

### Principio

Dos trackers corren en paralelo durante quests activas. Locus emite eventos ricos (geofence, motion, etc). Geolocator dispara pings cada 5 min. Ambos escriben a Hive local. Sync batch cada 30 min al backend con ambos datasets.

### `services/quest_tracker.dart` — Orchestrator

```dart
class QuestTracker {
  final LocusTracker _locus;
  final GeolocatorTracker _geolocator;
  final TrackingDB _db;
  final TrackingSync _sync;

  Future<void> startQuest(Event event) async {
    // 1. Validar permisos
    final permission = await _ensurePermissions();
    if (!permission) throw QuestPermissionException();

    // 2. Inicializar Locus con polygon del evento
    await _locus.start(
      eventId: event.id,
      polygon: event.geofencePolygon,
      onEvent: (locusEvent) => _db.saveLocusEvent(locusEvent),
    );

    // 3. Inicializar Geolocator con timer
    await _geolocator.start(
      eventId: event.id,
      interval: Duration(minutes: 5),
      polygon: event.geofencePolygon,
      onPing: (ping) => _db.saveGeolocatorPing(ping),
    );

    // 4. Programar sync cada 30 min
    _sync.schedulePeriodicSync(
      eventId: event.id,
      interval: Duration(minutes: 30),
    );
  }

  Future<void> stopQuest(String eventId) async {
    await _locus.stop(eventId);
    await _geolocator.stop(eventId);
    await _sync.finalSync(eventId);  // upload final de todos los datos
  }
}
```

### `services/locus_tracker.dart` — Primary

```dart
class LocusTracker {
  Future<void> start({
    required String eventId,
    required List<LatLng> polygon,
    required Function(LocusEvent) onEvent,
  }) async {
    await Locus.ready();
    
    // Configurar
    Locus.setConfig(
      locationAccuracy: LocationAccuracy.high,
      distanceFilter: 10,
      stopTimeout: 5,
      heartbeatInterval: 60,
      motionTriggerDelay: 30,
    );

    // Agregar polygon geofence
    await Locus.addGeofence(
      id: eventId,
      polygon: polygon,
      notifyOnEntry: true,
      notifyOnExit: true,
      notifyOnDwell: true,
      loiteringDelay: 60000, // 1 min
    );

    // Listeners
    Locus.onGeofenceEvent((event) {
      onEvent(LocusEvent.fromGeofence(event, eventId));
    });

    Locus.onLocationUpdate((location) {
      onEvent(LocusEvent.fromLocation(location, eventId));
    });

    Locus.onMotionChange((motion) {
      onEvent(LocusEvent.fromMotion(motion, eventId));
    });

    // Start
    await Locus.start();
  }

  Future<void> stop(String eventId) async {
    await Locus.removeGeofence(eventId);
    await Locus.stop();
  }
}
```

### `services/geolocator_tracker.dart` — Shadow

```dart
class GeolocatorTracker {
  Timer? _pingTimer;

  Future<void> start({
    required String eventId,
    required Duration interval,
    required List<LatLng> polygon,
    required Function(GeolocatorPing) onPing,
  }) async {
    _pingTimer?.cancel();

    _pingTimer = Timer.periodic(interval, (_) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );

        final ping = GeolocatorPing(
          eventId: eventId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          timestamp: DateTime.now(),
          isInsidePolygon: _isInsidePolygon(
            LatLng(position.latitude, position.longitude),
            polygon,
          ),
        );

        onPing(ping);
      } catch (e) {
        // Log pero no fallar - shadow track es best-effort
        print('Geolocator ping failed: $e');
      }
    });
  }

  Future<void> stop(String eventId) async {
    _pingTimer?.cancel();
  }

  bool _isInsidePolygon(LatLng point, List<LatLng> polygon) {
    // Ray casting algorithm
    int intersections = 0;
    for (int i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if (((a.latitude > point.latitude) != (b.latitude > point.latitude)) &&
          (point.longitude <
              (b.longitude - a.longitude) *
                      (point.latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude)) {
        intersections++;
      }
    }
    return intersections % 2 == 1;
  }
}
```

### `services/tracking_sync.dart` — Batch upload

```dart
class TrackingSync {
  final TrackingDB _db;
  final QuestApi _api;

  Future<void> syncBatch(String eventId) async {
    final locusEvents = await _db.getUnsyncedLocusEvents(eventId);
    final geolocatorPings = await _db.getUnsyncedGeolocatorPings(eventId);

    if (locusEvents.isEmpty && geolocatorPings.isEmpty) return;

    try {
      await _api.syncQuestBatch(
        eventId: eventId,
        locusEvents: locusEvents,
        geolocatorPings: geolocatorPings,
        clientTimestamp: DateTime.now(),
      );

      // Marcar como sync'd
      await _db.markAsSynced(
        locusEventIds: locusEvents.map((e) => e.id).toList(),
        geolocatorPingIds: geolocatorPings.map((e) => e.id).toList(),
      );
    } catch (e) {
      // Reintentará en siguiente periodo
      print('Sync failed, will retry: $e');
    }
  }
}
```

---

## Permisos (CRÍTICO, dedicar tiempo)

### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>smwhr uses your location to detect when you arrive at events.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>smwhr uses your location in background to verify you stayed at the event. We only track during active quests.</string>

<key>NSMotionUsageDescription</key>
<string>smwhr uses motion data to improve battery life during quests.</string>

<key>NSCameraUsageDescription</key>
<string>smwhr uses the camera to capture your moment at the event.</string>

<key>UIBackgroundModes</key>
<array>
  <string>location</string>
  <string>fetch</string>
  <string>remote-notification</string>
</array>
```

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### Flujo de solicitud de permisos

1. **Onboarding (pantalla 04 Permissions):** solo push notifications
2. **Primera vez que marca intent:** pedir "When in use" location
3. **Cuando quest arranca en venue:** pedir "Always" con copy claro
4. **Antes de capturar foto:** pedir camera

**Nunca pidas permisos upfront sin contexto.** Pedir "Always location" en splash tiene 60% de rechazo. Pedir después de un intent concreto tiene 85% de aceptación.

---

## Convenciones de código

### Naming
- Archivos: `snake_case.dart` (ej: `quest_tracker.dart`)
- Clases: `PascalCase` (ej: `QuestTracker`)
- Variables privadas: `_camelCase`
- Constantes: `SCREAMING_SNAKE_CASE`

### Widgets
- Stateless por default. StatefulWidget solo cuando necesario
- Extraer widgets cuando > 80 líneas o reutilizable
- Props nombradas siempre, no positional

### Estado
- Riverpod providers para todo estado compartido
- `StateNotifierProvider` para estado complejo
- `FutureProvider` para async data
- Nunca `setState` en widgets complejos — mover a Riverpod

### Async
- `async`/`await` siempre (no `.then()`)
- `try`/`catch` explícito para operaciones críticas
- `Future.wait` para paralelos

### Imports
- Orden: dart sdk → flutter → packages externos → packages internos → archivos del proyecto
- Sin imports relativos excepto dentro del mismo feature (usa absolute from `package:smwhr/`)

---

## Testing

- Widget tests para pantallas críticas (onboarding, quest active, reveal)
- Integration tests para flujo completo end-to-end
- Mock de Locus, geolocator, y API calls

---

## Anti-patterns mobile

- ❌ `setState` en widgets grandes (usa Riverpod)
- ❌ Networking fuera de Repository pattern
- ❌ Hardcoded strings (usa constants + i18n futuro)
- ❌ Hardcoded colors/sizes (usa AppColors/AppSpacing)
- ❌ Business logic en widgets (mover a services)
- ❌ Imports relativos largos (`../../../`) — usa absolute
- ❌ FutureBuilder sin error state
- ❌ Navegación imperativa (usa go_router)

---

## First tasks (Día 1-2)

1. `flutter create --org quest.smwhr app`
2. Configurar `pubspec.yaml` con todas las dependencias
3. Crear estructura de folders completa
4. Implementar `app_colors.dart`, `app_typography.dart`, `app_spacing.dart`
5. Implementar `app_theme.dart` con ThemeData dark
6. Configurar `go_router` con rutas base
7. Implementar pantalla 01 Splash/Auth con botones stub
8. Implementar integración Supabase Auth (Apple + Google)
9. Implementar pantalla 02 Identity con validación de handle en vivo
10. Configurar permisos iOS/Android en Info.plist/AndroidManifest.xml

Día 3: pantallas onboarding restantes + home feed + event detail.
Día 4-5: dual-track tracking + active quest screen.
Día 6: camera + reveal + profile + share.
