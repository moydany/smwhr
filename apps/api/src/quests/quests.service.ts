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
  ) {}

  async getStatus(user: User, eventId: string) {
    const event = await this.events.byId(eventId);
    const intent = await this.prisma.intent.findUnique({
      where: { userId_eventId: { userId: user.id, eventId: event.id } },
    });
    const checkin = await this.prisma.checkin.findUnique({
      where: { userId_eventId: { userId: user.id, eventId: event.id } },
    });
    const [locusCount, geolocatorCount] = await Promise.all([
      this.prisma.locusEvent.count({ where: { userId: user.id, eventId: event.id } }),
      this.prisma.geolocatorPing.count({ where: { userId: user.id, eventId: event.id } }),
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
    const isExifValid = exifTs !== null && metadata.exifLatitude !== undefined && metadata.exifLongitude !== undefined;
    const isInsideGeofence =
      isExifValid && metadata.exifLatitude !== undefined && metadata.exifLongitude !== undefined
        ? await this.geo.pointIsInside(event.id, metadata.exifLatitude, metadata.exifLongitude)
        : false;

    const photo = await this.prisma.photo.create({
      data: {
        id: photoId,
        userId: user.id,
        storagePath: upload.path,
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

    await this.prisma.checkin.upsert({
      where: { userId_eventId: { userId: user.id, eventId: event.id } },
      create: {
        userId: user.id,
        eventId: event.id,
        primarySource: 'pending',
        photoId: photo.id,
      },
      update: { photoId: photo.id },
    });

    await this.audit.record({
      type: 'PHOTO_UPLOADED',
      userId: user.id,
      eventId: event.id,
      metadata: { photoId: photo.id, isExifValid, isWithinTimeWindow, isInsideGeofence },
    });

    return {
      photoId: photo.id,
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
