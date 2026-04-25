import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

interface PushTarget {
  userId: string;
  pushToken: string;
  platform: string;
  displayName: string;
}

/**
 * R0.1 stub: looks up the recipient's push token + logs the intended
 * payload. Real FCM/APNs wiring lands when the mobile app's push
 * permission flow is verified end-to-end (post-soft-launch).
 *
 * The method signatures are stable — switching to a real provider only
 * touches the body of `dispatch()`.
 */
@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);

  constructor(private readonly prisma: PrismaService) {}

  async notifyBadgeIssued(userId: string, badgeId: string): Promise<void> {
    const target = await this.findTarget(userId);
    if (!target) return;

    const badge = await this.prisma.badge.findUnique({
      where: { id: badgeId },
      include: { event: { select: { title: true, venueName: true } } },
    });
    if (!badge) return;

    await this.dispatch(target, {
      title: 'Your badge is ready',
      body: `${badge.event.title} — #${badge.serialNumber}/${badge.totalForEvent}`,
      data: { badgeId, eventTitle: badge.event.title, deeplink: `smwhr://badge/${badgeId}` },
    });
  }

  async notifyEventStartingSoon(userId: string, eventId: string): Promise<void> {
    const target = await this.findTarget(userId);
    if (!target) return;
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      select: { title: true, venueName: true, city: true, startsAt: true },
    });
    if (!event) return;
    await this.dispatch(target, {
      title: 'Quest is live',
      body: `${event.title} starts at ${event.venueName}, ${event.city}.`,
      data: { eventId, deeplink: `smwhr://quest/${eventId}` },
    });
  }

  private async findTarget(userId: string): Promise<PushTarget | null> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, pushToken: true, pushPlatform: true, displayName: true },
    });
    if (!user?.pushToken || !user.pushPlatform) {
      this.logger.debug(`no push token for user=${userId}, skipping`);
      return null;
    }
    return {
      userId: user.id,
      pushToken: user.pushToken,
      platform: user.pushPlatform,
      displayName: user.displayName || user.id,
    };
  }

  private async dispatch(
    target: PushTarget,
    payload: { title: string; body: string; data: Record<string, string> },
  ): Promise<void> {
    // TODO(release): wire FCM (Android) + APNs (iOS) via firebase-admin
    // or a transactional push provider. Current behaviour is log-only.
    this.logger.log(
      `[push:${target.platform}] → user=${target.userId} (${target.displayName}): "${payload.title}" — ${payload.body}`,
    );
  }
}
