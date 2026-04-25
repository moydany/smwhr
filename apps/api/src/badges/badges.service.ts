import { HttpStatus, Injectable } from '@nestjs/common';
import type { User } from '@prisma/client';
import { ApiException } from '../common/exceptions/api.exception';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class BadgesService {
  constructor(private readonly prisma: PrismaService) {}

  async listMine(user: User) {
    return this.prisma.badge.findMany({
      where: { userId: user.id },
      include: { event: true, template: true },
      orderBy: { awardedAt: 'desc' },
    });
  }

  async byId(id: string) {
    const badge = await this.prisma.badge.findUnique({
      where: { id },
      include: { event: true, template: true, user: { select: { id: true, handle: true, displayName: true, avatarUrl: true } } },
    });
    if (!badge) {
      throw new ApiException(HttpStatus.NOT_FOUND, 'BADGE_NOT_FOUND', 'Badge not found');
    }
    return badge;
  }

  async share(id: string) {
    const badge = await this.byId(id);
    return {
      shareImageUrl: badge.shareImageUrl ?? badge.composedImageUrl,
      shareText: this.shareText(badge),
      deepLink: `https://smwhr.dev/b/${badge.id}`,
    };
  }

  private shareText(badge: { event: { title: string; venueName: string; city: string }; serialNumber: number; totalForEvent: number }): string {
    return `I was at ${badge.event.title} — ${badge.event.venueName}, ${badge.event.city}. #${badge.serialNumber}/${badge.totalForEvent} on smwhr.`;
  }
}
