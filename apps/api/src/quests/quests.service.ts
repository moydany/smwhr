import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { User } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { AuditService } from '../audit/audit.service';
import { ApiException } from '../common/exceptions/api.exception';
import { EventsService } from '../events/events.service';
import { PrismaService } from '../prisma/prisma.service';
import { IntegrityDto } from './dto/integrity.dto';
import { SyncTrackingDto } from './dto/sync-tracking.dto';
import { UploadPhotoMetadataDto } from './dto/upload-photo.dto';
import { GeoService } from './services/geo.service';
import { VerificationTasksService } from './services/verification-tasks.service';
import { targetSpotCheckCount } from './verification-tasks.constants';
import { StorageService } from './storage.service';

@Injectable()
export class QuestsService {
  private readonly logger = new Logger(QuestsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventsService,
    private readonly storage: StorageService,
    private readonly geo: GeoService,
    private readonly audit: AuditService,
    private readonly tasks: VerificationTasksService,
  ) {}

  async getStatus(user: User, eventId: string) {
    const event = await this.events.byId(eventId);
    const intent = await this.prisma.intent.findUnique({
      where: { userId_eventId: { userId: user.id, eventId: event.id } },
    });
    const checkin = await this.prisma.checkin.findUnique({
      where: { userId_eventId: { userId: user.id, eventId: event.id } },
    });

    // Aggregates the active-quest UI needs to render the task checklist:
    //   - total counts (legacy, kept for the activity meter widgets)
    //   - in-polygon counts → mirror what the persisted task ledger
    //     stores in `progressN` for the spot-check task; surfaced here
    //     too so older mobile builds without ledger awareness still get
    //     the N/M visual.
    const [locusCount, geolocatorCount, locusInside, geolocatorInside, earliestInside, tasks, photos, badge] =
      await Promise.all([
        this.prisma.locusEvent.count({ where: { userId: user.id, eventId: event.id } }),
        this.prisma.geolocatorPing.count({ where: { userId: user.id, eventId: event.id } }),
        this.prisma.locusEvent.count({
          where: { userId: user.id, eventId: event.id, isInsidePolygon: true },
        }),
        this.prisma.geolocatorPing.count({
          where: { userId: user.id, eventId: event.id, isInsidePolygon: true },
        }),
        this.firstInPolygonAt(user.id, event.id),
        this.tasks.listForUser(user.id, event.id),
        this.prisma.photo.findMany({
          where: { userId: user.id, eventId: event.id },
          orderBy: { createdAt: 'asc' },
          select: {
            id: true,
            publicUrl: true,
            createdAt: true,
            isInsideGeofence: true,
            isWithinTimeWindow: true,
            isExifValid: true,
          },
        }),
        // Surfaced so the mobile can swap "QUEST ACTIVE" for a "Ver
        // tu insignia →" CTA the moment the badge is issued. Null
        // until reconciliation passes the gates.
        this.prisma.badge.findUnique({
          where: { userId_eventId: { userId: user.id, eventId: event.id } },
          select: { id: true, awardedAt: true, serialNumber: true },
        }),
      ]);

    const now = Date.now();
    const startsAt = event.startsAt.getTime();
    const endsAt = event.endsAt.getTime();
    const phase: 'pre' | 'during' | 'post' =
      now < startsAt ? 'pre' : now <= endsAt + 60 * 60 * 1000 ? 'during' : 'post';

    return {
      eventId: event.id,
      hasIntent: Boolean(intent),
      phase,
      startsAt: event.startsAt,
      endsAt: event.endsAt,
      dwellMinimumMin: event.dwellMinimumMin,
      pointsCollected: locusCount + geolocatorCount,
      locusEventsCount: locusCount,
      geolocatorPingsCount: geolocatorCount,
      // Verification-task signals — both flat (legacy) and structured.
      inPolygonLocusCount: locusInside,
      inPolygonGeolocatorCount: geolocatorInside,
      firstInPolygonAt: earliestInside,
      targetSpotCheckCount: targetSpotCheckCount(event.startsAt, event.endsAt),
      tasks,
      photos,
      badge,
      checkin: checkin ? {
        primarySource: checkin.primarySource,
        dwellMinutes: checkin.dwellMinutes,
        verificationScore: checkin.verificationScore,
        isVerified: checkin.isVerified,
        reconciledAt: checkin.reconciledAt,
        // Surfaced so the mobile mapper can flip the
        // deviceTrusted + integrityActive checks (it reads
        // `checkin.integrityVerdict != null`) and the photoCapture
        // check (`checkin.photoId != null`). Without these the
        // active-quest screen never lights up the verification rows
        // even after the integrity attestation + photo upload land.
        integrityVerdict: checkin.integrityVerdict,
        integrityCheckedAt: checkin.integrityCheckedAt,
        photoId: checkin.photoId,
      } : null,
    };
  }

  /**
   * Earliest in-polygon timestamp across both tracks. Drives the
   * "arrival" verification task. Null until the first confirmed point
   * lands.
   */
  private async firstInPolygonAt(userId: string, eventId: string): Promise<Date | null> {
    const [locus, geo] = await Promise.all([
      this.prisma.locusEvent.findFirst({
        where: { userId, eventId, isInsidePolygon: true },
        orderBy: { timestamp: 'asc' },
        select: { timestamp: true },
      }),
      this.prisma.geolocatorPing.findFirst({
        where: { userId, eventId, isInsidePolygon: true },
        orderBy: { timestamp: 'asc' },
        select: { timestamp: true },
      }),
    ]);
    const ts = [locus?.timestamp, geo?.timestamp].filter((t): t is Date => t != null);
    if (ts.length === 0) return null;
    return ts.reduce((a, b) => (a < b ? a : b));
  }

  async sync(user: User, eventId: string, dto: SyncTrackingDto) {
    const event = await this.events.byId(eventId);
    await this.requireIntent(user.id, event.id);

    const locusRows: Prisma.LocusEventCreateManyInput[] = (dto.locusEvents ?? []).map((e) => ({
      userId: user.id,
      eventId: event.id,
      eventType: e.eventType,
      latitude: e.latitude,
      longitude: e.longitude,
      accuracy: e.accuracy ?? null,
      altitude: e.altitude ?? null,
      speed: e.speed ?? null,
      heading: e.heading ?? null,
      activity: e.activity ?? null,
      confidence: e.confidence ?? null,
      timestamp: new Date(e.timestamp),
      rawPayload: (e.rawPayload ?? Prisma.JsonNull) as Prisma.InputJsonValue,
    }));

    const geolocatorRows: Prisma.GeolocatorPingCreateManyInput[] = (dto.geolocatorPings ?? []).map((p) => ({
      userId: user.id,
      eventId: event.id,
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy ?? null,
      altitude: p.altitude ?? null,
      timestamp: new Date(p.timestamp),
      batteryLevel: p.batteryLevel ?? null,
    }));

    const [{ count: locusInserted }, { count: geolocatorInserted }] = await this.prisma.$transaction([
      this.prisma.locusEvent.createMany({ data: locusRows, skipDuplicates: true }),
      this.prisma.geolocatorPing.createMany({ data: geolocatorRows, skipDuplicates: true }),
    ]);

    const inside = await this.geo.applyGeofenceTo(user.id, event.id);

    // Recompute the task ledger after the geofence pass so the rows
    // reflect the latest in-polygon counts. Idempotent — only the rows
    // whose desired state changed get touched, so replay is cheap.
    await this.tasks.recompute(user.id, event.id);

    await this.audit.record({
      type: 'QUEST_SYNC',
      userId: user.id,
      eventId: event.id,
      metadata: {
        locusInserted,
        geolocatorInserted,
        insideLocus: inside.insideLocus,
        insideGeolocator: inside.insideGeolocator,
      },
    });

    return {
      eventId: event.id,
      receivedAt: new Date(),
      locusEventsInserted: locusInserted,
      geolocatorPingsInserted: geolocatorInserted,
      insideGeofence: inside,
    };
  }

  async attestIntegrity(user: User, eventId: string, dto: IntegrityDto) {
    const event = await this.events.byId(eventId);
    await this.requireIntent(user.id, event.id);

    const checkin = await this.prisma.checkin.upsert({
      where: { userId_eventId: { userId: user.id, eventId: event.id } },
      create: {
        userId: user.id,
        eventId: event.id,
        primarySource: 'pending',
        integrityToken: dto.token,
        integrityPlatform: dto.platform,
        integrityVerdict: 'pending_verification',
        integrityCheckedAt: new Date(dto.verifiedAt),
      },
      update: {
        integrityToken: dto.token,
        integrityPlatform: dto.platform,
        integrityVerdict: 'pending_verification',
        integrityCheckedAt: new Date(dto.verifiedAt),
      },
    });
    await this.audit.record({
      type: 'INTEGRITY_ATTESTED',
      userId: user.id,
      eventId: event.id,
      metadata: { platform: dto.platform, verdict: checkin.integrityVerdict },
    });
    return { verdict: checkin.integrityVerdict, verifiedAt: checkin.integrityCheckedAt };
  }

  async uploadPhoto(
    user: User,
    eventId: string,
    file: { buffer: Buffer; mimetype: string; originalname?: string; size: number },
    metadata: UploadPhotoMetadataDto,
  ) {
    const event = await this.events.byId(eventId);
    await this.requireIntent(user.id, event.id);

    if (file.size > 12 * 1024 * 1024) {
      throw new ApiException(HttpStatus.PAYLOAD_TOO_LARGE, 'PHOTO_TOO_LARGE', 'Photo exceeds 12MB');
    }
    const validMimes = ['image/jpeg', 'image/png', 'image/heic', 'image/heif'];
    if (!validMimes.includes(file.mimetype)) {
      throw new ApiException(
        HttpStatus.UNSUPPORTED_MEDIA_TYPE,
        'PHOTO_INVALID_MIME',
        `Allowed: ${validMimes.join(', ')}`,
      );
    }

    const photoId = randomUUID();
    const upload = await this.storage.uploadPhoto(user.id, event.id, photoId, file);

    const exifTs = metadata.exifTimestamp ? new Date(metadata.exifTimestamp) : null;
    const isWithinTimeWindow =
      exifTs !== null &&
      exifTs.getTime() >= event.startsAt.getTime() - 30 * 60 * 1000 &&
      exifTs.getTime() <= event.endsAt.getTime() + 30 * 60 * 1000;
    const hasCoords =
      metadata.exifLatitude !== undefined && metadata.exifLongitude !== undefined;
    const isExifValid = exifTs !== null && hasCoords;
    // The polygon check runs whenever we have coordinates, regardless
    // of whether the EXIF timestamp came through. The mobile fills
    // these coordinates from the live tracker when the camera plugin
    // doesn't embed GPS in the JPEG (common on iOS — privacy modes,
    // simulator, certain hardware), so a successful in-polygon
    // verdict here represents the user's actual position at capture
    // time, not just whatever stale GPS the photo file carried.
    const isInsideGeofence = hasCoords
      ? await this.geo.pointIsInside(event.id, metadata.exifLatitude!, metadata.exifLongitude!)
      : false;

    const photo = await this.prisma.photo.create({
      data: {
        id: photoId,
        userId: user.id,
        eventId: event.id,
        storagePath: upload.path,
        publicUrl: upload.publicUrl,
        exifTimestamp: exifTs,
        exifLatitude: metadata.exifLatitude ?? null,
        exifLongitude: metadata.exifLongitude ?? null,
        exifRaw: (metadata.exifRaw ?? Prisma.JsonNull) as Prisma.InputJsonValue,
        isExifValid,
        isWithinTimeWindow,
        isInsideGeofence,
        processingStatus: 'pending',
      },
    });

    // The badge anchors to the FIRST photo a user captures during the
    // event. Subsequent uploads still create new Photo rows (so the
    // user's record of the moment is richer), but Checkin.photoId is
    // sticky — overwriting it would change which photo composes the
    // badge each time, which is surprising UX.
    const existing = await this.prisma.checkin.findUnique({
      where: { userId_eventId: { userId: user.id, eventId: event.id } },
      select: { photoId: true },
    });
    const isAdditionalPhoto = existing?.photoId != null;
    await this.prisma.checkin.upsert({
      where: { userId_eventId: { userId: user.id, eventId: event.id } },
      create: {
        userId: user.id,
        eventId: event.id,
        primarySource: 'pending',
        photoId: photo.id,
      },
      update: isAdditionalPhoto ? {} : { photoId: photo.id },
    });

    // Photo task transitions to `done` here; recompute persists that.
    await this.tasks.recompute(user.id, event.id);

    await this.audit.record({
      type: 'PHOTO_UPLOADED',
      userId: user.id,
      eventId: event.id,
      metadata: {
        photoId: photo.id,
        isExifValid,
        isWithinTimeWindow,
        isInsideGeofence,
        isAdditionalPhoto,
      },
    });

    return {
      photoId: photo.id,
      isAdditionalPhoto,
      storagePath: photo.storagePath,
      isExifValid,
      isWithinTimeWindow,
      isInsideGeofence,
      uploadedAt: photo.createdAt,
    };
  }

  private async requireIntent(userId: string, eventId: string) {
    const intent = await this.prisma.intent.findUnique({
      where: { userId_eventId: { userId, eventId } },
    });
    if (!intent) {
      throw new ApiException(
        HttpStatus.FORBIDDEN,
        'INTENT_REQUIRED',
        'No active intent for this event — set RSVP first',
      );
    }
  }
}

