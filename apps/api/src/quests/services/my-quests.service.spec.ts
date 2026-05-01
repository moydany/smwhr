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
