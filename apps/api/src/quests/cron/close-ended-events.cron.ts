import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../prisma/prisma.service';
import { CheckinFinalizerService } from '../services/checkin-finalizer.service';

@Injectable()
export class CloseEndedEventsCron {
  private readonly logger = new Logger(CloseEndedEventsCron.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly finalizer: CheckinFinalizerService,
  ) {}

  /**
   * Every 5 min: find intents on events that ended ≥1h ago and don't yet
   * have a reconciled Checkin. Run finalize on each.
   */
  @Cron(CronExpression.EVERY_5_MINUTES)
  async run() {
    const cutoff = new Date(Date.now() - 60 * 60 * 1000);
    // Pull every intent for events that ended ≥1h ago. The
    // already-reconciled filter happens in a second pass below — doing
    // it inline as `NOT user.checkins.some.reconciledAt` (the previous
    // query) excluded any user with ANY past reconciled checkin from
    // ALL of their pending intents, so a user who'd ever earned a
    // badge stopped being picked up by this cron entirely. Prisma
    // can't correlate `intent.eventId === checkin.eventId` on the same
    // row inside a relation filter, hence the two-step approach.
    const candidates = await this.prisma.intent.findMany({
      where: { event: { endsAt: { lte: cutoff } } },
      include: { event: { select: { id: true, slug: true } } },
      take: 200,
    });
    if (candidates.length === 0) return;

    const reconciled = await this.prisma.checkin.findMany({
      where: {
        OR: candidates.map((i) => ({
          userId: i.userId,
          eventId: i.eventId,
        })),
        reconciledAt: { not: null },
      },
      select: { userId: true, eventId: true },
    });
    const reconciledKeys = new Set(
      reconciled.map((c) => `${c.userId}:${c.eventId}`),
    );

    const intents = candidates
      .filter((i) => !reconciledKeys.has(`${i.userId}:${i.eventId}`))
      .slice(0, 50);
    if (intents.length === 0) return;

    this.logger.log(`finalizing ${intents.length} pending checkin(s)`);
    for (const i of intents) {
      try {
        await this.finalizer.finalize(i.userId, i.eventId);
      } catch (err) {
        this.logger.error(
          `finalize failed for user=${i.userId} event=${i.event.slug}: ${(err as Error).message}`,
        );
      }
    }
  }
}
