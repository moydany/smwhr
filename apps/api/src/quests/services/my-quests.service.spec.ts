import { MyQuestsService } from './my-quests.service';

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

  // Mirrors the real Prisma `Event` row shape — `artist` (not
  // `artistName`) matches the column name in `schema.prisma`. Service
  // maps `e.artist` → response `artistName`. Keeping the fixture
  // realistic catches mapping drift before it hits prod.
  function event(id: string, fields: Partial<{
    slug: string; title: string; artist: string | null;
    venueName: string; city: string; category: string;
    heroImageUrl: string | null; startsAt: Date; endsAt: Date;
  }> = {}) {
    return {
      id,
      slug: fields.slug ?? `event-${id}`,
      title: fields.title ?? `Event ${id}`,
      artist: fields.artist ?? null,
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
    // Lock the `artist` (Prisma column) → `artistName` (response
    // field) mapping. If the service ever stops projecting this, the
    // assertion below catches it.
    const e = event('3', { startsAt, endsAt, artist: 'Coldplay' });
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
    expect(r.quests[0].event.artistName).toBe('Coldplay');
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
