import { HttpStatus, Injectable } from '@nestjs/common';
import type { User } from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { ApiException } from '../common/exceptions/api.exception';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../quests/storage.service';
import { OnboardingDto } from './dto/onboarding.dto';
import { UpdateMeDto } from './dto/update-me.dto';
import { normalizeHandle, validateHandle } from './utils/handle.validator';

const VALID_AVATAR_MIMETYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/heic',
  'image/heif',
  'image/webp',
]);

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly storage: StorageService,
  ) {}

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

    const updated = await this.prisma.user.update({
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
    await this.audit.record({
      type: 'ONBOARDING_COMPLETED',
      userId: updated.id,
      metadata: { handle: updated.handle, interestsCount: updated.interests.length },
    });
    return updated;
  }

  async updateMe(user: User, dto: UpdateMeDto): Promise<User> {
    let nextHandle: string | undefined;
    if (dto.handle != null) {
      const v = validateHandle(dto.handle);
      if (!v.ok) {
        throw new ApiException(HttpStatus.BAD_REQUEST, 'INVALID_HANDLE', v.reason);
      }
      const candidate = normalizeHandle(dto.handle);
      // Skip the uniqueness round-trip when the user submitted their
      // current handle untouched (common case from the edit form).
      if (candidate !== user.handle) {
        const existing = await this.prisma.user.findUnique({ where: { handle: candidate } });
        if (existing && existing.id !== user.id) {
          throw new ApiException(HttpStatus.CONFLICT, 'HANDLE_TAKEN', 'Handle already taken');
        }
        nextHandle = candidate;
      }
    }

    const updated = await this.prisma.user.update({
      where: { id: user.id },
      data: {
        handle: nextHandle ?? undefined,
        displayName: dto.displayName ?? undefined,
        bio: dto.bio ?? undefined,
        city: dto.city ?? undefined,
        interests: dto.interests ?? undefined,
        language: dto.language ?? undefined,
        pushToken: dto.pushToken ?? undefined,
        pushPlatform: dto.pushPlatform ?? undefined,
      },
    });

    if (nextHandle != null) {
      await this.audit.record({
        type: 'HANDLE_CHANGED',
        userId: updated.id,
        metadata: { from: user.handle, to: nextHandle },
      });
    }
    return updated;
  }

  async uploadAvatar(user: User, file: Express.Multer.File): Promise<User> {
    if (!file || !file.buffer) {
      throw new ApiException(HttpStatus.BAD_REQUEST, 'AVATAR_FILE_REQUIRED', 'Avatar file is required');
    }
    if (!VALID_AVATAR_MIMETYPES.has(file.mimetype)) {
      throw new ApiException(
        HttpStatus.BAD_REQUEST,
        'AVATAR_MIMETYPE_UNSUPPORTED',
        `Unsupported mimetype ${file.mimetype}`,
      );
    }
    const upload = await this.storage.uploadAvatar(user.id, {
      buffer: file.buffer,
      mimetype: file.mimetype,
      originalname: file.originalname,
    });
    if (!upload.publicUrl) {
      throw new ApiException(HttpStatus.BAD_GATEWAY, 'STORAGE_SIGN_FAILED', 'Could not sign avatar URL');
    }
    return this.prisma.user.update({
      where: { id: user.id },
      data: { avatarUrl: upload.publicUrl },
    });
  }

  async removeAvatar(user: User): Promise<User> {
    return this.prisma.user.update({
      where: { id: user.id },
      data: { avatarUrl: null },
    });
  }
}
