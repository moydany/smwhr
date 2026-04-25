# Mobile R0.1 — Frontend-First Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete smwhr Flutter app for R0.1, navigable end-to-end, using mock repositories so the UI is shippable before the NestJS backend exists.

**Architecture:** Flutter + Riverpod + go_router. Repository pattern abstracts data access (`AuthRepository`, `EventsRepository`, `QuestsRepository`, `BadgesRepository`, `UsersRepository`) — `MockX` implementations live behind a `useMocks` flag flipped via `--dart-define`. UI never touches HTTP/Hive directly: it consumes Riverpod providers that read from the active repository.

**Tech Stack:** Flutter 3.24+, Dart 3.5+, Riverpod 2.5, go_router 14, dio 5.4, hive_flutter 1.1, supabase_flutter 2 (deferred to integration phase), camera 0.11, native_exif 0.6, locus 2 + geolocator 12 + permission_handler 11 (mocked through Session 7), lottie 3.1, flutter_svg 2, cached_network_image 3.3.

**Pacing:** timeline pressure ignored per founder direction (2026-04-24). Plan is sequenced as **14 × 4-hour sessions** but executed as fast as practical without artificial day boundaries. Soft launch 2026-05-05 remains the only fixed deadline.

**Global UX bar (non-negotiable, applies to every screen):**
- All animations and lists hold **60 fps** on mid-tier hardware. Profile-mode check at every smoke test.
- Every primary interaction emits **haptic feedback** via `HapticFeedback.lightImpact()` (taps), `selectionClick()` (toggles), `mediumImpact()` (commits), `heavyImpact()` (reveal moment).
- Page transitions follow `ONBOARDING_FLOW.md` curves; default is `Curves.easeOutCubic` 280 ms.

**Visual source of truth:** founder will deliver an **HTML design system + screen mocks** (not the PDF in `design/mocks/v1/`, which is superseded). Sessions that touch visual surface (3+) wait on the HTML drop or use it once received. Foundation sessions (1, 2) proceed against tokens already in `apps/mobile/CLAUDE.md`.

---

## File structure (locked before tasks)

```
apps/mobile/
├── pubspec.yaml
├── analysis_options.yaml
├── lib/
│   ├── main.dart                                  # entrypoint + ProviderScope
│   ├── app.dart                                   # MaterialApp.router
│   ├── core/
│   │   ├── theme/{app_colors,app_typography,app_spacing,app_theme}.dart
│   │   ├── router/app_router.dart                 # go_router config
│   │   ├── config/env.dart                        # useMocks flag
│   │   └── constants/api_constants.dart
│   ├── shared/
│   │   ├── widgets/{primary_button,secondary_button,smwhr_text_field,
│   │   │           progress_dots,status_pill,smwhr_scaffold}.dart
│   │   └── utils/{date_format,delay,handle_validator}.dart
│   ├── data/
│   │   ├── models/{user,event,badge,intent,quest_status,
│   │   │            locus_event,geolocator_ping}.dart
│   │   ├── repositories/                           # ABSTRACT interfaces
│   │   │   ├── auth_repository.dart
│   │   │   ├── users_repository.dart
│   │   │   ├── events_repository.dart
│   │   │   ├── quests_repository.dart
│   │   │   └── badges_repository.dart
│   │   ├── mock/                                   # mock impls + fixtures
│   │   │   ├── mock_users.dart
│   │   │   ├── mock_events.dart
│   │   │   ├── mock_badges.dart
│   │   │   ├── mock_intents.dart
│   │   │   ├── mock_auth_repository.dart
│   │   │   ├── mock_users_repository.dart
│   │   │   ├── mock_events_repository.dart
│   │   │   ├── mock_quests_repository.dart
│   │   │   └── mock_badges_repository.dart
│   │   └── remote/                                 # real impls (Phase 2)
│   │       ├── api_client.dart
│   │       └── *_api.dart
│   └── features/
│       ├── auth/screens/splash_auth_screen.dart
│       ├── onboarding/
│       │   ├── providers/onboarding_state.dart
│       │   └── screens/{identity,interests,permissions}_screen.dart
│       ├── events/
│       │   ├── providers/events_provider.dart
│       │   ├── screens/{home_feed,event_detail}_screen.dart
│       │   └── widgets/{event_card,featured_card,badge_preview_locked}.dart
│       ├── quest/
│       │   ├── providers/quest_state_provider.dart
│       │   ├── screens/active_quest_screen.dart
│       │   ├── services/{quest_tracker,locus_tracker,
│       │   │             geolocator_tracker,tracking_sync}.dart
│       │   └── widgets/{quest_timer,verification_checks,dwell_progress}.dart
│       ├── camera/
│       │   ├── screens/camera_screen.dart
│       │   └── widgets/badge_frame_overlay.dart
│       ├── badges/
│       │   ├── screens/{reveal,badge_detail}_screen.dart
│       │   └── widgets/{badge_card,serial_label}.dart
│       ├── profile/
│       │   ├── screens/profile_screen.dart
│       │   └── widgets/{profile_stats,collection_grid}.dart
│       └── share/
│           ├── screens/share_screen.dart
│           └── services/share_image_generator.dart
├── test/
│   ├── widget/{primary_button,smwhr_text_field,event_card}_test.dart
│   ├── golden/{badge_card,featured_card}_golden_test.dart
│   └── flow/onboarding_happy_path_test.dart
└── assets/
    ├── fonts/{SpaceGrotesk,Inter,JetBrainsMono}/*
    ├── icons/*.svg                               # phosphor/lucide-style line icons
    ├── lottie/badge_reveal.json                  # placeholder until designer ships
    └── frames/                                   # badge frame templates per vertical
```

---

## Session-level plan (14 × 4-hour blocks)

Each session has: **Goal**, **Files**, **Definition of done**, **Commit message**. Day labels are removed — execute sequentially.

**Per-session smoke test (mandatory close-out):** boot the app on iPhone 15 sim in profile mode, walk the surface added that session, screenshot the result, verify 60 fps in the DevTools performance overlay. No commit lands without the smoke pass.

### Session 1 — Bootstrap + design tokens
**Files:** `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `lib/core/theme/*`, `assets/fonts/`
**Goal:** Empty Flutter app boots on iOS sim with dark theme + 3 typefaces + magenta accent.
**Done when:** `flutter run` shows a black screen with `Text('smwhr', style: AppTypography.display)` rendered in Space Grotesk on magenta.
**Commit:** `chore(mobile): bootstrap flutter project with design tokens`

### Session 2 — Router + Repository abstractions + mock seeds**Files:** `lib/core/router/app_router.dart`, `lib/core/config/env.dart`, `lib/data/models/*`, `lib/data/repositories/*`, `lib/data/mock/mock_users.dart`, `mock_events.dart`, `mock_badges.dart`, `mock_intents.dart`
**Goal:** go_router with 11 named routes (placeholders), `useMocks=true` Riverpod provider, freezed-style data models, mock fixtures hydrated.
**Done when:** every route navigable from a debug menu screen, mock data loads via repository providers.
**Commit:** `feat(mobile): repository abstractions, router, and mock seed data`

### Session 3 — Shared widgets + Splash/Auth (Pantalla 01)
**Files:** `lib/shared/widgets/*`, `lib/features/auth/screens/splash_auth_screen.dart`, `lib/data/mock/mock_auth_repository.dart`
**Goal:** Reusable button + text field + progress dots; splash animation → 3 auth buttons (Apple, Google, Email) that mock-login and route to `/onboarding/identity` for new users or `/home` for returning.
**Done when:** widget tests pass for buttons + text field; splash → auth tap → onboarding navigation works end-to-end.
**Commit:** `feat(mobile): splash/auth screen with mock providers`

### Session 4 — Onboarding 02–04
**Files:** `lib/features/onboarding/**`, `lib/shared/utils/handle_validator.dart`
**Goal:** Identity (handle live-validation against reserved list with simulated 400ms latency), Interests (5 categories + "Everything"), Permissions (notifications stub). State machine via `onboardingStateProvider`. Final tap routes to `/home`.
**Done when:** integration test `onboarding_happy_path_test.dart` walks all 4 screens green.
**Commit:** `feat(mobile): onboarding flow screens 02-04 with validation`

### Session 5 — Home feed
**Files:** `lib/features/events/screens/home_feed_screen.dart`, `lib/features/events/widgets/{event_card,featured_card}.dart`, `lib/features/events/providers/events_provider.dart`
**Goal:** Featured carousel + grid of 16 mock LATAM events. Pull-to-refresh, skeleton loading state, empty state. BTS hero event pinned at top.
**Done when:** Golden test passes for `featured_card` and `event_card`; tapping an event routes to detail screen.
**Commit:** `feat(mobile): home feed with featured + event grid`

### Session 6 — Event detail
**Files:** `lib/features/events/screens/event_detail_screen.dart`, `lib/features/events/widgets/badge_preview_locked.dart`
**Goal:** Hero poster, event metadata, locked badge preview (silhouette + "?"), "I'll be there" intent button (toggles via mock repo), other-attendees stub avatars.
**Done when:** Tapping intent updates UI optimistically + persists in mock repo across navigation.
**Commit:** `feat(mobile): event detail with locked badge preview and intent toggle`

### Session 7 — Active quest screen + mock tracking
**Files:** `lib/features/quest/**` (incl. abstract `LocusTracker`/`GeolocatorTracker` interfaces with mock impls), `mock_quests_repository.dart`
**Goal:** Quest timer animating 1 sec = 1 mock minute, four verification checks (GPS / device trusted / integrity / photo) lighting up over time, "Take photo" button enabled at 30 mock-min dwell.
**Done when:** Cold-start a quest from event detail → screen shows live progression to "ready to capture".
**Commit:** `feat(mobile): active quest screen with mock dual-track simulation`

### Session 8 — Camera screen + EXIF stub
**Files:** `lib/features/camera/**`
**Goal:** In-app camera (no gallery), badge-frame overlay (per-vertical SVG), capture → preview → confirm flow. Mock EXIF metadata writer.
**Done when:** Captured photo persists to temp dir, surfaces in next screen, EXIF-stub returns expected timestamp + GPS payload.
**Commit:** `feat(mobile): camera capture with badge frame overlay`

### Session 9 — Reveal animation + badge detail
**Files:** `lib/features/badges/**`
**Goal:** **Procedural reveal in pure Flutter** — `AnimationController` 1.6s + `Tween` chain on `Curves.easeOutBack`: frame slides in (0–500 ms) → photo composites with scale + opacity (400–1000 ms) → serial number types out `#0001/∞` JetBrains Mono (1000–1600 ms). Heavy haptic at the photo-composite moment. Badge detail screen with stats and metadata. Lottie swap deferred to Phase 2.
**Done when:** Reveal plays once at 60 fps profile-mode, then routes to badge detail; serial number is deterministic from mock badge id.
**Commit:** `feat(mobile): badge reveal animation and detail screen`

### Session 10 — Profile + collection
**Files:** `lib/features/profile/**`
**Goal:** Profile screen for `@moi` with stats (quests / venues / artists), collection grid (6–8 mock badges), tap-through to badge detail.
**Done when:** Pulls from `mock_badges.dart` + `mock_users.dart`, scroll perf > 55 fps on iPhone 14.
**Commit:** `feat(mobile): profile and collection screens`

### Session 11 — Share screen + image gen
**Files:** `lib/features/share/**`
**Goal:** Compose 1080×1920 share image via `RepaintBoundary` → `dart:ui` → save to temp + share-sheet hand-off.
**Done when:** Generated PNG opens in iOS share sheet pre-formatted for Instagram Stories.
**Commit:** `feat(mobile): share screen with story image generator`

### Session 12 — Polish pass: animations + empty/error states
**Files:** scattered touch-ups
**Goal:** Page transitions match `ONBOARDING_FLOW.md` (fade-through for splash→auth, slide for onboarding steps), every list/screen has an empty + error state, haptics on key actions.
**Done when:** Visual demo on a real device feels production-grade.
**Commit:** `feat(mobile): animations, haptics, empty and error states`

### Session 13 — Real-device QA + perf + E2E
**Goal:** Run on iPhone 14 + a real Android device (mid-tier). Profile-mode build, fix any frame drops, verify dark-mode-only on both platforms. **Full E2E integration test** walks splash → onboarding → home → event detail → quest → camera → reveal → profile → share.
**Done when:** No jank on slow device; install footprint < 60 MB; E2E green on both platforms.
**Commit:** `chore(mobile): perf pass and device-specific fixes`

### Session 14 — Buffer / Phase-2 prep
**Goal:** Wire `EnvConfig.useMocks=false` switch to throw not-implemented stubs, document the cut-over checklist, prep `dio` interceptor scaffolding so backend integration in Phase 2 is plumbing-only.
**Done when:** `--dart-define=USE_MOCKS=false` boots and shows clear stub errors per repository.
**Commit:** `chore(mobile): real-repository scaffolding for backend integration phase`

---

## First 5 concrete tasks (Session 1, today)

These are the bite-sized steps for the first ~90 minutes — enough to verify the toolchain and unblock everything else.

- [ ] **Task 1: Initialize Flutter project in apps/mobile**
  ```bash
  cd /Volumes/Storage/Projects/smwhr/apps/mobile
  flutter create --org dev.orbit-m --project-name smwhr \
                 --platforms=ios,android --description "smwhr mobile" .
  flutter --version  # verify ≥ 3.24, Dart ≥ 3.5
  ```
  Expected: project scaffolded, no errors.

- [ ] **Task 2: Pin dependencies in pubspec.yaml**
  Add (exact versions per `apps/mobile/CLAUDE.md`): flutter_riverpod ^2.5, go_router ^14.0, dio ^5.4, flutter_secure_storage ^9.0, hive_flutter ^1.1, locus ^2.0, geolocator ^12.0, permission_handler ^11.0, workmanager ^0.5, camera ^0.11, native_exif ^0.6, sign_in_with_apple ^6.0, google_sign_in ^6.2, firebase_messaging ^15.0, flutter_local_notifications ^17.0, flutter_svg ^2.0, lottie ^3.1, cached_network_image ^3.3, supabase_flutter ^2.0.
  Run `flutter pub get`. Expected: no version conflicts. (If `locus 2.0` resolves with a constraint conflict, escalate — do not auto-bump major versions.)

- [ ] **Task 3: Drop in fonts and add `assets:` block**
  Place Space Grotesk, Inter, JetBrains Mono TTFs under `assets/fonts/<family>/`. Wire them in `pubspec.yaml` under `flutter: fonts:`. Run `flutter pub get` again.

- [ ] **Task 4: Create design tokens (`lib/core/theme/`)**
  Files: `app_colors.dart` (background `#050505`, surface `#0E0E0E`, accent `#FF2D95`, text primary `#FFFFFF`, text muted `#9A9A9A`, divider `#1F1F1F`, error `#FF4D4D`), `app_typography.dart` (Space Grotesk display 32/24/20, Inter body 16/14/12, JetBrains Mono caption 12/10), `app_spacing.dart` (`xxs=4 xs=8 sm=12 md=16 lg=24 xl=32 xxl=48 xxxl=64`), `app_theme.dart` (dark `ThemeData` composing the above).
  No comments unless a value is non-obvious.

- [ ] **Task 5: Wire main.dart and verify on simulator**
  `lib/main.dart` → `runApp(ProviderScope(child: MaterialApp(theme: AppTheme.dark, home: SmokeScreen())))`. `SmokeScreen` is a temporary widget that renders `Text('smwhr — you were somewhere.', style: AppTypography.displayLarge)` centered on `AppColors.background` with the magenta accent underline.
  Run `flutter run -d "iPhone 15"`. Expected: black screen, white display text, magenta accent rendered. **Commit:** `chore(mobile): bootstrap flutter project with design tokens`.

After Task 5, stop and confirm the screenshot before starting Session 2.

---

## Locked decisions (resolved 2026-04-24 by founder)

1. **Visual source of truth:** founder-provided **HTML design system + screen mocks**. PDF in `design/mocks/v1/` is superseded and ignored. Sessions touching visual surface (3+) consume the HTML once delivered; foundation Sessions 1–2 proceed against tokens in `apps/mobile/CLAUDE.md`.
2. **Pacing:** ignore the original cronograma. Execute sessions back-to-back as fast as quality allows.
3. **Auth in mock mode:** stubs only. Tap any provider button → simulated **800–1200 ms** latency (random within range) → instant `mockCurrentUser` session. Real OAuth deferred to Phase 2.
4. **Storage:** **in-memory** for fixtures (events, users, badges, intents). **Hive** for (a) `tracking_db` (dual-track logs) and (b) **auth session persistence** (token + current user across cold starts).
5. **Screen count:** **11 total** confirmed — 4 onboarding (01 Splash/Auth, 02 Identity, 03 Interests, 04 Permissions) + 7 core (05 Home, 06 Event Detail, 07 Active Quest, 08 Camera, 09 Reveal, 10 Profile, 11 Share).
6. **Testing discipline:** pragmatic. Widget tests **only for non-trivial logic** (handle validator, quest state machine, share image generator). **Smoke test on simulator at the close of every session** (mandatory). **Full E2E only in Session 13** (real-device QA).
7. **Plan location:** `docs/sprints/2026-04-24-mobile-r01-frontend-first.md`. Index lives at `docs/sprints/README.md`.
8. **Reveal animation:** procedural in Flutter — `AnimationController` 1.6s + `Tween` chain on `Curves.easeOutBack`. Lottie swap is Phase 2 if-decided.

## Global UX requirements (apply to every session)

- **60 fps everywhere.** Smoke close-out runs profile mode and checks DevTools performance overlay. Any frame drop blocks the commit.
- **Haptic feedback** on every primary interaction:
  - `HapticFeedback.lightImpact()` — taps on cards, list items
  - `HapticFeedback.selectionClick()` — toggles, segment switches, interest chips
  - `HapticFeedback.mediumImpact()` — commit actions (intent toggle, photo capture, share)
  - `HapticFeedback.heavyImpact()` — reveal moment, badge unlock
- Default page transition: `Curves.easeOutCubic` 280 ms. Splash→Auth uses fade-through 500 ms per spec.
