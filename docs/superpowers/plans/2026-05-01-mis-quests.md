# Mis quests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `QuestHistoryScreen`'s badges-only data source with a chronological list of every event the user RSVP'd to (past, live, upcoming), each row tappable to the right destination.

**Architecture:** New `GET /me/quests` endpoint returns enriched `Intent` rows. Backend service joins Intent + Event + Checkin + Badge in three parallel queries and computes a derived `status` server-side. Mobile screen swaps its data provider, generalizes the existing row visual to four states, and routes taps to badge-detail (verified) or event-detail (everything else — claim button + status banner already live there).

**Tech Stack:** NestJS / Prisma / Postgres on backend. Flutter / Riverpod / dio / Hive on mobile. Jest for backend tests, flutter_test for mobile tests.

**Spec:** [docs/superpowers/specs/2026-05-01-mis-quests-design.md](../specs/2026-05-01-mis-quests-design.md)

---

## File Structure

**Backend:**
- Create: `apps/api/src/quests/services/my-quests.service.ts` — owns the join + status derivation
- Create: `apps/api/src/quests/services/my-quests.service.spec.ts` — unit tests with prisma mocked
- Modify: `apps/api/src/quests/quests.module.ts` — register + export `MyQuestsService`
- Modify: `apps/api/src/users/users.module.ts` — import `QuestsModule` so the controller can inject the service
- Modify: `apps/api/src/users/users.controller.ts` — add `@Get('me/quests')` handler

**Mobile:**
- Modify: `apps/mobile/lib/data/models/quest.dart` — add `MyQuestStatus`, `QuestPhase`, `QuestVerification`, `BadgeSummary`, `MyQuestEntry`
- Modify: `apps/mobile/lib/data/repositories/quests_repository.dart` — add `listMyQuests()` to the contract
- Modify: `apps/mobile/lib/data/mock/mock_quests_repository.dart` — implement with 4-state fixture
- Modify: `apps/mobile/lib/data/remote/mappers.dart` — add `myQuestEntryFromJson`
- Modify: `apps/mobile/lib/data/remote/real_quests_repository.dart` — implement HTTP path
- Modify: `apps/mobile/lib/features/profile/screens/quest_history_screen.dart` — swap provider, generalize pill, fix tap routing
- Modify: `apps/mobile/test/mock_repositories_test.dart` — add `listMyQuests` group
- Create: `apps/mobile/test/quest_history_screen_test.dart` — widget test for the four states

---

## Task 1: Backend — `MyQuestsService` skeleton + first failing test

**Files:**
- Create: `apps/api/src/quests/services/my-quests.service.ts`
- Create: `apps/api/src/quests/services/my-quests.service.spec.ts`

- [ ] **Step 1.1: Create the failing test file**

```ts
// apps/api/src/quests/services/my-quests.service.spec.ts
import { MyQuestsService } from './my-quests.service';

describe('MyQuestsService', () => {
  // Manual mock: each test wires only the prisma method shapes the
  // service uses, keeping the surface narrow and the failure modes
  // explicit. Avoids pulling in a generic mock library for one service.
  function makePrisma(overrides: {
    intents?: any[];
    checkins?: any[];
    badges?: any[];
  }) {
    return {
      intent: {
        findMany: jest.fn().mockResolvedValue(overrides.intents ?? []),
      },
      checkin: {
        findMany: jest.fn().mockResolvedValue(overrides.checkins ?? []),
      },
      badge: {
        findMany: jest.fn().mockResolvedValue(overrides.badges ?? []),
      },
    } as any;
  }

  it('returns empty list when user has no intents', async () => {
    const svc = new MyQuestsService(makePrisma({}));
    const r = await svc.listForUser('u1');
    expect(r.quests).toEqual([]);
  });
});
```

- [ ] **Step 1.2: Create the minimal service to compile**

```ts
// apps/api/src/quests/services/my-quests.service.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export type MyQuestStatus = 'upcoming' | 'live' | 'verified' | 'unverified';
export type QuestPhase = 'pre' | 'during' | 'post';

export interface MyQuestEntry {
  event: {
    id: string;
    slug: string;
    title: string;
    artistName: string | null;
    venueName: string;
    city: string;
    category: string;
    heroImageUrl: string | null;
    startsAt: Date;
    endsAt: Date;
  };
  intentCreatedAt: Date;
  phase: QuestPhase;
  checkin: {
    isVerified: boolean;
    verificationScore: number;
    reconciledAt: Date | null;
  } | null;
  badge: {
    id: string;
    serialNumber: number;
    awardedAt: Date;
  } | null;
  status: MyQuestStatus;
}

@Injectable()
export class MyQuestsService {
  constructor(private readonly prisma: PrismaService) {}

  async listForUser(userId: string): Promise<{ quests: MyQuestEntry[] }> {
    return { quests: [] };
  }
}
```

- [ ] **Step 1.3: Run the test, expect PASS**

Run: `cd apps/api && pnpm jest --testPathPatterns=my-quests`
Expected: 1 passed.

- [ ] **Step 1.4: Commit**

```bash
git add apps/api/src/quests/services/my-quests.service.ts apps/api/src/quests/services/my-quests.service.spec.ts
git commit -m "feat(api): scaffold MyQuestsService + first empty-list spec"
```

---

## Task 2: Backend — implement status derivation with full coverage

**Files:**
- Modify: `apps/api/src/quests/services/my-quests.service.spec.ts`
- Modify: `apps/api/src/quests/services/my-quests.service.ts`

- [ ] **Step 2.1: Write the four-state failing test**

Replace the body of the existing `describe` with:

```ts
describe('MyQuestsService', () => {
  function makePrisma(overrides: {
    intents?: any[];
    checkins?: any[];
    badges?: any[];
  }) {
    return {
      intent: {
        findMany: jest.fn().mockResolvedValue(overrides.intents ?? []),
      },
      checkin: {
        findMany: jest.fn().mockResolvedValue(overrides.checkins ?? []),
      },
      badge: {
        findMany: jest.fn().mockResolvedValue(overrides.badges ?? []),
      },
    } as any;
  }

  function event(id: string, fields: Partial<{
    slug: string; title: string; artistName: string | null;
    venueName: string; city: string; category: string;
    heroImageUrl: string | null; startsAt: Date; endsAt: Date;
  }> = {}) {
    return {
      id,
      slug: fields.slug ?? `event-${id}`,
      title: fields.title ?? `Event ${id}`,
      artistName: fields.artistName ?? null,
      venueName: fields.venueName ?? 'Venue',
      city: fields.city ?? 'CDMX',
      category: fields.category ?? 'music',
      heroImageUrl: fields.heroImageUrl ?? null,
      startsAt: fields.startsAt ?? new Date('2026-04-01T20:00:00Z'),
      endsAt: fields.endsAt ?? new Date('2026-04-01T23:00:00Z'),
    };
  }

  it('returns empty list when user has no intents', async () => {
    const svc = new MyQuestsService(makePrisma({}));
    const r = await svc.listForUser('u1');
    expect(r.quests).toEqual([]);
  });

  it('classifies a future-dated intent as upcoming', async () => {
    const future = new Date(Date.now() + 1000 * 60 * 60 * 24 * 7);
    const e = event('1', {
      startsAt: future,
      endsAt: new Date(future.getTime() + 3 * 60 * 60 * 1000),
    });
    const svc = new MyQuestsService(
      makePrisma({
        intents: [{ userId: 'u1', eventId: e.id, createdAt: new Date(), event: e }],
      }),
    );
    const r = await svc.listForUser('u1');
    expect(r.quests).toHaveLength(1);
    expect(r.quests[0].status).toBe('upcoming');
    expect(r.quests[0].phase).toBe('pre');
    expect(r.quests[0].badge).toBeNull();
  });

  it('classifies an in-window intent as live (within 1h grace)', async () => {
    const startsAt = new Date(Date.now() - 30 * 60 * 1000);
    const endsAt = new Date(Date.now() + 30 * 60 * 1000);
    const e = event('2', { startsAt, endsAt });
    const svc = new MyQuestsService(
      makePrisma({
        intents: [{ userId: 'u1', eventId: e.id, createdAt: new Date(), event: e }],
      }),
    );
    const r = await svc.listForUser('u1');
    expect(r.quests[0].status).toBe('live');
    expect(r.quests[0].phase).toBe('during');
  });

  it('classifies a past intent with a badge as verified', async () => {
    const startsAt = new Date(Date.now() - 1000 * 60 * 60 * 24);
    const endsAt = new Date(startsAt.getTime() + 3 * 60 * 60 * 1000);
    const e = event('3', { startsAt, endsAt });
    const svc = new MyQuestsService(
      makePrisma({
        intents: [{ userId: 'u1', eventId: e.id, createdAt: new Date(), event: e }],
        checkins: [{
          userId: 'u1', eventId: e.id, isVerified: true,
          verificationScore: 88, reconciledAt: new Date(),
        }],
        badges: [{
          id: 'b3', userId: 'u1', eventId: e.id, serialNumber: 42,
          awardedAt: new Date(),
        }],
      }),
    );
    const r = await svc.listForUser('u1');
    expect(r.quests[0].status).toBe('verified');
    expect(r.quests[0].phase).toBe('post');
    expect(r.quests[0].badge?.id).toBe('b3');
  });

  it('classifies a past intent without a badge as unverified', async () => {
    const startsAt = new Date(Date.now() - 1000 * 60 * 60 * 24);
    const endsAt = new Date(startsAt.getTime() + 3 * 60 * 60 * 1000);
    const e = event('4', { startsAt, endsAt });
    const svc = new MyQuestsService(
      makePrisma({
        intents: [{ userId: 'u1', eventId: e.id, createdAt: new Date(), event: e }],
      }),
    );
    const r = await svc.listForUser('u1');
    expect(r.quests[0].status).toBe('unverified');
    expect(r.quests[0].badge).toBeNull();
  });

  it('sorts by event.startsAt DESC, ties broken by intentCreatedAt DESC', async () => {
    const day = (n: number) =>
      new Date(Date.now() - n * 24 * 60 * 60 * 1000);
    const e1 = event('1', { startsAt: day(2), endsAt: day(2) });
    const e2 = event('2', { startsAt: day(1), endsAt: day(1) });
    const e3 = event('3', { startsAt: day(1), endsAt: day(1) });
    const svc = new MyQuestsService(
      makePrisma({
        intents: [
          { userId: 'u1', eventId: e1.id, createdAt: day(10), event: e1 },
          { userId: 'u1', eventId: e2.id, createdAt: day(5),  event: e2 },
          { userId: 'u1', eventId: e3.id, createdAt: day(3),  event: e3 },
        ],
      }),
    );
    const r = await svc.listForUser('u1');
    // e2 and e3 both startsAt=day(1); e3 has later createdAt → should come first.
    expect(r.quests.map((q) => q.event.id)).toEqual(['3', '2', '1']);
  });
});
```

- [ ] **Step 2.2: Run the tests, expect 5 of 6 to fail**

Run: `cd apps/api && pnpm jest --testPathPatterns=my-quests`
Expected: 1 passed (empty list), 5 failed (every status / sort case).

- [ ] **Step 2.3: Implement `listForUser`**

Replace the `listForUser` body in `my-quests.service.ts`:

```ts
  async listForUser(userId: string): Promise<{ quests: MyQuestEntry[] }> {
    const intents = await this.prisma.intent.findMany({
      where: { userId },
      include: { event: true },
      orderBy: [{ event: { startsAt: 'desc' } }, { createdAt: 'desc' }],
      take: 200,
    });
    if (intents.length === 0) return { quests: [] };

    const eventIds = intents.map((i) => i.eventId);
    const [checkins, badges] = await Promise.all([
      this.prisma.checkin.findMany({
        where: { userId, eventId: { in: eventIds } },
        select: {
          eventId: true,
          isVerified: true,
          verificationScore: true,
          reconciledAt: true,
        },
      }),
      this.prisma.badge.findMany({
        where: { userId, eventId: { in: eventIds } },
        select: {
          id: true,
          eventId: true,
          serialNumber: true,
          awardedAt: true,
        },
      }),
    ]);

    const checkinByEvent = new Map(checkins.map((c) => [c.eventId, c]));
    const badgeByEvent = new Map(badges.map((b) => [b.eventId, b]));

    const now = Date.now();
    const quests: MyQuestEntry[] = intents.map((i) => {
      const e = i.event;
      const startsAt = e.startsAt.getTime();
      const endsAt = e.endsAt.getTime();
      // Mirrors `QuestsService.getStatus` — keep the 1h grace consistent
      // so the list and the detail screen never disagree about phase.
      const phase: QuestPhase =
        now < startsAt
          ? 'pre'
          : now <= endsAt + 60 * 60 * 1000
            ? 'during'
            : 'post';
      const ck = checkinByEvent.get(e.id) ?? null;
      const bd = badgeByEvent.get(e.id) ?? null;
      const status: MyQuestStatus =
        phase === 'pre'
          ? 'upcoming'
          : phase === 'during'
            ? 'live'
            : bd
              ? 'verified'
              : 'unverified';
      return {
        event: {
          id: e.id,
          slug: e.slug,
          title: e.title,
          artistName: e.artistName,
          venueName: e.venueName,
          city: e.city,
          category: e.category,
          heroImageUrl: e.heroImageUrl,
          startsAt: e.startsAt,
          endsAt: e.endsAt,
        },
        intentCreatedAt: i.createdAt,
        phase,
        checkin: ck
          ? {
              isVerified: ck.isVerified,
              verificationScore: ck.verificationScore,
              reconciledAt: ck.reconciledAt,
            }
          : null,
        badge: bd
          ? { id: bd.id, serialNumber: bd.serialNumber, awardedAt: bd.awardedAt }
          : null,
        status,
      };
    });

    return { quests };
  }
```

- [ ] **Step 2.4: Run all specs, expect 6/6 pass**

Run: `cd apps/api && pnpm jest --testPathPatterns=my-quests`
Expected: 6 passed.

- [ ] **Step 2.5: Commit**

```bash
git add apps/api/src/quests/services/my-quests.service.ts apps/api/src/quests/services/my-quests.service.spec.ts
git commit -m "feat(api): MyQuestsService — phase + status derivation, sort stable"
```

---

## Task 3: Backend — wire the endpoint into `users.controller`

**Files:**
- Modify: `apps/api/src/quests/quests.module.ts`
- Modify: `apps/api/src/users/users.module.ts`
- Modify: `apps/api/src/users/users.controller.ts`

- [ ] **Step 3.1: Register + export `MyQuestsService` from `QuestsModule`**

Open `apps/api/src/quests/quests.module.ts`. Add `MyQuestsService` to the providers list AND to the exports list. The exact import path is `./services/my-quests.service`. Example diff (final state of providers/exports):

```ts
providers: [
  // ... existing entries unchanged ...
  MyQuestsService,
],
exports: [
  // ... existing exports unchanged ...
  MyQuestsService,
],
```

Add `import { MyQuestsService } from './services/my-quests.service';` near the top with the other service imports.

- [ ] **Step 3.2: Import `QuestsModule` in `UsersModule`**

Open `apps/api/src/users/users.module.ts`. Add `QuestsModule` to the `imports` array so the controller can inject `MyQuestsService`. If a circular dependency surfaces, swap to `forwardRef(() => QuestsModule)` — but try the direct import first.

```ts
import { QuestsModule } from '../quests/quests.module';

@Module({
  imports: [/* existing */, QuestsModule],
  // controllers, providers unchanged
})
export class UsersModule {}
```

- [ ] **Step 3.3: Add the route handler**

In `apps/api/src/users/users.controller.ts`, add a new method after the existing `me()` handler:

```ts
import { MyQuestsService } from '../quests/services/my-quests.service';

// inside the controller class, alongside the other @Get handlers:

  constructor(
    // existing params...
    private readonly myQuests: MyQuestsService,
  ) {}

  @Get('me/quests')
  @ApiOperation({ summary: 'Every event the current user has intent on, with derived status' })
  listMyQuests(@CurrentUser() user: User) {
    return this.myQuests.listForUser(user.id);
  }
```

If the controller already has a constructor, append the new param without removing existing ones — order matters for Nest DI but appending is safe.

- [ ] **Step 3.4: Boot-check the API**

Run: `cd apps/api && pnpm start:dev` (or whatever the boot command is — check `package.json` `scripts` if unsure).
Expected: server boots cleanly, `[Nest] ... LOG ... Mapped {GET, /me/quests}` appears in startup logs. Hit `Ctrl+C` to stop.

If circular dep error: swap to `forwardRef`.

- [ ] **Step 3.5: Run full backend test suite**

Run: `cd apps/api && pnpm jest`
Expected: all tests pass (existing 31 + 6 new = 37).

- [ ] **Step 3.6: Commit**

```bash
git add apps/api/src/quests/quests.module.ts apps/api/src/users/users.module.ts apps/api/src/users/users.controller.ts
git commit -m "feat(api): expose GET /me/quests via UsersController"
```

---

## Task 4: Mobile — domain models

**Files:**
- Modify: `apps/mobile/lib/data/models/quest.dart`

- [ ] **Step 4.1: Add the new types at the bottom of `quest.dart`**

Append after the existing `GeolocatorPing` class:

```dart
/// Status pill shown on the "Mis quests" list. Derived server-side
/// (`MyQuestsService.listForUser`) so the list and event-detail
/// screens never disagree about whether an event is live or post.
enum MyQuestStatus { upcoming, live, verified, unverified }

/// Lifecycle phase for an event from the current user's perspective.
/// Mirrors the backend enum exactly — keep these strings in sync.
enum QuestPhase { pre, during, post }

/// One entry on the "Mis quests" list — an event the user RSVP'd to,
/// joined with whatever verification + badge data already exists.
class MyQuestEntry {
  final Event event;
  final DateTime intentCreatedAt;
  final QuestPhase phase;
  final MyQuestStatus status;
  final QuestVerification? verification;
  final BadgeSummary? badge;

  const MyQuestEntry({
    required this.event,
    required this.intentCreatedAt,
    required this.phase,
    required this.status,
    this.verification,
    this.badge,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyQuestEntry && other.event.id == event.id;

  @override
  int get hashCode => event.id.hashCode;
}

/// Snapshot of the current user's `Checkin` row for an event. Null
/// until reconciliation has run — even successful runs return a row,
/// so a non-null verification with `isVerified: false` is the
/// "we tried, didn't make the threshold" signal.
class QuestVerification {
  final bool isVerified;
  final double verificationScore;
  final DateTime? reconciledAt;

  const QuestVerification({
    required this.isVerified,
    required this.verificationScore,
    this.reconciledAt,
  });
}

/// Lightweight badge reference — just enough to deep-link into the
/// reveal/badge-detail screen without requiring a full Badge fetch.
class BadgeSummary {
  final String id;
  final int serialNumber;
  final DateTime awardedAt;

  const BadgeSummary({
    required this.id,
    required this.serialNumber,
    required this.awardedAt,
  });
}
```

The `Event` import is already in this file (it's referenced by `QuestStatus`); no extra imports needed.

- [ ] **Step 4.2: Verify analyze stays clean**

Run: `cd apps/mobile && flutter analyze --no-fatal-infos lib/data/models/quest.dart`
Expected: `No issues found!`

- [ ] **Step 4.3: Commit**

```bash
git add apps/mobile/lib/data/models/quest.dart
git commit -m "feat(mobile): MyQuestEntry domain model + status/phase enums"
```

---

## Task 5: Mobile — repository contract

**Files:**
- Modify: `apps/mobile/lib/data/repositories/quests_repository.dart`

- [ ] **Step 5.1: Add the new method to the abstract**

Open `apps/mobile/lib/data/repositories/quests_repository.dart`. Add this method declaration alongside the existing ones (next to `finalizeQuest` is a logical home):

```dart
  /// Every event the current user has intent on, joined with the
  /// derived status + (when present) the verification + badge data.
  /// Backed by `GET /me/quests`. Returns the list pre-sorted by event
  /// date desc.
  Future<List<MyQuestEntry>> listMyQuests();
```

- [ ] **Step 5.2: Verify analyze fails on missing implementations**

Run: `cd apps/mobile && flutter analyze --no-fatal-infos`
Expected: errors on `MockQuestsRepository` and `RealQuestsRepository` for missing concrete implementations of `listMyQuests`. This is the failing-test equivalent — proves the contract is in force.

- [ ] **Step 5.3: Commit**

```bash
git add apps/mobile/lib/data/repositories/quests_repository.dart
git commit -m "feat(mobile): QuestsRepository.listMyQuests contract"
```

---

## Task 6: Mobile — mock implementation + tests

**Files:**
- Modify: `apps/mobile/lib/data/mock/mock_quests_repository.dart`
- Modify: `apps/mobile/test/mock_repositories_test.dart`

- [ ] **Step 6.1: Write the failing test**

Add a new `group` to `apps/mobile/test/mock_repositories_test.dart` (place after the existing `MockEventsRepository` group):

```dart
  group('MockQuestsRepository.listMyQuests', () {
    test('returns 4 entries spanning every status', () async {
      final repo = MockQuestsRepository();
      final entries = await repo.listMyQuests();
      final statuses = entries.map((e) => e.status).toSet();
      expect(statuses, containsAll([
        MyQuestStatus.verified,
        MyQuestStatus.live,
        MyQuestStatus.upcoming,
        MyQuestStatus.unverified,
      ]));
    });

    test('verified entries carry a non-null badge', () async {
      final repo = MockQuestsRepository();
      final entries = await repo.listMyQuests();
      for (final e in entries) {
        if (e.status == MyQuestStatus.verified) {
          expect(e.badge, isNotNull);
        } else {
          expect(e.badge, isNull);
        }
      }
    });

    test('sorts entries by event.startsAt desc', () async {
      final repo = MockQuestsRepository();
      final entries = await repo.listMyQuests();
      for (var i = 1; i < entries.length; i++) {
        expect(
          entries[i - 1].event.startsAt.isAfter(entries[i].event.startsAt) ||
              entries[i - 1].event.startsAt.isAtSameMomentAs(
                entries[i].event.startsAt,
              ),
          isTrue,
        );
      }
    });
  });
```

Add `import 'package:smwhr/data/mock/mock_quests_repository.dart';` and `import 'package:smwhr/data/models/quest.dart';` at the top if not already present.

- [ ] **Step 6.2: Run, expect compile failure**

Run: `cd apps/mobile && flutter test test/mock_repositories_test.dart`
Expected: compile-fail because `MockQuestsRepository.listMyQuests` doesn't exist.

- [ ] **Step 6.3: Implement the method on the mock**

Add this method to `MockQuestsRepository` in `apps/mobile/lib/data/mock/mock_quests_repository.dart` (after `finalizeQuest`). Add `import '../models/event.dart';` and `import '../models/event_category.dart';` if not present.

```dart
  @override
  Future<List<MyQuestEntry>> listMyQuests() async {
    await MockLatency.simulate();
    // Hand-built fixtures spanning every MyQuestStatus so the screen
    // can be smoke-tested in mock mode without standing up the
    // backend. Dates are anchored relative to "now" so the phase
    // computation on the server side would land on the same status
    // for the same fixture.
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 7));
    final live = now.subtract(const Duration(minutes: 30));
    final future = now.add(const Duration(days: 14));
    final older = now.subtract(const Duration(days: 30));

    Event mkEvent({
      required String id,
      required String slug,
      required String title,
      required String? artist,
      required DateTime starts,
      required DateTime ends,
    }) {
      return Event(
        id: id,
        slug: slug,
        title: title,
        artistName: artist,
        venueName: 'Estadio GNP',
        city: 'CDMX',
        category: EventCategory.music,
        heroImageUrl: null,
        startsAt: starts,
        endsAt: ends,
        intentCount: 0,
        ticketmasterUrl: null,
      );
    }

    return [
      MyQuestEntry(
        event: mkEvent(
          id: 'evt-verified',
          slug: 'evt-verified',
          title: 'BTS — World Tour',
          artist: 'BTS',
          starts: past,
          ends: past.add(const Duration(hours: 3)),
        ),
        intentCreatedAt: past.subtract(const Duration(days: 14)),
        phase: QuestPhase.post,
        status: MyQuestStatus.verified,
        verification: QuestVerification(
          isVerified: true,
          verificationScore: 88,
          reconciledAt: past.add(const Duration(hours: 4)),
        ),
        badge: BadgeSummary(
          id: 'bdg-001',
          serialNumber: 42,
          awardedAt: past.add(const Duration(hours: 4)),
        ),
      ),
      MyQuestEntry(
        event: mkEvent(
          id: 'evt-live',
          slug: 'evt-live',
          title: 'Coldplay — Music of the Spheres',
          artist: 'Coldplay',
          starts: live,
          ends: live.add(const Duration(hours: 3)),
        ),
        intentCreatedAt: live.subtract(const Duration(days: 5)),
        phase: QuestPhase.during,
        status: MyQuestStatus.live,
      ),
      MyQuestEntry(
        event: mkEvent(
          id: 'evt-upcoming',
          slug: 'evt-upcoming',
          title: 'Bad Bunny — Most Wanted Tour',
          artist: 'Bad Bunny',
          starts: future,
          ends: future.add(const Duration(hours: 3)),
        ),
        intentCreatedAt: now.subtract(const Duration(days: 1)),
        phase: QuestPhase.pre,
        status: MyQuestStatus.upcoming,
      ),
      MyQuestEntry(
        event: mkEvent(
          id: 'evt-unverified',
          slug: 'evt-unverified',
          title: 'Festival Vive Latino',
          artist: null,
          starts: older,
          ends: older.add(const Duration(hours: 8)),
        ),
        intentCreatedAt: older.subtract(const Duration(days: 30)),
        phase: QuestPhase.post,
        status: MyQuestStatus.unverified,
      ),
    ]..sort((a, b) => b.event.startsAt.compareTo(a.event.startsAt));
  }
```

If the `Event` constructor in this codebase requires fields not listed above (e.g. additional optional params with required defaults), add them with reasonable values — the test only asserts shape via `MyQuestEntry`, not `Event` internals.

- [ ] **Step 6.4: Run mock tests, expect 3 new tests to pass**

Run: `cd apps/mobile && flutter test test/mock_repositories_test.dart`
Expected: all tests pass, including 3 new `MockQuestsRepository.listMyQuests` cases.

- [ ] **Step 6.5: Commit**

```bash
git add apps/mobile/lib/data/mock/mock_quests_repository.dart apps/mobile/test/mock_repositories_test.dart
git commit -m "feat(mobile): MockQuestsRepository.listMyQuests with 4-state fixture"
```

---

## Task 7: Mobile — real repository + JSON mapper

**Files:**
- Modify: `apps/mobile/lib/data/remote/mappers.dart`
- Modify: `apps/mobile/lib/data/remote/real_quests_repository.dart`

- [ ] **Step 7.1: Add the JSON mapper**

Open `apps/mobile/lib/data/remote/mappers.dart`. At the bottom add:

```dart
MyQuestEntry myQuestEntryFromJson(Map<String, dynamic> json) {
  final eventJson = json['event'] as Map<String, dynamic>;
  // The endpoint ships only the event fields the list needs, not the
  // full Event payload — fields like geofence/dwell are absent. We
  // still want to reuse the existing Event class so the row widgets
  // and the tap → eventDetail navigation just work; missing fields
  // get safe defaults (geofence is empty, dwell is 0).
  final event = Event(
    id: eventJson['id'] as String,
    slug: eventJson['slug'] as String,
    title: eventJson['title'] as String,
    artistName: eventJson['artistName'] as String?,
    venueName: eventJson['venueName'] as String,
    city: eventJson['city'] as String,
    category: eventCategoryFromString(eventJson['category'] as String),
    heroImageUrl: eventJson['heroImageUrl'] as String?,
    startsAt: DateTime.parse(eventJson['startsAt'] as String),
    endsAt: DateTime.parse(eventJson['endsAt'] as String),
    intentCount: 0,
    ticketmasterUrl: null,
  );
  final phase = QuestPhase.values.byName(json['phase'] as String);
  final status = MyQuestStatus.values.byName(json['status'] as String);
  final ck = json['checkin'] as Map<String, dynamic>?;
  final bd = json['badge'] as Map<String, dynamic>?;
  return MyQuestEntry(
    event: event,
    intentCreatedAt: DateTime.parse(json['intentCreatedAt'] as String),
    phase: phase,
    status: status,
    verification: ck == null
        ? null
        : QuestVerification(
            isVerified: ck['isVerified'] as bool,
            verificationScore: (ck['verificationScore'] as num).toDouble(),
            reconciledAt: ck['reconciledAt'] == null
                ? null
                : DateTime.parse(ck['reconciledAt'] as String),
          ),
    badge: bd == null
        ? null
        : BadgeSummary(
            id: bd['id'] as String,
            serialNumber: bd['serialNumber'] as int,
            awardedAt: DateTime.parse(bd['awardedAt'] as String),
          ),
  );
}
```

If `eventCategoryFromString` doesn't exist in the file yet, find the closest existing helper (look at how `category` is currently mapped from JSON for the events feed) and reuse the same pattern.

- [ ] **Step 7.2: Implement on `RealQuestsRepository`**

Add to `apps/mobile/lib/data/remote/real_quests_repository.dart`, after `finalizeQuest`:

```dart
  @override
  Future<List<MyQuestEntry>> listMyQuests() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/me/quests');
    final data = res.data ?? const {};
    final list = (data['quests'] as List?) ?? const [];
    return list
        .cast<Map<String, dynamic>>()
        .map(myQuestEntryFromJson)
        .toList(growable: false);
  }
```

- [ ] **Step 7.3: Verify analyze**

Run: `cd apps/mobile && flutter analyze --no-fatal-infos`
Expected: `No issues found!`. Any error here means a model field shape diverged — fix before continuing.

- [ ] **Step 7.4: Run all flutter tests**

Run: `cd apps/mobile && flutter test`
Expected: all existing + new tests pass.

- [ ] **Step 7.5: Commit**

```bash
git add apps/mobile/lib/data/remote/mappers.dart apps/mobile/lib/data/remote/real_quests_repository.dart
git commit -m "feat(mobile): RealQuestsRepository.listMyQuests + JSON mapper"
```

---

## Task 8: Mobile — `quest_history_screen` rewire

**Files:**
- Modify: `apps/mobile/lib/features/profile/screens/quest_history_screen.dart`

- [ ] **Step 8.1: Replace the data provider**

In `apps/mobile/lib/features/profile/screens/quest_history_screen.dart`:

- Replace the `_myBadgesProvider` definition (at the bottom of the file) with:

```dart
final _myQuestsProvider = FutureProvider.autoDispose<List<MyQuestEntry>>((ref) {
  return ref.watch(questsRepositoryProvider).listMyQuests();
});
```

- Update the import block to include `import '../../../data/models/quest.dart';` and remove the `import '../../../data/models/badge.dart';` line — `Badge` is no longer referenced here. (`badge_detail` route lookup still uses an id string, not the Badge type.)

- In the `build` method, change `final badgesAsync = ref.watch(_myBadgesProvider);` to `final questsAsync = ref.watch(_myQuestsProvider);` and rename the `badgesAsync.when(...)` to `questsAsync.when(...)`.

- [ ] **Step 8.2: Update the top bar copy**

Change `'Quest history'` to `'Mis quests'` in the `_TopBar` widget.

- [ ] **Step 8.3: Update `_Empty` copy**

Change the empty-state text to:

```dart
'Aún no marcaste intent en ningún evento — explora el feed.'
```

- [ ] **Step 8.4: Generalize the row widget**

Replace `_QuestRow` with a version that takes `MyQuestEntry`. Full replacement:

```dart
class _QuestRow extends StatelessWidget {
  final MyQuestEntry entry;
  const _QuestRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final ambient = _ambient(entry.event.category);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        onTap: () {
          HapticFeedback.lightImpact();
          // Verified rows deep-link to the badge reveal; everything
          // else routes to event-detail, which already handles the
          // post-event claim button + the live status banner from
          // the prior bug-fix.
          if (entry.status == MyQuestStatus.verified &&
              entry.badge != null) {
            context.push(AppRoutes.badgeDetail(entry.badge!.id));
          } else {
            context.push(AppRoutes.eventDetail(entry.event.slug));
          }
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBlock(date: entry.event.startsAt, ambient: ambient),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CategoryDot(color: ambient),
                        const SizedBox(width: 6),
                        Text(
                          _categoryLabel(entry.event.category),
                          style: AppTypography.monoSmall.copyWith(
                            fontSize: 9,
                            letterSpacing: 1.4,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const Spacer(),
                        _StatusPill(status: entry.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.event.title,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.event.artistName != null &&
                        entry.event.artistName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.event.artistName!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${entry.event.venueName} · ${entry.event.city}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.badge != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '#${entry.badge!.serialNumber.toString().padLeft(5, '0')}',
                            style: AppTypography.monoSmall.copyWith(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (entry.verification != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Score ${entry.verification!.verificationScore.toStringAsFixed(0)}',
                              style: AppTypography.monoSmall.copyWith(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _ambient(EventCategory c) => switch (c) {
        EventCategory.music => AppColors.musicAmbient,
        EventCategory.sports => AppColors.sportsAmbient,
        EventCategory.festivals => AppColors.festivalsAmbient,
        EventCategory.outdoor => AppColors.outdoorAmbient,
        EventCategory.culture => AppColors.cultureAmbient,
      };

  static String _categoryLabel(EventCategory c) => switch (c) {
        EventCategory.music => 'LIVE MUSIC',
        EventCategory.sports => 'SPORTS',
        EventCategory.festivals => 'FESTIVAL',
        EventCategory.outdoor => 'OUTDOOR',
        EventCategory.culture => 'CULTURE',
      };
}
```

- [ ] **Step 8.5: Replace `_VerifiedPill` with `_StatusPill`**

Delete the entire `_VerifiedPill` class and add:

```dart
class _StatusPill extends StatelessWidget {
  final MyQuestStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = _configFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cfg.label,
            style: AppTypography.monoSmall.copyWith(
              fontSize: 9,
              letterSpacing: 1.2,
              color: cfg.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (cfg.icon != null) ...[
            const SizedBox(width: 2),
            Icon(cfg.icon, size: 11, color: cfg.fg),
          ],
        ],
      ),
    );
  }

  static _PillConfig _configFor(MyQuestStatus s) {
    switch (s) {
      case MyQuestStatus.verified:
        return const _PillConfig(
          label: 'VERIFIED',
          bg: AppColors.accentGlow,
          fg: AppColors.accent,
          icon: Icons.check_rounded,
        );
      case MyQuestStatus.live:
        return const _PillConfig(
          label: 'EN CURSO',
          bg: AppColors.accent,
          fg: AppColors.textPrimary,
          icon: null,
        );
      case MyQuestStatus.upcoming:
        return const _PillConfig(
          label: 'PRÓXIMO',
          bg: AppColors.surfaceElevated,
          fg: AppColors.textSecondary,
          icon: null,
        );
      case MyQuestStatus.unverified:
        return const _PillConfig(
          label: 'SIN VERIFICAR',
          bg: AppColors.surfaceElevated,
          fg: AppColors.textTertiary,
          icon: null,
        );
    }
  }
}

class _PillConfig {
  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  const _PillConfig({
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
  });
}
```

- [ ] **Step 8.6: Update `itemBuilder` to pass entries**

In the `ListView.separated` block, change:

```dart
itemBuilder: (context, i) => _QuestRow(badge: sorted[i]),
```

to (and remove the now-unused `..sort` line since the backend pre-sorts):

```dart
itemBuilder: (context, i) => _QuestRow(entry: questsAsync.requireValue[i]),
```

Also update `final sorted = [...badges]..sort(...);` → just use `entries` directly. Final shape of the data branch:

```dart
data: (entries) {
  if (entries.isEmpty) {
    return const _Empty();
  }
  return ListView.separated(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xxl,
    ),
    itemCount: entries.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
    itemBuilder: (context, i) => _QuestRow(entry: entries[i]),
  );
},
```

- [ ] **Step 8.7: Verify analyze**

Run: `cd apps/mobile && flutter analyze --no-fatal-infos lib/features/profile/screens/quest_history_screen.dart`
Expected: `No issues found!`

- [ ] **Step 8.8: Smoke-test in mock mode**

Run: `cd apps/mobile && flutter run --dart-define=USE_MOCKS=true`
- Sign in (mock auth)
- Profile → tap "Quest history" entry point
- Expected: see four rows, one per status. Tap a verified row → reveal screen. Tap an upcoming row → event detail.

- [ ] **Step 8.9: Commit**

```bash
git add apps/mobile/lib/features/profile/screens/quest_history_screen.dart
git commit -m "feat(mobile): Mis quests — list every intent, status pill, smart tap routing"
```

---

## Task 9: Mobile — widget test for the four states

**Files:**
- Create: `apps/mobile/test/quest_history_screen_test.dart`

- [ ] **Step 9.1: Write the widget test**

```dart
// apps/mobile/test/quest_history_screen_test.dart
//
// Renders QuestHistoryScreen with a stubbed repo emitting one entry
// per MyQuestStatus and asserts each pill label appears. Doesn't
// exercise navigation — the tap → route mapping is covered by inline
// inspection of the row's onTap closure.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:smwhr/data/models/event.dart';
import 'package:smwhr/data/models/event_category.dart';
import 'package:smwhr/data/models/quest.dart';
import 'package:smwhr/data/providers.dart';
import 'package:smwhr/data/repositories/quests_repository.dart';
import 'package:smwhr/features/profile/screens/quest_history_screen.dart';

class _StubRepo implements QuestsRepository {
  final List<MyQuestEntry> entries;
  _StubRepo(this.entries);

  @override
  Future<List<MyQuestEntry>> listMyQuests() async => entries;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Event _event(String slug, DateTime starts) => Event(
      id: slug,
      slug: slug,
      title: 'Title $slug',
      artistName: null,
      venueName: 'Venue',
      city: 'CDMX',
      category: EventCategory.music,
      heroImageUrl: null,
      startsAt: starts,
      endsAt: starts.add(const Duration(hours: 3)),
      intentCount: 0,
      ticketmasterUrl: null,
    );

void main() {
  testWidgets('renders one row per status with the right pill', (tester) async {
    final now = DateTime.now();
    final entries = [
      MyQuestEntry(
        event: _event('verified', now.subtract(const Duration(days: 1))),
        intentCreatedAt: now,
        phase: QuestPhase.post,
        status: MyQuestStatus.verified,
        badge: BadgeSummary(
          id: 'b1', serialNumber: 1, awardedAt: now,
        ),
        verification: const QuestVerification(
          isVerified: true, verificationScore: 90,
        ),
      ),
      MyQuestEntry(
        event: _event('live', now),
        intentCreatedAt: now,
        phase: QuestPhase.during,
        status: MyQuestStatus.live,
      ),
      MyQuestEntry(
        event: _event('upcoming', now.add(const Duration(days: 7))),
        intentCreatedAt: now,
        phase: QuestPhase.pre,
        status: MyQuestStatus.upcoming,
      ),
      MyQuestEntry(
        event: _event('unverified', now.subtract(const Duration(days: 30))),
        intentCreatedAt: now.subtract(const Duration(days: 31)),
        phase: QuestPhase.post,
        status: MyQuestStatus.unverified,
      ),
    ];

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const QuestHistoryScreen()),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questsRepositoryProvider.overrideWithValue(_StubRepo(entries)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    // Pump twice: first frame shows the loading spinner, second frame
    // surfaces the resolved data after the FutureProvider settles.
    await tester.pump();
    await tester.pump();

    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('EN CURSO'), findsOneWidget);
    expect(find.text('PRÓXIMO'), findsOneWidget);
    expect(find.text('SIN VERIFICAR'), findsOneWidget);
  });
}
```

- [ ] **Step 9.2: Run, expect PASS**

Run: `cd apps/mobile && flutter test test/quest_history_screen_test.dart`
Expected: 1 passed.

- [ ] **Step 9.3: Run full mobile suite**

Run: `cd apps/mobile && flutter test`
Expected: all tests pass.

- [ ] **Step 9.4: Commit**

```bash
git add apps/mobile/test/quest_history_screen_test.dart
git commit -m "test(mobile): widget test for QuestHistoryScreen status pills"
```

---

## Task 10: Final integration smoke + cleanup

- [ ] **Step 10.1: Backend full suite**

Run: `cd apps/api && pnpm jest`
Expected: 37 passed (31 existing + 6 new).

- [ ] **Step 10.2: Mobile full analyze + suite**

Run: `cd apps/mobile && flutter analyze --no-fatal-infos && flutter test`
Expected: `No issues found!` and all tests pass (60 prior + 3 mock + 1 widget = 64).

- [ ] **Step 10.3: End-to-end smoke against real backend**

Boot the API locally (or against your ngrok tunnel), seed at least three intents per status, then:

```sh
cd apps/mobile
flutter run --dart-define=USE_MOCKS=false \
  --dart-define=API_BASE_URL=https://crappie-patient-boxer.ngrok-free.app
```

- Tap profile → "Mis quests"
- Verify all four states appear and route correctly:
  - Verified → reveal screen with the right serial
  - Live → event detail with active-quest banner
  - Upcoming → event detail with intent toggle
  - Unverified → event detail with claim button (or "I'll be there" if intent was removed)

- [ ] **Step 10.4: No-op if nothing else to clean up**

If steps 10.1-10.3 surface no issues, this task is done. Do NOT add unrelated cleanup or refactors.

---

## Self-Review Notes

**Spec coverage:**
- ✅ Endpoint shape — Task 1, 2 (status derivation per spec table)
- ✅ Endpoint mounting — Task 3
- ✅ Mobile model — Task 4
- ✅ Repository contract — Task 5, 6, 7
- ✅ Screen rewrite — Task 8 (provider, top bar, empty state, row, pill, routing)
- ✅ Tests — Tasks 2, 6, 9
- ✅ No breaking changes to `BadgesRepository.listMyBadges()` — Task 8 only removes the import in this one screen

**Placeholder scan:** none — every step ships executable code or an exact command.

**Type consistency:** `MyQuestEntry`, `MyQuestStatus`, `QuestPhase`, `QuestVerification`, `BadgeSummary` are defined once in Task 4 and consumed unchanged in 5/6/7/8/9.

**Status table consistency:** spec's pill table (verified/live/upcoming/unverified) matches Task 8's `_StatusPill._configFor` switch arm-for-arm.
