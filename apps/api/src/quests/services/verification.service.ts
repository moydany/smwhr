import { Injectable } from '@nestjs/common';

export interface ScoreInput {
  /** Spot-checks that landed inside the venue polygon (geolocator). */
  inPolygonGeolocatorCount: number;

  /** Total spot-checks the mobile was scheduled to fire. Comes from
   *  `targetSpotCheckCount(event.startsAt, event.endsAt)`; mirrors what
   *  the mobile UI displays as `N/M`. */
  targetSpotCheckCount: number;

  /** True the moment ANY in-polygon point lands (locus or geolocator).
   *  Acts as a sanity gate — if the user never showed up, no badge,
   *  full stop, regardless of total score. */
  hasArrived: boolean;

  /** Volume of raw tracker data — keeps the "we tried hard to verify"
   *  signal independent of how much landed inside the polygon. */
  totalPointsCollected: number;

  /** Cross-validation: locus and geolocator dwell agreement (0..1). */
  agreementScore: number | null;

  /** App Attest / Play Integrity verdict. */
  integrityVerdict: string | null;

  /** Reconciliation primary source — drives the divergence penalty. */
  primarySource: string;

  /** Photo metadata. Optional — null until the user captures. */
  photo?: {
    isExifValid: boolean;
    isWithinTimeWindow: boolean;
    isInsideGeofence: boolean;
  } | null;
}

export interface ScoreBreakdown {
  total: number;
  isVerified: boolean;
  parts: {
    /** Earned presence points — based on the spot-check ratio. */
    presence: number;
    /** The actual N/M ratio, surfaced for the audit log. */
    presenceRatio: number;
    tracking: number;
    crossValidation: number;
    integrity: number;
    photo: number;
    penaltyMultiplier: number;
  };
}

/**
 * Final verification gates. The mobile UI mirrors the ratio gate
 * visually (the master "verification" progress bar fills as
 * `inPolygonGeolocatorCount / targetSpotCheckCount` approaches this
 * value). Keeping the constant here means the server is the single
 * source of truth — clients can render their own progress bars off
 * `targetSpotCheckCount`, but issuance is decided here.
 */
export const VERIFIED_SPOT_CHECK_RATIO = 0.7;
// The score threshold is layered defense, not the canonical
// verification rule — `presenceRatio >= VERIFIED_SPOT_CHECK_RATIO`
// + `hasArrived` are the actual gates per R0.1. The previous 60
// was calibrated against multi-hour concerts with hundreds of
// tracker points; on shorter events (clinic visits, sub-1h
// gatherings) even a fully-passing user maxed at ~57 because
// `tracking` scales with point volume and `integrity` is stubbed
// at 3 pending real DeviceCheck/Play Integrity wiring. Dropping to
// 40 keeps the threshold meaningful (a wholly-failed run scores in
// the teens) without rejecting legitimate short events.
export const VERIFIED_SCORE_THRESHOLD = 40;

@Injectable()
export class VerificationService {
  score(input: ScoreInput): ScoreBreakdown {
    const target = Math.max(0, input.targetSpotCheckCount);
    const inPoly = Math.max(0, input.inPolygonGeolocatorCount);
    const presenceRatio = target === 0 ? 0 : Math.min(1, inPoly / target);

    // Presence is the headline component (35 pts). Linear up to the
    // ratio gate; saturates at full credit there. So a user that hits
    // 70% in-polygon spot-checks gets the full 35 pts; anything less
    // scales down proportionally.
    const presence = Math.round(
      Math.min(1, presenceRatio / VERIFIED_SPOT_CHECK_RATIO) * 35,
    );

    const tracking = Math.min(
      25,
      Math.round((input.totalPointsCollected / 20) * 25),
    );

    let crossValidation = 0;
    if (input.agreementScore !== null) {
      if (input.agreementScore > 0.8) crossValidation = 10;
      else if (input.agreementScore > 0.6) crossValidation = 5;
    }

    let integrity = 0;
    switch (input.integrityVerdict) {
      case 'trusted':
        integrity = 15;
        break;
      case 'pending_verification':
        integrity = 3;
        break;
      default:
        integrity = 0;
    }

    let photo = 0;
    if (input.photo) {
      if (input.photo.isExifValid) photo += 7;
      if (input.photo.isInsideGeofence) photo += 4;
      if (input.photo.isWithinTimeWindow) photo += 4;
    }

    const raw = presence + tracking + crossValidation + integrity + photo;
    const penaltyMultiplier =
      input.primarySource === 'divergence_conservative' ? 0.7 : 1;
    const total = Math.max(0, Math.min(100, Math.round(raw * penaltyMultiplier)));

    // Two hard gates layered on top of the score threshold:
    //   1. The user must have actually arrived (some in-polygon point
    //      landed). Without this, score might still cross 60 from
    //      tracking + integrity alone — that would issue a badge to
    //      someone who never showed up.
    //   2. The spot-check ratio must clear `VERIFIED_SPOT_CHECK_RATIO`.
    //      This is the explicit verification rule that replaces the
    //      old `dwellMinutes >= dwellMinimumMin` test — anti-spoof by
    //      construction (random sampling timing) and tolerant of brief
    //      steps outside (no continuous-dwell pressure).
    const isVerified =
      total >= VERIFIED_SCORE_THRESHOLD &&
      input.hasArrived &&
      presenceRatio >= VERIFIED_SPOT_CHECK_RATIO;

    return {
      total,
      isVerified,
      parts: {
        presence,
        presenceRatio,
        tracking,
        crossValidation,
        integrity,
        photo,
        penaltyMultiplier,
      },
    };
  }
}
