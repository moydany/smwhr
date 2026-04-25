import { Injectable } from '@nestjs/common';

export interface ScoreInput {
  dwellMinutes: number;
  dwellMinimumMin: number;
  totalPointsCollected: number;
  agreementScore: number | null;
  integrityVerdict: string | null;
  primarySource: string;
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
    dwell: number;
    tracking: number;
    crossValidation: number;
    integrity: number;
    photo: number;
    penaltyMultiplier: number;
  };
}

const VERIFIED_THRESHOLD = 60;

@Injectable()
export class VerificationService {
  score(input: ScoreInput): ScoreBreakdown {
    const dwellRatio = Math.min(1, input.dwellMinutes / Math.max(1, input.dwellMinimumMin));
    const dwell = Math.round(dwellRatio * 35);

    const tracking = Math.min(25, Math.round((input.totalPointsCollected / 20) * 25));

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

    const raw = dwell + tracking + crossValidation + integrity + photo;
    const penaltyMultiplier = input.primarySource === 'divergence_conservative' ? 0.7 : 1;
    const total = Math.max(0, Math.min(100, Math.round(raw * penaltyMultiplier)));

    return {
      total,
      isVerified: total >= VERIFIED_THRESHOLD,
      parts: { dwell, tracking, crossValidation, integrity, photo, penaltyMultiplier },
    };
  }
}
