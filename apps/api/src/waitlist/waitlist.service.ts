import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';
import { WaitlistSignupDto } from './dto/waitlist-signup.dto';

@Injectable()
export class WaitlistService {
  private readonly logger = new Logger(WaitlistService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async signup(dto: WaitlistSignupDto) {
    try {
      await this.prisma.waitlistSignup.create({
        data: {
          email: dto.email.toLowerCase().trim(),
          source: dto.source ?? 'landing',
          referrer: dto.referrer ?? null,
          interests: dto.interests ?? [],
        },
      });
      await this.audit.record({
        type: 'WAITLIST_SIGNUP',
        metadata: { source: dto.source ?? 'landing', interestsCount: (dto.interests ?? []).length },
      });
      return { success: true, message: "You're on the list — we'll be in touch." };
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        return { success: true, message: "You're already on the list." };
      }
      this.logger.error(`waitlist signup failed: ${(err as Error).message}`);
      throw err;
    }
  }
}
