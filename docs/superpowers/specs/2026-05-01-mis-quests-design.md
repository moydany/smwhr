# Mis quests — design spec

**Date:** 2026-05-01
**Author:** Mobile + Backend agents (paired)
**Scope:** R0.1 — extends profile/quest discovery surface
**Replaces:** Current `QuestHistoryScreen` (badges-only) behaviour

---

## Goal

Surface every event the current user has marked intent on — past, live, and upcoming — in a single chronological list. Each row reveals the quest outcome at a glance (verified / not verified / live / upcoming) and is tappable into the right destination (badge reveal or event detail).

The trigger: today, if a user RSVPs to an event but the verifier doesn't issue a badge (not enough presence, finalize never landed, cron filter bug — see prior fix), the event vanishes from their profile. There is no surface to revisit it, retry the claim, or even confirm "I tried."

## Non-goals

- New filters / tabs / search inside the screen — the list is single-axis (chronological)
- Sharing the list itself — shareable units are still individual badges
- Listing other people's intents — out-of-scope until R1.0 social layer
- A "Reclamable" pill in the list — claimability is decided inside `event_detail_screen` (where the manual "Reclamar insignia" CTA already lives post the prior bug-fix); duplicating it on the list would force the API to recompute task gates per row

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ apps/mobile/lib/features/profile/screens/                │
│ quest_history_screen.dart                                │
│   ↓ watches                                              │
│ _myQuestsProvider (FutureProvider.autoDispose)           │
│   ↓ calls                                                │
│ QuestsRepository.listMyQuests() ──► RealQuestsRepository │
│                                  └► MockQuestsRepository │
└─────────────────────────────────────────────────────────┘
                         │ HTTP GET /me/quests
                         ▼
┌─────────────────────────────────────────────────────────┐
│ apps/api/src/users/users.controller.ts                   │
│   @Get('me/quests') → MyQuestsService.listForUser(user)  │
│                                                          │
│ apps/api/src/quests/services/my-quests.service.ts        │
│   • Loads intents + events + checkins + badges in 1 trip │
│   • Computes phase from event.startsAt / endsAt          │
│   • Computes status from phase + badge presence          │
│   • Sorts by event.startsAt DESC                         │
└─────────────────────────────────────────────────────────┘
```

## Backend

### Endpoint

`GET /me/quests` — auth required, current user only.

Mounted from `users.controller.ts` (existing `/me`-prefixed routes live there). The handler delegates to a new `MyQuestsService` housed in `apps/api/src/quests/services/my-quests.service.ts` so the data shape stays in the quests domain. `UsersModule` imports `QuestsModule` (or re-exports the service) — pick whichever keeps the dependency graph cycle-free; the existing `events ↔ quests` boundary is the reference.

### Response shape

```ts
{
  quests: Array<{
    event: {
      id: string;
      slug: string;
      title: string;
      artistName: string | null;
      venueName: string;
      city: string;
      category: string;        // EventCategory enum
      heroImageUrl: string | null;
      startsAt: string;        // ISO 8601
      endsAt: string;
    };
    intentCreatedAt: string;
    phase: 'pre' | 'during' | 'post';
    checkin: {
      isVerified: boolean;
      verificationScore: number;
      reconciledAt: string | null;
    } | null;
    badge: {
      id: string;
      serialNumber: number;
      awardedAt: string;
    } | null;
    status: 'upcoming' | 'live' | 'verified' | 'unverified';
  }>;
}
```

### Status derivation (server-authoritative)

```
phase = pre        → upcoming
phase = during     → live
phase = post + badge != null → verified
phase = post + badge == null → unverified
```

Phase mirrors `QuestsService.getStatus`'s rule (`now <= endsAt + 1h` is still `during` for the grace window). Keeping the same rule means the list and the detail screen never disagree about whether an event is "live" or "post."

### Sort order

`event.startsAt DESC` — most recent first. Ties broken by `intentCreatedAt DESC`. Pagination is YAGNI for R0.1 (a typical user has <50 intents); cap at 200 with a `take: 200` for safety.

### Query strategy

Single Prisma `findMany` on `Intent` with `include: { event: true }`, then a parallel pair of `findMany` on `Checkin` and `Badge` filtered by the same `(userId, eventId)` set. Stitched into the response in memory. Avoids N+1; avoids correlated subqueries Prisma can't express cleanly.

### Errors

- 401 if no auth (existing `JwtAuthGuard` covers this)
- Empty array on no intents — never throws

---

## Mobile

### New types — `apps/mobile/lib/data/models/quest.dart`

```dart
enum MyQuestStatus { upcoming, live, verified, unverified }
enum QuestPhase { pre, during, post }

class MyQuestEntry {
  final Event event;
  final DateTime intentCreatedAt;
  final QuestPhase phase;
  final MyQuestStatus status;
  final QuestVerification? verification;  // checkin summary, null pre-finalize
  final BadgeSummary? badge;              // null until awarded
}

class QuestVerification {
  final bool isVerified;
  final double verificationScore;
  final DateTime? reconciledAt;
}

class BadgeSummary {
  final String id;
  final int serialNumber;
  final DateTime awardedAt;
}
```

`MyQuestEntry` is a value type (immutable, `==` based on `event.id`). Lives next to `QuestStatus` since it's a quest-domain projection.

### Repository contract

`QuestsRepository.listMyQuests(): Future<List<MyQuestEntry>>`

Mock impl synthesizes 5 entries spanning all four states off the existing seeded events. Real impl GETs `/me/quests` and runs through `myQuestEntryFromJson` in `mappers.dart`.

### Screen — `quest_history_screen.dart`

Replace `_myBadgesProvider` with `_myQuestsProvider`. Visual scaffold (`_TopBar`, `_DateBlock`, `_CategoryDot`, layout) stays. Two changes:

1. **Status pill** generalized — `_StatusPill(status: MyQuestStatus)` replaces `_VerifiedPill`. Color + label table:

   | Status        | Bg                      | Text color           | Label            |
   |---------------|-------------------------|----------------------|------------------|
   | `verified`    | `accentGlow`            | `accent`             | `VERIFIED ✓`     |
   | `live`        | `accent` (pulsing alpha)| `textPrimary`        | `EN CURSO`       |
   | `upcoming`    | `surfaceElevated`       | `textSecondary`      | `PRÓXIMO`        |
   | `unverified`  | `surfaceElevated`       | `textTertiary`       | `SIN VERIFICAR`  |

   Reuses `QuestActivePill`'s pulse animation for `live` to stay coherent with `event_detail_screen`'s in-progress banner.

2. **Tap routing** — `verified` rows push `AppRoutes.badgeDetail(badge.id)` (today's behaviour). All other rows push `AppRoutes.eventDetail(event.slug)`, which post-prior-fix correctly handles all phases (claim button when applicable, status banner when live, "Tickets" link when upcoming).

3. **Top-bar copy** — "Quest history" → "Mis quests".

4. **Empty state copy** — "Aún no marcaste intent en ningún evento — explora el feed."

### Score display

`_QuestRow`'s footer (`#serial · Score N`) still applies for `verified`. For other states, hide the serial; show the date row only. Keeps low-confidence rows from displaying meaningless `Score 0` artefacts.

---

## Migration / breaking changes

- **None for backend.** New endpoint, no schema changes, no removed fields.
- **Mobile:** `QuestHistoryScreen`'s data shape changes from `List<Badge>` to `List<MyQuestEntry>`. The route, the entry point in `profile_screen`, and the route param surface stay unchanged. `BadgesRepository.listMyBadges()` is **not** removed — `profile_screen` still uses it for the collection grid.
- **Mocks:** `MockQuestsRepository.listMyQuests()` is new. Existing mock badge fixtures stay.

---

## Testing

### Backend
- `my-quests.service.spec.ts` covers:
  - Empty intents → empty list
  - Single intent in each phase × {with/without badge} → correct status
  - Sort order (DESC by startsAt, ties by intentCreatedAt DESC)
  - User isolation (other users' intents excluded)

### Mobile
- `mock_repositories_test.dart` extends with `listMyQuests` returning fixtures for each of the 4 states. Asserts shape + sort.
- `quest_history_screen_test.dart` (new) widget test: renders 4-row fixture, asserts each pill renders the right label + asserts tap routes through the correct path (verified → badgeDetail, others → eventDetail).

### Manual smoke
1. RSVP to a past event with a badge → row shows `VERIFIED ✓`, taps to reveal
2. RSVP to a past event without a badge (force a failed verification) → row shows `SIN VERIFICAR`, taps to event_detail where the claim button decides what to do
3. RSVP to a live event → row pulses `EN CURSO`, taps to event_detail with active quest banner
4. RSVP to an upcoming event → row shows `PRÓXIMO`, taps to event_detail with intent CTA dimmed

---

## Risks + mitigations

- **Risk:** `unverified` is ambiguous — "we didn't verify you" reads as "you failed" but could also mean "the cron hasn't run yet." Mitigation: `event_detail_screen` already has the manual "Reclamar insignia" CTA; the list is a doorway, not a verdict surface.
- **Risk:** Listing 200 intents pulls 200 events + checkins + badges in three queries. Postgres handles this trivially at R0.1 scale; revisit pagination only if it becomes hot.
- **Risk:** `live` rows update only on screen open (no polling on the list itself). Acceptable for R0.1 — a user who's actually live mid-event is on `event_detail_screen`, not the history list.

---

## Out-of-scope follow-ups (for later releases)

- Filtering / search (R0.3+)
- Pull-to-refresh (R0.3+)
- "Claim now" inline action on the list itself instead of the detour through event_detail (R0.3+ if data shows users get stuck)
- Multi-user list (intents your friends have on the same event) — R1.0 social layer
