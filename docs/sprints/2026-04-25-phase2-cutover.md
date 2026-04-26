# Phase 2 cutover — mocks → real backend

> **Status:** ✅ shipped 2026-04-25 (commits c4449c7 → 8a4f8c7).
>
> Auth + onboarding + browse + intent + profile + badges (catalog) +
> waitlist all run against the real NestJS backend on Supabase.
> The remaining Phase-2 work — Locus + Geolocator dual-track, real
> camera capture, EXIF writes, permission flow — is sequenced in
> [2026-04-25-mobile-quest-active.md](./2026-04-25-mobile-quest-active.md).

This doc is the historical cutover guide. Items marked ✅ landed in
the cutover; items marked ❌ are intentionally deferred and have a
named follow-up plan.

## Pre-flight (state at cutover time)

- ✅ NestJS API deployed at a stable URL — `https://crappie-patient-boxer.ngrok-free.app` (ngrok tunnel to local `:4000` for dev). Railway deploy still pending.
- ✅ Supabase project provisioned (auth, storage `photos`/`badges`/`avatars` buckets, PostGIS in `extensions` schema, all migrations applied).
- ❌ OAuth providers configured — deferred to release window. Apple/Google buttons in app surface "not configured yet" snack.
- ❌ Push provider keys — `NotificationService` logs payload only; FCM/APNs swap is post-launch.
- ✅ `.env` file (`apps/api/.env`) with the 6 Supabase vars; mobile uses `--dart-define` at run time.

## Real-mode build (works today)

```bash
cd apps/mobile
flutter run \
  --dart-define=USE_MOCKS=false \
  --dart-define=API_BASE_URL=https://crappie-patient-boxer.ngrok-free.app
```

`SUPABASE_URL` / `SUPABASE_ANON_KEY` are not needed by the mobile —
only the backend talks to Supabase directly.

## What lives where

| Concern | Mock layer | Real layer |
|---|---|---|
| Auth | `lib/data/mock/mock_auth_repository.dart` (Hive `mock_auth` box) | `lib/data/remote/real_auth_repository.dart` + `auth_token_store.dart` (Hive `auth_session` box) |
| Users | `lib/data/mock/mock_users_repository.dart` | `lib/data/remote/real_users_repository.dart` (`/me`, `/users/:handle`, `/users/:handle/badges`) |
| Events | `lib/data/mock/mock_events_repository.dart` | `lib/data/remote/real_events_repository.dart` (`/events`, `/events/:slug`, `/events/by-id/:id`, `/events/:id/intent`) |
| Quests (API methods) | `lib/data/mock/mock_quests_repository.dart` (timer simulation) | `lib/data/remote/real_quests_repository.dart` (status / sync / photo / integrity / finalize) |
| Quests (tracker lifecycle) | mock timer | ❌ pending — see active-quest plan |
| Badges | `lib/data/mock/mock_badges_repository.dart` | `lib/data/remote/real_badges_repository.dart` (`/me/badges`, `/badges/:id`, `/badges/:id/share`) |
| HTTP client | n/a | `lib/data/remote/api_client.dart` (Dio singleton + AuthInterceptor backed by `AuthTokenStore`) |
| Mappers | n/a | `lib/data/remote/mappers.dart` (User/Event/Badge/QuestStatus fromJson + User toJson for Hive cache) |

## Implementation steps — done in cutover

1. ✅ **Flesh out `RealAuthRepository`.** Email OTP flow (`/auth/email/request`, `/auth/email/verify`, `/auth/refresh`, `/auth/logout`), `completeOnboarding`, `checkHandleAvailable`. State stream + `currentState`. Cached User + AuthSession in Hive. Apple/Google sign-in returns `AuthResultFailure("not configured yet")` until provider creds land.
2. ✅ **`AuthTokenStore`** owns the Hive `auth_session` box AND implements `AuthTokenSource` for the Dio interceptor. `RealAuthRepository` registers a refresh callback against it; 401s rotate the access token and retry the request automatically.
3. ✅ **`apiClientProvider`** wired through the store in real mode.
4. ✅ **Read paths**: `RealEventsRepository.{listEvents, listFeatured, getEventBySlug, getEventById}`, `RealUsersRepository.{getMe, getUserByHandle, getUserBadges}`, `RealBadgesRepository.{listMyBadges, getBadge, getShareImageUrl}`. Each maps Dio responses onto the existing domain models via `mappers.dart`.
5. ✅ **Write paths**: `setIntent` / `removeIntent` (idempotent on backend, both return updated `Event`), `completeOnboarding` (`POST /me/onboarding`), `WaitlistRepository`-level `POST /waitlist`.
6. ✅ **Splash UI**: replaces hardcoded `mock@smwhr.dev` request with a bottom-sheet flow — stage 1 collects email, stage 2 the 6-digit OTP. Apple/Google buttons stay visible and surface the deferral message via snack.
7. ✅ **Router redirect**: bounces signed-in users from `/` to `/home` (or `/onboarding/identity` if not onboarded). Reads `authRepositoryProvider.currentState` synchronously to avoid the StreamProvider's first-tick `loading` race.
8. ✅ **Default boot**: splash in both modes. `--dart-define=BOOT_AT_DEBUG=true` opts into the `/_debug` menu (mock mode only).
9. ✅ **Custom Supabase email template**: [`docs/email-templates/magic-link.html`](../email-templates/magic-link.html) renders the 6-digit `{{ .Token }}` in the smwhr visual language. Default Supabase template ships only `{{ .ConfirmationURL }}` — overrides in dashboard.

## Implementation steps — pending

10. ❌ **Replace `MockQuestsRepository` simulation with real Locus + Geolocator wiring.** Per `apps/mobile/CLAUDE.md` § "Arquitectura dual-track":
    - `services/locus_tracker.dart` for the primary tracker
    - `services/geolocator_tracker.dart` for the shadow
    - `services/tracking_sync.dart` for the batch upload (uses `RealQuestsRepository.syncTrackingBatch` already wired)
    - `services/quest_tracker.dart` orchestrator
11. ❌ **Hive adapters** for `LocusEvent` + `GeolocatorPing` so `tracking_db` survives app kills.
12. ❌ **Real CameraController + EXIF write** in `camera_screen.dart`.
13. ❌ **Permission flow** (when-in-use → always, camera, motion).
14. ❌ **Deeplink scheme** (`smwhr://`) for Supabase magic-link redirects + Instagram Stories share callbacks.
15. ❌ **Bundle TTF fonts** under `assets/fonts/` and remove `google_fonts` from `pubspec.yaml`.
16. ❌ **Railway deploy** of the API so we move off the ngrok tunnel.

Items 10-13 are the active-quest sprint. See
[2026-04-25-mobile-quest-active.md](./2026-04-25-mobile-quest-active.md).

## What the UI stays unaware of

The 11 screens never need to change. Each consumes one of:
- `authRepositoryProvider` (4 screens: splash + 3 onboarding)
- `eventsRepositoryProvider` (3 screens: home, event detail, quest)
- `questsRepositoryProvider` (2 screens: active quest, camera)
- `badgesRepositoryProvider` (3 screens: reveal, badge detail, share)
- `usersRepositoryProvider` (1 screen: profile)

## Anti-patterns to avoid

- ❌ Reaching past a repository to call Dio directly from a widget.
- ❌ Letting a backend-shaped DTO leak into a screen — always map at `lib/data/remote/mappers.dart`.
- ❌ Bypassing `AuthInterceptor` on a one-off request.
- ❌ Adding new screens without a matching repository method.

## Smoke test on cutover

After the first real build, work the manual QA checklist
([2026-04-25-r01-manual-qa-checklist.md](./2026-04-25-r01-manual-qa-checklist.md))
against the real backend. Any divergence between mock and real is a
bug in the real impl, not in the UI.
