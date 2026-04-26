# Mobile Quest Active — dual-track tracker + camera + EXIF + permissions

> **For agentic workers:** REQUIRED SUB-SKILL — invoke `superpowers:executing-plans` (or `superpowers:subagent-driven-development`) and walk session-by-session. Smoke test + commit close every session. No silent scope drift. Steps use `- [ ]` for tracking.

**Goal:** Replace the mock quest pipeline with a real implementation that opens the camera, captures a photo with EXIF metadata, and runs a dual-track GPS tracker (Locus primary + Geolocator shadow) during an active event so the backend's reconciliation engine can mint a verified badge.

**Soft-launch deadline:** 2026-05-05 (BTS World Tour, 7/9/10 mayo, Estadio GNP Seguros). The dual-track quest is the LAST feature blocking the soft-launch demo flow. Auth, onboarding, catalog browsing, intent toggle, profile, badges (catalog), and waitlist are already real. See `2026-04-25-r01-handoff.md` for that surface.

**Scope:** mobile (`apps/mobile/`) + a small backend tweak in `apps/api/` to expose the event polygon as GeoJSON so the mobile tracker can register the Locus geofence.

---

## Where things stand right now (read this before touching anything)

The cutover commits 5608e2b → 8a4f8c7 wired the API-callable surface of `RealQuestsRepository` against the NestJS backend. Specifically:

- ✅ `getQuestStatus(eventId)` → `GET /quests/:eventId/status` returning the full `QuestStatus` (already mapped in `lib/data/remote/mappers.dart`)
- ✅ `watchQuestStatus(eventId)` polls every 5 s
- ✅ `syncTrackingBatch(eventId, locusEvents, geolocatorPings)` → `POST /quests/:eventId/sync` with `LocusEvent` + `GeolocatorPing` arrays mapped to backend shape
- ✅ `attestIntegrity(eventId, token)` → `POST /quests/:eventId/integrity`
- ✅ `uploadPhoto({eventId, file})` → `POST /quests/:eventId/photo` (multipart, EXIF metadata as form fields)
- ❌ `startQuest(eventId)` and `stopQuest(eventId)` throw `UnimplementedError`. They need an on-device orchestrator.

What's missing on the mobile side, in dependency order:
1. Real platform permissions (location when-in-use, location always, camera, motion). Today the `PermissionsScreen` only stubs notifications.
2. A permission flow service that requests the right permission at the right moment with the right copy.
3. Hive `tracking_db` to accumulate Locus events + Geolocator pings before each batch sync.
4. `LocusTracker` (primary) wrapping `package:locus`.
5. `GeolocatorTracker` (shadow) with a 5-min `Timer.periodic` and ray-cast `isInsidePolygon`.
6. `QuestTracker` orchestrator that owns the lifecycle and writes to Hive.
7. `TrackingSync` that batches every 30 min via `RealQuestsRepository.syncTrackingBatch`.
8. Real `CameraController` capture in `camera_screen.dart` (currently a procedural preview).
9. EXIF write/read on the captured file via `native_exif`.
10. iOS `Info.plist` + Android `AndroidManifest.xml` background modes / foreground service.

What's missing on the backend side:
- `Event` JSON does not currently include the polygon. The PostGIS column is populated in seed (commit fe304f0) but not surfaced. The mobile mapper defaults `geofencePolygon` to `const []`. The Locus tracker needs the actual polygon to register the geofence. **One small backend tweak in Session 1.**

---

## Architecture (per `apps/mobile/CLAUDE.md` § dual-track)

```
                       QuestTracker (orchestrator)
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
       LocusTracker    GeolocatorTracker   TrackingSync
       (primary)        (shadow, 5 min)    (batch every 30 min)
            │                 │                 │
            └────────►  TrackingDb (Hive)  ◄────┘
                              │
                              ▼
              RealQuestsRepository.syncTrackingBatch
                              │
                              ▼
                    POST /quests/:id/sync
```

- **Locus** emits `GEOFENCE_ENTER`, `GEOFENCE_EXIT`, `LOCATION_UPDATE`, `MOTION_CHANGE`. Configured with the event polygon at start, distance filter 10 m, accuracy `LocationAccuracy.high`, motion-trigger delay 30 s, heartbeat 60 s.
- **Geolocator** runs an independent `Timer.periodic` every 5 minutes, calls `Geolocator.getCurrentPosition`, ray-casts `isInsidePolygon` locally so the backend can use the flag in `ReconciliationService`.
- Both write to **Hive** (`tracking_db`, one box per `eventId`) so background ticks survive cold restart.
- **TrackingSync** runs every 30 min: reads unsynced rows, calls `RealQuestsRepository.syncTrackingBatch`, marks rows synced. Final sync on `stopQuest`.
- **Backend reconciliation** — already shipped (`fe304f0`). On event end + 1 h grace, `CloseEndedEventsCron` finalizes any unfinalized intents: runs `ReconciliationService` (5 strategies) → `VerificationService` (score 0-100) → `BadgesService.issue` if `score ≥ 60`.

The mobile UI driving this lives at `lib/features/quest/screens/active_quest_screen.dart`. It already consumes `questsRepositoryProvider.watchQuestStatus(eventId)` — no changes there once `RealQuestsRepository.startQuest` actually starts the orchestrator.

---

## File structure (locked before tasks)

```
apps/api/src/events/events.service.ts        # Session 1 — add geofencePolygon GeoJSON to event reads

apps/mobile/
├── ios/Runner/Info.plist                    # Session 1 — NSLocation/Camera/Motion + UIBackgroundModes
├── android/app/src/main/AndroidManifest.xml # Session 1 — ACCESS_*_LOCATION, FOREGROUND_SERVICE*, CAMERA, POST_NOTIFICATIONS
├── lib/
│   ├── data/
│   │   ├── local/
│   │   │   ├── tracking_db.dart             # Session 2 — Hive boxes per eventId
│   │   │   └── adapters/
│   │   │       ├── locus_event_adapter.dart # Session 2 — TypeAdapter
│   │   │       └── geolocator_ping_adapter.dart  # Session 2
│   │   └── remote/
│   │       └── mappers.dart                 # Session 1 — parse geofencePolygon GeoJSON
│   └── features/
│       └── quest/
│           ├── services/
│           │   ├── permission_flow.dart     # Session 1 — when-in-use → always escalation, camera, motion
│           │   ├── locus_tracker.dart       # Session 3 — primary tracker (package:locus)
│           │   ├── geolocator_tracker.dart  # Session 3 — shadow (package:geolocator) + ray-cast
│           │   ├── quest_tracker.dart       # Session 4 — orchestrator
│           │   └── tracking_sync.dart       # Session 4 — batch upload every 30 min
│           ├── providers/
│           │   └── quest_state_provider.dart # Session 4 — bridge tracker → screen
│           └── screens/
│               └── active_quest_screen.dart  # Session 4 — drive from real status (small edit)
│
├── lib/features/camera/
│   ├── services/
│   │   └── exif_writer.dart                 # Session 6 — read EXIF via native_exif
│   └── screens/
│       └── camera_screen.dart               # Session 5 — real CameraController + capture
│
└── test/
    ├── tracking_db_test.dart                # Session 2 — Hive round-trip
    ├── geolocator_tracker_test.dart         # Session 3 — ray-cast on known polygons
    └── quest_tracker_test.dart              # Session 4 — lifecycle, sync cadence
```

---

## Session-level plan (6 sessions)

Each session has: **Goal**, **Files**, **Definition of done**, **Smoke**, **Commit message**.

**Per-session smoke (mandatory close-out):** boot the app on a real device (NOT just simulator — Locus + background location + camera need hardware) walking the new surface that session. Capture the relevant log/screenshot. Profile mode for the perf-sensitive sessions (3, 4, 5).

### Session 1 — Backend polygon export, platform config, permission service

**Goal:** unblock everything downstream by (a) surfacing the event polygon in the API response, (b) writing the iOS + Android platform-permission strings, (c) building a `PermissionFlow` service so the trackers + camera can request what they need at the right moment with proper copy.

**Files:**
- `apps/api/src/events/events.service.ts` — extend `bySlug` and `byId` to include `geofencePolygon: number[][]` (an array of `[lng, lat]` pairs) by `ST_AsGeoJSON(geofence_polygon)::json->'coordinates'->0`. Test against the BTS event slug — should return ~5 vertices.
- `apps/api/src/events/events.controller.ts` — no change; the response shape is already defined by Prisma's return + transformation.
- `apps/mobile/lib/data/remote/mappers.dart` — parse the new `geofencePolygon` field into `List<LatLng>` (default empty when missing for backward compat).
- `apps/mobile/ios/Runner/Info.plist` — add:
  - `NSLocationWhenInUseUsageDescription` — "smwhr usa tu ubicación para detectar cuando llegas al evento."
  - `NSLocationAlwaysAndWhenInUseUsageDescription` — "smwhr verifica que estuviste durante el evento. Solo trackea durante quests activas."
  - `NSMotionUsageDescription` — "smwhr usa datos de movimiento para ahorrar batería durante quests."
  - `NSCameraUsageDescription` — "smwhr usa la cámara para capturar tu momento en el evento."
  - `UIBackgroundModes` array: `location`, `fetch`, `remote-notification`.
- `apps/mobile/android/app/src/main/AndroidManifest.xml` — add `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`, `CAMERA`, `INTERNET`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`. Plus `<service>` declaration for the foreground service Locus uses on Android.
- `apps/mobile/lib/features/quest/services/permission_flow.dart` — orchestrator with these methods:
  - `Future<PermissionResult> requestForIntent(Event event)` — requests when-in-use location only. Called when the user taps "I'll be there" for the first time. Returns granted / denied / permanentlyDenied / notNeeded.
  - `Future<PermissionResult> requestForActiveQuest(Event event)` — requests Always location + motion. Called when the user taps "Start quest" inside the venue window.
  - `Future<PermissionResult> requestForCamera()` — requests camera. Called when the user taps the shutter.
  - Each method defers to `package:permission_handler`. Returns the raw status plus a UX-friendly hint (`shouldOpenSettings: true` when permanently denied).

**Done when:**
- Backend smoke: `curl https://crappie-patient-boxer.ngrok-free.app/events/bts-mexico-2026-n1` returns a JSON body with a non-empty `geofencePolygon` array.
- Mobile build runs on a real iOS device with all four privacy strings visible in Settings → smwhr.
- `PermissionFlow.requestForIntent(event)` invoked from a debug button correctly prompts the iOS "When-in-use" sheet and returns `granted` after acceptance.

**Commit:** `feat(quest): backend polygon JSON, ios/android perm strings, PermissionFlow`

---

### Session 2 — Hive tracking_db + adapters

**Goal:** persistent local accumulation for Locus events + Geolocator pings so a 30-min batch sync doesn't lose entries on app kill / OS reclaim.

**Files:**
- `apps/mobile/lib/data/local/tracking_db.dart` — owns one Hive box per eventId, named `tracking_<eventId>`. API:
  - `Future<void> open(String eventId)` / `Future<void> close(String eventId)`
  - `Future<void> appendLocusEvent(String eventId, LocusEvent e)`
  - `Future<void> appendGeolocatorPing(String eventId, GeolocatorPing p)`
  - `Future<List<LocusEvent>> unsyncedLocusEvents(String eventId)`
  - `Future<List<GeolocatorPing>> unsyncedGeolocatorPings(String eventId)`
  - `Future<void> markSynced({required List<String> locusIds, required List<String> pingIds})`
  - `Future<int> totalCount(String eventId)` (for diagnostics)
  - Internally: `synced` bool flag on each row; mark by id list.
- `apps/mobile/lib/data/local/adapters/locus_event_adapter.dart` — Hive `TypeAdapter<LocusEvent>` with `typeId: 1`.
- `apps/mobile/lib/data/local/adapters/geolocator_ping_adapter.dart` — `TypeAdapter<GeolocatorPing>` with `typeId: 2`.
- `apps/mobile/lib/main.dart` — register both adapters before `runApp` (only when `!Env.useMocks`).
- `apps/mobile/test/tracking_db_test.dart` — round-trip: write 5 locus events + 5 pings → close box → reopen → assert all round-tripped, none marked synced. Then `markSynced` half → reopen → assert correct synced/unsynced split.

**Done when:**
- `flutter test` passes the new file.
- Adapters use stable `typeId` values (1, 2). Document them in the file header so they don't clash with future adapters.

**Commit:** `feat(mobile): tracking_db (Hive) for dual-track persistence`

---

### Session 3 — LocusTracker + GeolocatorTracker

**Goal:** two independent tracker services, each writes to `TrackingDb` on its own callbacks. No orchestration yet — that's Session 4.

**Files:**
- `apps/mobile/lib/features/quest/services/locus_tracker.dart` — `LocusTracker.start({eventId, polygon, onEvent})`. Configures `package:locus` (high accuracy, distanceFilter 10, motionTriggerDelay 30, heartbeat 60), adds polygon geofence with `notifyOnEntry/Exit/Dwell` (loitering 60 s), wires listeners:
  - `Locus.onGeofenceEvent` → emit `LocusEvent.fromGeofence(event, eventId)`
  - `Locus.onLocationUpdate` → emit `LocusEvent.fromLocation(loc, eventId)`
  - `Locus.onMotionChange` → emit `LocusEvent.fromMotion(motion, eventId)`
  - Each `onEvent` writes to `TrackingDb`. Stop with `removeGeofence` + `Locus.stop`.
- `apps/mobile/lib/features/quest/services/geolocator_tracker.dart` — `GeolocatorTracker.start({eventId, interval, polygon, onPing})` with a `Timer.periodic(interval=5min)` that calls `Geolocator.getCurrentPosition(accuracy: high, timeLimit: 10s)`, computes `isInsidePolygon` via ray-casting (per CLAUDE.md), emits a `GeolocatorPing`. Skip ping if battery < 5 % (use `battery_plus` if not pulled in by deps; otherwise default to `true`).
- Inline ray-casting helper. Pure-fn extracted into a top-level function for testability.
- `apps/mobile/test/geolocator_tracker_test.dart` — feed the BTS GNP Seguros polygon (~ ±0.0015°) to the ray-cast function, assert: center point inside, points 0.005° away outside, edge points consistent.

**Done when:**
- Tests for ray-casting pass.
- Manual smoke: instantiate `LocusTracker` from a debug button against the BTS polygon at the office (or simulated location), see GEOFENCE_ENTER + LOCATION_UPDATE entries flowing into `TrackingDb`.
- Same for `GeolocatorTracker`: 1-min interval (override default for testing), see pings landing in Hive every minute.

**Commit:** `feat(quest): LocusTracker + GeolocatorTracker with TrackingDb writes`

---

### Session 4 — QuestTracker orchestrator + TrackingSync + RealQuestsRepository wire-up

**Goal:** the orchestrator that ties everything together and the screen finally drives off real state.

**Files:**
- `apps/mobile/lib/features/quest/services/quest_tracker.dart` — `QuestTracker.startQuest(Event event)`:
  1. `await PermissionFlow.requestForActiveQuest(event)` — if not granted, throw `QuestPermissionException`.
  2. `await TrackingDb.open(event.id)`.
  3. `await LocusTracker.start(eventId, event.geofencePolygon, onEvent: db.appendLocusEvent)`.
  4. `await GeolocatorTracker.start(eventId, interval: 5min, polygon, onPing: db.appendGeolocatorPing)`.
  5. `TrackingSync.schedulePeriodic(eventId, interval: 30min)`.
  And `stopQuest(eventId)`: stops both trackers, calls `TrackingSync.finalSync(eventId)`, closes the Hive box.
- `apps/mobile/lib/features/quest/services/tracking_sync.dart` — `TrackingSync.schedulePeriodic(eventId, interval)` arms a `Timer.periodic`; `syncBatch(eventId)` reads unsynced from `TrackingDb`, calls `RealQuestsRepository.syncTrackingBatch`, then `markSynced` with the returned ids. Swallow transient failures and log — next tick retries.
- `apps/mobile/lib/data/remote/real_quests_repository.dart` — replace the `UnimplementedError` in `startQuest` / `stopQuest` with a delegation to `QuestTracker`. Same for the now-defunct `getQuestStatus` polling lifecycle (we keep the API call, but the *local* state stream comes from QuestTracker).
- `apps/mobile/lib/features/quest/providers/quest_state_provider.dart` — `StateNotifierProvider` exposing `QuestStatus` derived from `TrackingDb` counts + the backend's `/quests/:id/status`. `active_quest_screen.dart` watches this provider; `dwellMinutes` comes from the most-recent `LocusEvent` with `eventType=GEOFENCE_DWELL` minus the GEOFENCE_ENTER timestamp.
- `apps/mobile/test/quest_tracker_test.dart` — fake Locus + fake Geolocator + fake TrackingDb + fake RealQuestsRepository. Assert: `startQuest` registers polygon and timer; `stopQuest` cancels both; `TrackingSync.syncBatch` calls the repo with the right shape; `syncBatch` skips the call when there's nothing unsynced.

**Done when:**
- `flutter test` green for the new + existing suites.
- Manual smoke (real device): RSVP to the BTS event, tap "Start quest", verify in dev console that `/quests/:id/sync` is hit every 30 min (or override interval to 30 s for testing) and the backend's `system_events` table has matching `QUEST_SYNC` rows.
- `getStatus` after a few minutes shows `pointsCollected > 0` and `locusEventsCount + geolocatorPingsCount` matching the local Hive counts.

**Commit:** `feat(quest): QuestTracker + TrackingSync + active screen wired to real state`

---

### Session 5 — Real CameraController capture

**Goal:** replace the procedural badge-frame preview with a live camera preview behind the frame, plus real `takePicture` on shutter.

**Files:**
- `apps/mobile/lib/features/camera/screens/camera_screen.dart` — replace shim. On mount: `await Camera.availableCameras()` → pick `lensDirection == back`, `ResolutionPreset.high` (1080×1920 target), init `CameraController`. Compose `CameraPreview(controller)` BEHIND the existing `BadgeFrameOverlay`. Dispose controller in `dispose()`. Handle permission denial gracefully — if `PermissionFlow.requestForCamera()` returns denied, show error state with "Open Settings" CTA.
- Shutter handler: `final XFile shot = await controller.takePicture()` → write to `getTemporaryDirectory()/<eventId>/<uuid>.jpg` → push to `/reveal/<badgeId>` carrying the file path. (Reveal still uses the badge metadata from the backend, just composites the captured photo on top.)
- Lifecycle: pause preview when app is backgrounded, resume on foreground.
- Confirm `flutter analyze` is still clean.

**Done when:**
- On a real device, opening the camera shows a live preview behind the badge frame.
- Shutter tap captures a real JPG to temp dir, surfaces in the reveal screen.
- Camera releases properly when leaving the screen (no orphaned process).

**Commit:** `feat(camera): real CameraController capture behind badge frame overlay`

---

### Session 6 — EXIF + photo upload + iOS background polish + real-device E2E

**Goal:** finish the loop — write/read EXIF, upload via the already-wired `RealQuestsRepository.uploadPhoto`, and verify the full E2E flow on a real device with the dual-track running in the background.

**Files:**
- `apps/mobile/lib/features/camera/services/exif_writer.dart` — uses `native_exif` to read `DateTimeOriginal`, `GPSLatitude`, `GPSLongitude`, full raw map from the captured file.
- `apps/mobile/lib/data/remote/real_quests_repository.dart` — extend `uploadPhoto` to also send `exifTimestamp`, `exifLatitude`, `exifLongitude`, `exifRaw` (JSON-stringified) as form fields. Backend already accepts these (verified in commit 6fd6516).
- `apps/mobile/lib/features/camera/screens/camera_screen.dart` — between capture and navigation: `final exif = await ExifReader.read(file)` → pass to `repo.uploadPhoto(eventId, file, metadata: exif)`. Backend returns `{photoId, isExifValid, isWithinTimeWindow, isInsideGeofence}` — surface failure (e.g. `isInsideGeofence=false`) as a soft warning, not a block.
- iOS `Info.plist`: confirm `UIBackgroundModes` includes `location` so Locus keeps tracking when the app is backgrounded for ≥ 30 s.
- Android `AndroidManifest.xml`: confirm a `<service android:name=".LocusForegroundService" android:foregroundServiceType="location"/>` is declared. Pin notification copy to "smwhr is verifying your quest. We'll let you know when it's done."
- **Real-device E2E:** new user → email OTP → onboarding → home → tap BTS event → "I'll be there" (when-in-use prompt) → wait until inside the venue window or use a dev override → tap "Start quest" (always-permission prompt) → walk around / drive away / come back to test geofence enter+exit → take photo → upload → reveal → view in profile collection. Backend's `/quests/:id/finalize` should mint a verified badge. Document the flow with screenshots in `docs/sprints/screenshots/quest-real-<timestamp>-*.png`.

**Done when:**
- A captured photo with EXIF lat/lng inside the polygon and timestamp inside the event window arrives at the backend with `isExifValid=true`, `isInsideGeofence=true`, `isWithinTimeWindow=true`.
- Manual force-finalize (`POST /quests/:id/finalize`) on the test user emits a verified Badge with the photo as `composedImageUrl` (or null until sharp pipeline lands; not a blocker).
- Background tracking continues for ≥ 5 min when the app is in the background on iOS and Android.

**Commit:** `feat(quest): EXIF capture + photo upload + real-device E2E pass`

---

## Locked decisions (resolve here before Session 1 starts)

1. **Backend polygon shape:** GeoJSON `coordinates[0]` (outer ring of a Polygon) → array of `[lng, lat]` pairs. Mobile maps to `List<LatLng>`. Empty list = no polygon → trackers fall back to the `geofenceRadiusM` circle around `geofence_center`. Locked.
2. **Hive `typeId` allocation:** `LocusEvent` = 1, `GeolocatorPing` = 2. Reserve 3-9 for future tracker additions. Document at the top of each adapter. Locked.
3. **Battery threshold for geolocator skips:** < 5 % → skip the ping (don't kill the user's phone). Don't pull `battery_plus` if not already a dep — default to "always ping" until that's wired. Locked.
4. **Sync cadence:** 30 minutes during active quest. Final sync on `stopQuest`. Locked.
5. **Geolocator interval:** 5 minutes. Configurable for tests but production fixed. Locked.
6. **Permission UX timing** (per `apps/mobile/CLAUDE.md`):
   - Onboarding screen 04: notifications only.
   - First "I'll be there" tap: when-in-use location.
   - "Start quest" inside the venue window: always location + motion.
   - Camera shutter: camera.
   Each gated through `PermissionFlow`. Locked.
7. **Background modes:** iOS — `location` + `fetch` + `remote-notification`. Android — `FOREGROUND_SERVICE_LOCATION` typed foreground service. Locked.
8. **Reveal flow** stays mostly as-is (procedural Flutter animation). The reveal screen receives `badgeId` from the backend's finalize response, reads `composedImageUrl` (or null). Photo composite is mobile-side via `BadgeFrameOverlay` for R0.1; sharp server-side render is post-launch. Locked.
9. **Multi-event quests:** out of scope. One active quest at a time. Locked.

---

## Definition of done (the whole sprint)

- All 6 session smokes passed and committed.
- A real iPhone + a real Android (mid-tier) can walk: signup → onboarding → home → event detail → set intent (with WhenInUse prompt) → start quest (with Always prompt) → tracker writes to local Hive AND syncs to `/quests/:id/sync` every 30 min → take photo → EXIF + upload → reveal → see badge in profile.
- Backend `system_events` shows the expected audit trail: `INTENT_SET` → `QUEST_SYNC` × N → `INTEGRITY_ATTESTED` → `PHOTO_UPLOADED` → `CHECKIN_FINALIZED` → `BADGE_ISSUED`.
- `flutter analyze` clean. `flutter test` green.
- `docs/sprints/2026-04-25-r01-handoff.md` "Phase 2 deferrals" rows for tracker / camera / EXIF flip from ❌ to ✅.

---

## Anti-patterns (for the agent executing this plan)

- ❌ Calling `Locus.start` without first checking that the polygon list is non-empty. Fall back to radius+center if backend hasn't surfaced the polygon.
- ❌ Wiring the trackers from inside a widget. They live in services and are constructed by `QuestTracker`.
- ❌ Hardcoded sync intervals or timeouts in the call sites — they live in `QuestTracker` config.
- ❌ Skipping permission flow because "the simulator doesn't ask anyway." The real device WILL ask.
- ❌ Letting a Locus event leak into the UI without going through `TrackingDb`. The DB is the single source of truth for what's been collected vs synced.
- ❌ Adding new Hive `typeId`s without updating the table at the top of `tracking_db.dart`.
- ❌ Catching `DioException` for sync errors and ignoring them silently. Log a warning; the next tick retries.

---

## Bootstrapping a fresh conversation

Paste this into the new session:

> I'm Moi, founder of smwhr. R0.1 mobile is real-mode-wired against the
> NestJS backend (auth, browse, intent, profile, badges, waitlist —
> all green). The active-quest pipeline (dual-track tracker + camera
> capture + EXIF + permissions) is the last gap before the 2026-05-05
> soft launch. The plan is in
> `docs/sprints/2026-04-25-mobile-quest-active.md` — 6 sessions,
> self-contained. Backend endpoints (`/quests/:id/sync`, `/photo`,
> `/integrity`, `/finalize`, `/status`) are already shipped and verified.
> Start with Session 1 (backend polygon export + iOS/Android perm
> strings + `PermissionFlow` service). Use
> `superpowers:executing-plans` and close every session with a real-
> device smoke + commit.
