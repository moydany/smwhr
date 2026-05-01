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
        status,
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
      };
    });

    // Sort in JS as well — protects against mock not honouring orderBy
    // and makes the contract robust against future repo changes.
    quests.sort((a, b) => {
      const dateDiff = b.event.startsAt.getTime() - a.event.startsAt.getTime();
      if (dateDiff !== 0) return dateDiff;
      return b.intentCreatedAt.getTime() - a.intentCreatedAt.getTime();
    });

    return { quests };
  }
}
