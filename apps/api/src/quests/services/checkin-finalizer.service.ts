import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuditService } from '../../audit/audit.service';
import { NotificationService } from '../../notifications/notification.service';
import { PrismaService } from '../../prisma/prisma.service';
import { ReconciliationService } from './reconciliation.service';
import { VerificationService } from './verification.service';
import { targetSpotCheckCount } from '../verification-tasks.constants';

@Injectable()
export class CheckinFinalizerService {
  private readonly logger = new Logger(CheckinFinalizerService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly reconciler: ReconciliationService,
    private readonly verifier: VerificationService,
    private readonly audit: AuditService,
    private readonly notify: NotificationService,
  ) {}

  /**
   * Reconcile + score for a single (user, event) pair, write/update the
   * Checkin row, and issue a Badge if verified. Idempotent.
   */
  async finalize(userId: string, eventId: string) {
    const event = await this.prisma.event.findUnique({ where: { id: eventId } });
    if (!event) throw new Error(`event ${eventId} not found`);

    const [locusEvents, geolocatorPings, existingCheckin, photo] = await Promise.all([
      this.prisma.locusEvent.findMany({ where: { userId, eventId } }),
      this.prisma.geolocatorPing.findMany({ where: { userId, eventId } }),
      this.prisma.checkin.findUnique({ where: { userId_eventId: { userId, eventId } } }),
      this.prisma.photo.findFirst({
        where: { userId, checkin: { userId, eventId } },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    const r = this.reconciler.reconcile({ locusEvents, geolocatorPings });

    // Presence inputs — the new verification gate. Spot-check ratio
    // is what decides "did the user actually attend?" instead of the
    // old continuous-dwell test. dwellMinutes is still computed by
    // the reconciler and stored on the Checkin row for audit, but no
    // longer drives issuance.
    const inPolygonGeolocatorCount = geolocatorPings.filter((p) => p.isInsidePolygon).length;
    const inPolygonLocusCount = locusEvents.filter((e) => e.isInsidePolygon).length;
    const target = targetSpotCheckCount(event.startsAt, event.endsAt);
    const hasArrived = inPolygonGeolocatorCount > 0 || inPolygonLocusCount > 0;

    const score = this.verifier.score({
      inPolygonGeolocatorCount,
      targetSpotCheckCount: target,
      hasArrived,
      totalPointsCollected: r.totalPoints,
      agreementScore: r.agreementScore,
      integrityVerdict: existingCheckin?.integrityVerdict ?? null,
      primarySource: r.primarySource,
      photo: photo
        ? {
            isExifValid: photo.isExifValid,
            isWithinTimeWindow: photo.isWithinTimeWindow,
            isInsideGeofence: photo.isInsideGeofence,
          }
        : null,
    });

    const checkin = await this.prisma.checkin.upsert({
      where: { userId_eventId: { userId, eventId } },
      create: {
        userId,
        eventId,
        primarySource: r.primarySource,
        reconciliationReason: r.reason,
        agreementScore: r.agreementScore,
        reconciledAt: new Date(),
        dwellMinutes: r.dwellMinutes,
        firstPointAt: r.firstPointAt,
        lastPointAt: r.lastPointAt,
        totalPointsCollected: r.totalPoints,
        locusEventsCount: locusEvents.length,
        geolocatorPingsCount: geolocatorPings.length,
        verificationScore: score.total,
        isVerified: score.isVerified,
        verificationReason: this.scoreReason(score, r),
        photoId: photo?.id ?? existingCheckin?.photoId ?? null,
      },
      update: {
        primarySource: r.primarySource,
        reconciliationReason: r.reason,
        agreementScore: r.agreementScore,
        reconciledAt: new Date(),
        dwellMinutes: r.dwellMinutes,
        firstPointAt: r.firstPointAt,
        lastPointAt: r.lastPointAt,
        totalPointsCollected: r.totalPoints,
        locusEventsCount: locusEvents.length,
        geolocatorPingsCount: geolocatorPings.length,
        verificationScore: score.total,
        isVerified: score.isVerified,
        verificationReason: this.scoreReason(score, r),
        photoId: photo?.id ?? existingCheckin?.photoId ?? null,
      },
    });

    await this.audit.record({
      type: 'CHECKIN_FINALIZED',
      userId,
      eventId,
      metadata: {
        primarySource: r.primarySource,
        dwellMinutes: r.dwellMinutes,
        verificationScore: score.total,
        isVerified: score.isVerified,
      },
    });

    let badgeId: string | null = null;
    if (score.isVerified) {
      badgeId = await this.issueBadge(userId, event.id, event.badgeTemplateId, score.total, photo?.id ?? null);
      await this.notify.notifyBadgeIssued(userId, badgeId);
    }

    return { checkin, scoreBreakdown: score, badgeId };
  }

  private scoreReason(
    s: { parts: { presence: number; presenceRatio: number; tracking: number; crossValidation: number; integrity: number; photo: number; penaltyMultiplier: number } },
    r: { primarySource: string },
  ): string {
    const p = s.parts;
    const ratio = p.presenceRatio.toFixed(2);
    return `presence=${p.presence}(${ratio}) tracking=${p.tracking} cross=${p.crossValidation} integrity=${p.integrity} photo=${p.photo} penalty=${p.penaltyMultiplier} (source=${r.primarySource})`;
  }

  private async issueBadge(
    userId: string,
    eventId: string,
    templateId: string | null,
    verificationScore: number,
    photoId: string | null,
  ): Promise<string> {
    const existing = await this.prisma.badge.findUnique({
      where: { userId_eventId: { userId, eventId } },
    });
    if (existing) {
      if (!existing.composedImageUrl && photoId) {
        const photo = await this.prisma.photo.findUnique({ where: { id: photoId } });
        if (photo?.publicUrl) {
          await this.prisma.badge.update({
            where: { id: existing.id },
            data: { composedImageUrl: photo.publicUrl },
          });
        }
      }
      return existing.id;
    }

    const tplId = templateId ?? (await this.fallbackTemplateId(eventId));

    const badge = await this.prisma.$transaction(async (tx) => {
      const max = await tx.badge.aggregate({
        where: { eventId },
        _max: { serialNumber: true },
      });
      const serial = (max._max.serialNumber ?? 0) + 1;
      const photoUrl = photoId
        ? await tx.photo.findUnique({ where: { id: photoId } }).then((p) => p?.publicUrl ?? null)
        : null;
      const created = await tx.badge.create({
        data: {
          userId,
          eventId,
          templateId: tplId,
          serialNumber: serial,
          totalForEvent: serial,
          verificationScore,
          isVerified: true,
          composedImageUrl: photoUrl,
          awardedAt: new Date(),
        },
      });
      await tx.event.update({
        where: { id: eventId },
        data: { badgeCount: { increment: 1 } },
      });
      await tx.badge.updateMany({
        where: { eventId },
        data: { totalForEvent: serial },
      });
      return created;
    });

    this.logger.log(`badge issued: user=${userId} event=${eventId} serial=${badge.serialNumber}`);
    await this.audit.record({
      type: 'BADGE_ISSUED',
      userId,
      eventId,
      metadata: { badgeId: badge.id, serialNumber: badge.serialNumber, score: verificationScore },
    });
    return badge.id;
  }

  private async fallbackTemplateId(eventId: string): Promise<string> {
    const event = await this.prisma.event.findUnique({ where: { id: eventId } });
    const tpl = await this.prisma.badgeTemplate.findFirst({
      where: { category: event?.category ?? 'music', variant: 'default' },
    });
    if (!tpl) {
      throw new Error(`no badge template for category ${event?.category}`);
    }
    return tpl.id;
  }
}
