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
    const intents = await this.prisma.intent.findMany({
      where: {
        event: { endsAt: { lte: cutoff } },
        NOT: {
          user: {
            checkins: {
              some: { reconciledAt: { not: null } },
            },
          },
        },
      },
      include: { event: { select: { id: true, slug: true } } },
      take: 50,
    });
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
