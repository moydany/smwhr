# Phase 2 cutover — mocks → real backend

> Drop-in checklist for swapping `Env.useMocks=true` for `false` once
> the NestJS API + Supabase project are live. Every UI screen already
> consumes the abstract repositories — Phase 2 is plumbing, not
> redesign.

## Pre-flight (before flipping the flag)

- [ ] NestJS API deployed at a stable URL (Railway prod or staging).
- [ ] Supabase project provisioned (auth, storage `photos`, storage
      `badges`, RLS policies live).
- [ ] OAuth providers configured (Apple Developer team + Google
      Console + Supabase redirect URLs).
- [ ] Push provider keys in place (firebase_messaging or OneSignal).
- [ ] `.env` file at repo root with the real values for:
      `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`.

## Real-mode build

Build with the runtime flag flipped:

```bash
flutter build ios --release \
  --dart-define=USE_MOCKS=false \
  --dart-define=API_BASE_URL=https://api.smwhr.dev \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

The router redirect, providers, and Hive bootstrap all already check
`Env.useMocks`. There is no rebuild of the UI tree.

## What lives where

| Concern | Mock layer | Real layer |
|---|---|---|
| Auth | `lib/data/mock/mock_auth_repository.dart` (Hive `mock_auth` box) | `lib/data/remote/real_auth_repository.dart` (Supabase Auth + `/auth/*`) |
| Users | `lib/data/mock/mock_users_repository.dart` | `lib/data/remote/real_users_repository.dart` (`/me`, `/users/:handle`) |
| Events | `lib/data/mock/mock_events_repository.dart` | `lib/data/remote/real_events_repository.dart` (`/events`, `/events/:id/intent`) |
| Quests | `lib/data/mock/mock_quests_repository.dart` (timer simulation) | `lib/data/remote/real_quests_repository.dart` + Locus + Geolocator |
| Badges | `lib/data/mock/mock_badges_repository.dart` | `lib/data/remote/real_badges_repository.dart` (`/me/badges`, `/badges/:id`) |
| HTTP client | n/a | `lib/data/remote/api_client.dart` (Dio singleton + AuthInterceptor) |

## Implementation steps (in order)

1. **Flesh out `RealAuthRepository`.**
   - Wire Supabase Auth's PKCE flow for Apple + Google.
   - Implement `/auth/email/request` + `/auth/email/verify` against the
     NestJS magic-link endpoints.
   - Replace the Hive `mock_auth` box with `auth_session` (same JSON
     payload — see `lib/data/models/user.dart` `AuthSession.toJson`).
   - Implement `AuthTokenSource` so the Dio interceptor can read the
     access token. Wire it in `apiClientProvider` (lib/data/providers.dart).
2. **Flesh out the read paths**: `RealEventsRepository.listEvents`,
   `getEventBySlug`, `RealUsersRepository.getMe`. Map each Dio response
   onto the existing domain models. The screens are already consuming
   them.
3. **Flesh out the write paths**: intents, completeOnboarding, photo
   upload (multipart).
4. **Replace `MockQuestsRepository` simulation with real Locus +
   Geolocator wiring.** Per `apps/mobile/CLAUDE.md` § "Arquitectura
   dual-track":
   - `services/locus_tracker.dart` for the primary tracker.
   - `services/geolocator_tracker.dart` for the shadow.
   - `services/tracking_sync.dart` for the batch upload.
   - `services/quest_tracker.dart` orchestrator.
5. **Add Hive adapters** for `LocusEvent` + `GeolocatorPing` so
   tracking_db survives app kills (currently the mock keeps everything
   in memory).
6. **Add deeplink scheme** (`smwhr://`) for Supabase magic-link
   redirects + Instagram Stories share callbacks.
7. **Wire the `BOOT_AT_SPLASH` / `BOOT_AT` env overrides off in
   release builds** — they're design QA aids, not user-facing.
8. **Bundle TTF fonts** under `assets/fonts/` and remove
   `google_fonts` from `pubspec.yaml`. Uncomment the `fonts:` block
   in pubspec.

## What the UI stays unaware of

The 11 screens never need to change. Each consumes one of:
- `authRepositoryProvider` (4 screens: splash + 3 onboarding)
- `eventsRepositoryProvider` (3 screens: home, event detail, quest)
- `questsRepositoryProvider` (2 screens: active quest, camera)
- `badgesRepositoryProvider` (3 screens: reveal, badge detail, share)
- `usersRepositoryProvider` (1 screen: profile)

## Anti-patterns to avoid during Phase 2

- ❌ Reaching past a repository to call Dio directly from a widget.
- ❌ Letting a mock-shaped DTO leak into a screen — always map at the
      repository boundary.
- ❌ Bypassing `AuthInterceptor` on a one-off request.
- ❌ Adding new screens without a matching repository method.

## Smoke test on cutover

After the first real build, work the manual QA checklist
(`docs/sprints/2026-04-25-r01-manual-qa-checklist.md`) against the
real backend. Any divergence between mock and real is a bug in the
real impl, not in the UI.
