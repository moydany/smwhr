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
