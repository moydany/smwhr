import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export type AuditEventType =
  | 'USER_AUTO_CREATED'
  | 'ONBOARDING_COMPLETED'
  | 'INTENT_SET'
  | 'INTENT_CLEARED'
  | 'QUEST_SYNC'
  | 'INTEGRITY_ATTESTED'
  | 'PHOTO_UPLOADED'
  | 'CHECKIN_FINALIZED'
  | 'BADGE_ISSUED'
  | 'WAITLIST_SIGNUP'
  | 'AUTH_OTP_REQUESTED'
  | 'AUTH_OTP_VERIFIED';

interface RecordInput {
  type: AuditEventType;
  userId?: string | null;
  eventId?: string | null;
  metadata?: Record<string, unknown>;
}

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Append a row to system_events. Never throws — audit must not break
   * the request that emitted it.
   */
  async record(input: RecordInput): Promise<void> {
    try {
      await this.prisma.systemEvent.create({
        data: {
          type: input.type,
          userId: input.userId ?? null,
          eventId: input.eventId ?? null,
          metadata: (input.metadata ?? Prisma.JsonNull) as Prisma.InputJsonValue,
        },
      });
    } catch (err) {
      this.logger.warn(`audit record failed (type=${input.type}): ${(err as Error).message}`);
    }
  }
}
