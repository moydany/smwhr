import { HttpStatus, Injectable } from '@nestjs/common';
import type { User } from '@prisma/client';
import { ApiException } from '../common/exceptions/api.exception';
import { PrismaService } from '../prisma/prisma.service';
import { OnboardingDto } from './dto/onboarding.dto';
import { UpdateMeDto } from './dto/update-me.dto';
import { normalizeHandle, validateHandle } from './utils/handle.validator';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(user: User): Promise<User> {
    return user;
  }

  async getByHandle(rawHandle: string): Promise<User> {
    const handle = normalizeHandle(rawHandle);
    const user = await this.prisma.user.findUnique({ where: { handle } });
    if (!user) {
      throw new ApiException(HttpStatus.NOT_FOUND, 'USER_NOT_FOUND', `User @${handle} not found`);
    }
    return user;
  }

  async getBadgesByHandle(rawHandle: string) {
    const user = await this.getByHandle(rawHandle);
    return this.prisma.badge.findMany({
      where: { userId: user.id },
      include: { event: true, template: true },
      orderBy: { awardedAt: 'desc' },
    });
  }

  async checkHandleAvailable(rawHandle: string): Promise<{ available: boolean; reason?: string }> {
    const v = validateHandle(rawHandle);
    if (!v.ok) return { available: false, reason: v.reason };
    const handle = normalizeHandle(rawHandle);
    const existing = await this.prisma.user.findUnique({ where: { handle } });
    return existing ? { available: false, reason: 'Handle already taken' } : { available: true };
  }

  async completeOnboarding(user: User, dto: OnboardingDto): Promise<User> {
    const v = validateHandle(dto.handle);
    if (!v.ok) {
      throw new ApiException(HttpStatus.BAD_REQUEST, 'INVALID_HANDLE', v.reason);
    }
    const handle = normalizeHandle(dto.handle);

    const existing = await this.prisma.user.findUnique({ where: { handle } });
    if (existing && existing.id !== user.id) {
      throw new ApiException(HttpStatus.CONFLICT, 'HANDLE_TAKEN', 'Handle already taken');
    }

    return this.prisma.user.update({
      where: { id: user.id },
      data: {
        handle,
        displayName: dto.displayName,
        city: dto.city ?? null,
        countryCode: dto.countryCode ?? 'MX',
        interests: dto.interests ?? [],
        pushToken: dto.notificationsEnabled === false ? null : dto.pushToken ?? null,
        pushPlatform: dto.notificationsEnabled === false ? null : dto.pushPlatform ?? null,
        notificationPromptShownAt: new Date(),
        onboardingCompletedAt: new Date(),
      },
    });
  }

  async updateMe(user: User, dto: UpdateMeDto): Promise<User> {
    return this.prisma.user.update({
      where: { id: user.id },
      data: {
        displayName: dto.displayName ?? undefined,
        bio: dto.bio ?? undefined,
        city: dto.city ?? undefined,
        interests: dto.interests ?? undefined,
        pushToken: dto.pushToken ?? undefined,
        pushPlatform: dto.pushPlatform ?? undefined,
      },
    });
  }
}
