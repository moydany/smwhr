import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { EventsService } from '../../events/events.service';
import { PrismaService } from '../../prisma/prisma.service';
import { targetSpotCheckCount } from '../verification-tasks.constants';
import { VERIFIED_SPOT_CHECK_RATIO } from './verification.service';

/**
 * Canonical task ids surfaced to the mobile UI. Mobile mirrors this in
 * `VerificationTaskId`; keep the strings in sync.
 *
 * Order is the rendering order on the active quest screen — UI relies
 * on `listForUser` returning tasks in this order so the checklist stays
 * stable across syncs.
 *
 * Verification model (R0.1+):
 *   - **arrival**: first in-polygon point landed (sanity gate).
 *   - **spot_checks**: N of M random GPS reads inside the polygon.
 *     This is the actual verification gate — see
 *     `VerificationService.score`.
 *   - **photo**: badge anchor.
 *
 * Continuous-dwell ('dwell') was removed because it punished
 * legitimate users (bathroom break = stopwatch reset) and was less
 * spoof-resistant than randomized spot-checks.
 */
export const VERIFICATION_TASK_IDS = [
  'arrival',
  'spot_checks',
  'photo',
] as const;

export type VerificationTaskId = (typeof VERIFICATION_TASK_IDS)[number];
export type VerificationTaskStatus = 'pending' | 'active' | 'done';

export interface VerificationTaskRow {
  taskId: VerificationTaskId;
  status: VerificationTaskStatus;
  evidenceAt: Date | null;
  evidenceRefId: string | null;
  progressN: number | null;
  progressM: number | null;
  updatedAt: Date;
}

interface DesiredTask {
  status: VerificationTaskStatus;
  evidenceAt?: Date | null;
  evidenceRefId?: string | null;
  progressN?: number | null;
  progressM?: number | null;
}

/**
 * Persistent ledger of verification tasks per (user, event). Owns both
 * the recompute pipeline (called from `sync` + `photo`) and the read
 * API consumed by `getStatus`.
 *
 * Recompute is intentionally idempotent: it derives the *desired* state
 * from the underlying signal tables (LocusEvent, GeolocatorPing,
 * Checkin, Photo) and upserts only the rows that changed. Replaying
 * the same sync produces no writes; replaying after new data lands
 * nudges exactly the affected rows.
 *
 * Tasks live in `verification_tasks`; the table is small (≤4 rows per
 * (user,event)) so the recompute query is cheap even on a hot path.
 */
@Injectable()
export class VerificationTasksService {
  private readonly logger = new Logger(VerificationTasksService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventsService,
  ) {}

  async recompute(userId: string, eventId: string): Promise<VerificationTaskRow[]> {
    const event = await this.events.byId(eventId);

    const [
      firstInsideLocus,
      firstInsideGeolocator,
      inPolygonGeolocatorCount,
      photo,
    ] = await Promise.all([
      this.prisma.locusEvent.findFirst({
        where: { userId, eventId, isInsidePolygon: true },
        orderBy: { timestamp: 'asc' },
        select: { id: true, timestamp: true },
      }),
      this.prisma.geolocatorPing.findFirst({
        where: { userId, eventId, isInsidePolygon: true },
        orderBy: { timestamp: 'asc' },
        select: { id: true, timestamp: true },
      }),
      this.prisma.geolocatorPing.count({
        where: { userId, eventId, isInsidePolygon: true },
      }),
      this.prisma.photo.findFirst({
        where: { userId, checkin: { eventId } },
        orderBy: { createdAt: 'asc' },
        select: { id: true, createdAt: true },
      }),
    ]);

    // Earliest in-polygon evidence (locus or geolocator), used by the
    // arrival task. Falls through to null while the user is still
    // outside the polygon.
    const firstInside =
      firstInsideLocus && firstInsideGeolocator
        ? firstInsideLocus.timestamp <= firstInsideGeolocator.timestamp
          ? firstInsideLocus
          : firstInsideGeolocator
        : firstInsideLocus ?? firstInsideGeolocator ?? null;

    const targetCount = targetSpotCheckCount(event.startsAt, event.endsAt);
    // Mirror the verifier's gate: task is "done" the moment the user
    // crosses the in-polygon ratio threshold, not when they land in
    // every single attempt. Keeps the UI checklist consistent with
    // what `VerificationService.score` will accept at finalize time.
    const requiredInPolygon = Math.ceil(targetCount * VERIFIED_SPOT_CHECK_RATIO);

    const desired: Record<VerificationTaskId, DesiredTask> = {
      arrival: firstInside
        ? {
            status: 'done',
            evidenceAt: firstInside.timestamp,
            evidenceRefId: firstInside.id,
          }
        : { status: 'pending' },
      spot_checks: {
        status:
          inPolygonGeolocatorCount >= requiredInPolygon
            ? 'done'
            : inPolygonGeolocatorCount > 0
              ? 'active'
              : 'pending',
        progressN: inPolygonGeolocatorCount,
        progressM: targetCount,
        evidenceAt:
          inPolygonGeolocatorCount >= requiredInPolygon
            ? firstInsideGeolocator?.timestamp ?? null
            : null,
      },
      photo: photo
        ? {
            status: 'done',
            evidenceAt: photo.createdAt,
            evidenceRefId: photo.id,
          }
        : firstInside
          ? { status: 'active' }
          : { status: 'pending' },
    };

    // Read the existing rows once, decide per-task whether to upsert. A
    // bulk upsert would skip the no-op short-circuit and dirty
    // updatedAt every sync — keeping this fine-grained makes the audit
    // trail meaningful.
    const existing = await this.prisma.verificationTask.findMany({
      where: { userId, eventId },
    });
    const byTaskId = new Map(existing.map((r) => [r.taskId, r]));

    for (const taskId of VERIFICATION_TASK_IDS) {
      const want = desired[taskId];
      const have = byTaskId.get(taskId);
      if (have && taskRowMatches(have, want)) continue;

      await this.prisma.verificationTask.upsert({
        where: { userId_eventId_taskId: { userId, eventId, taskId } },
        create: {
          userId,
          eventId,
          taskId,
          status: want.status,
          evidenceAt: want.evidenceAt ?? null,
          evidenceRefId: want.evidenceRefId ?? null,
          progressN: want.progressN ?? null,
          progressM: want.progressM ?? null,
        },
        update: {
          status: want.status,
          evidenceAt: want.evidenceAt ?? null,
          evidenceRefId: want.evidenceRefId ?? null,
          progressN: want.progressN ?? null,
          progressM: want.progressM ?? null,
        },
      });
    }

    // Sweep stale rows whose taskId no longer appears in
    // VERIFICATION_TASK_IDS (e.g. legacy 'dwell' rows from before R0.1's
    // verification redesign). Self-healing — keeps the audit log
    // honest and means we don't need a separate migration to drop
    // dropped task ids.
    const stale = existing
      .filter((r) => !(VERIFICATION_TASK_IDS as readonly string[]).includes(r.taskId))
      .map((r) => r.id);
    if (stale.length > 0) {
      await this.prisma.verificationTask.deleteMany({
        where: { id: { in: stale } },
      });
    }

    return this.listForUser(userId, eventId);
  }

  async listForUser(
    userId: string,
    eventId: string,
  ): Promise<VerificationTaskRow[]> {
    const rows = await this.prisma.verificationTask.findMany({
      where: { userId, eventId },
    });
    const byId = new Map(rows.map((r) => [r.taskId as VerificationTaskId, r]));
    // Always return in canonical order, with placeholder rows for tasks
    // the recompute path hasn't materialised yet (cold-start UX).
    return VERIFICATION_TASK_IDS.map<VerificationTaskRow>((id) => {
      const r = byId.get(id);
      if (r) {
        return {
          taskId: id,
          status: r.status as VerificationTaskStatus,
          evidenceAt: r.evidenceAt,
          evidenceRefId: r.evidenceRefId,
          progressN: r.progressN,
          progressM: r.progressM,
          updatedAt: r.updatedAt,
        };
      }
      return {
        taskId: id,
        status: 'pending',
        evidenceAt: null,
        evidenceRefId: null,
        progressN: null,
        progressM: null,
        updatedAt: new Date(0),
      };
    });
  }
}

function taskRowMatches(
  have: Prisma.VerificationTaskGetPayload<true>,
  want: DesiredTask,
): boolean {
  return (
    have.status === want.status &&
    sameDate(have.evidenceAt, want.evidenceAt ?? null) &&
    (have.evidenceRefId ?? null) === (want.evidenceRefId ?? null) &&
    (have.progressN ?? null) === (want.progressN ?? null) &&
    (have.progressM ?? null) === (want.progressM ?? null)
  );
}

function sameDate(a: Date | null, b: Date | null): boolean {
  if (a === null && b === null) return true;
  if (a === null || b === null) return false;
  return a.getTime() === b.getTime();
}
