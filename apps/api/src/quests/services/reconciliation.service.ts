import { Injectable } from '@nestjs/common';
import type { GeolocatorPing, LocusEvent } from '@prisma/client';

export interface ReconciliationInput {
  locusEvents: LocusEvent[];
  geolocatorPings: GeolocatorPing[];
}

export interface ReconciliationResult {
  primarySource:
    | 'locus_complete'
    | 'locus_partial'
    | 'geolocator_fallback'
    | 'cross_validated'
    | 'divergence_conservative'
    | 'insufficient';
  reason: string;
  dwellMinutes: number;
  firstPointAt: Date | null;
  lastPointAt: Date | null;
  totalPoints: number;
  agreementScore: number | null;
  locusComplete: boolean;
  geolocatorSufficient: boolean;
}

const MIN_GEOLOCATOR_PINGS = 3;

@Injectable()
export class ReconciliationService {
  reconcile(input: ReconciliationInput): ReconciliationResult {
    const locus = [...input.locusEvents].sort(
      (a, b) => a.timestamp.getTime() - b.timestamp.getTime(),
    );
    const geo = [...input.geolocatorPings].sort(
      (a, b) => a.timestamp.getTime() - b.timestamp.getTime(),
    );

    const enter = locus.find((e) => e.eventType === 'GEOFENCE_ENTER');
    const exit = [...locus].reverse().find((e) => e.eventType === 'GEOFENCE_EXIT');
    const locusComplete = Boolean(enter && exit);
    const locusFirst = locus[0]?.timestamp ?? null;
    const locusLast = locus[locus.length - 1]?.timestamp ?? null;
    const geoFirst = geo[0]?.timestamp ?? null;
    const geoLast = geo[geo.length - 1]?.timestamp ?? null;

    const locusDwell = this.dwellMinutes(enter?.timestamp ?? locusFirst, exit?.timestamp ?? locusLast);
    const geoDwell = this.dwellMinutes(geoFirst, geoLast);
    const geolocatorSufficient = geo.length >= MIN_GEOLOCATOR_PINGS;
    const totalPoints = locus.length + geo.length;

    if (locus.length === 0 && !geolocatorSufficient) {
      return {
        primarySource: 'insufficient',
        reason: 'No locus events and not enough geolocator pings',
        dwellMinutes: 0,
        firstPointAt: null,
        lastPointAt: null,
        totalPoints,
        agreementScore: null,
        locusComplete: false,
        geolocatorSufficient: false,
      };
    }

    if (locusComplete && geolocatorSufficient) {
      const agreement = this.agreement(locusDwell, geoDwell);
      if (agreement > 0.8) {
        return {
          primarySource: 'cross_validated',
          reason: 'Locus complete and geolocator agrees (>0.8)',
          dwellMinutes: locusDwell,
          firstPointAt: enter?.timestamp ?? locusFirst,
          lastPointAt: exit?.timestamp ?? locusLast,
          totalPoints,
          agreementScore: agreement,
          locusComplete: true,
          geolocatorSufficient: true,
        };
      }
      if (agreement <= 0.6) {
        const conservativeDwell = Math.min(locusDwell, geoDwell);
        return {
          primarySource: 'divergence_conservative',
          reason: 'Locus and geolocator diverge — taking the smaller dwell',
          dwellMinutes: conservativeDwell,
          firstPointAt: locusFirst && geoFirst ? (locusFirst < geoFirst ? geoFirst : locusFirst) : locusFirst ?? geoFirst,
          lastPointAt: locusLast && geoLast ? (locusLast > geoLast ? geoLast : locusLast) : locusLast ?? geoLast,
          totalPoints,
          agreementScore: agreement,
          locusComplete: true,
          geolocatorSufficient: true,
        };
      }
    }

    if (locusComplete) {
      return {
        primarySource: 'locus_complete',
        reason: 'Locus has enter + exit',
        dwellMinutes: locusDwell,
        firstPointAt: enter?.timestamp ?? locusFirst,
        lastPointAt: exit?.timestamp ?? locusLast,
        totalPoints,
        agreementScore: null,
        locusComplete: true,
        geolocatorSufficient,
      };
    }

    if (locus.length > 0 && geolocatorSufficient) {
      const agreement = this.agreement(locusDwell, geoDwell);
      return {
        primarySource: 'locus_partial',
        reason: 'Locus has points but no enter/exit pair; geolocator confirms',
        dwellMinutes: Math.max(locusDwell, geoDwell),
        firstPointAt: locusFirst && geoFirst ? (locusFirst < geoFirst ? locusFirst : geoFirst) : locusFirst ?? geoFirst,
        lastPointAt: locusLast && geoLast ? (locusLast > geoLast ? locusLast : geoLast) : locusLast ?? geoLast,
        totalPoints,
        agreementScore: agreement,
        locusComplete: false,
        geolocatorSufficient: true,
      };
    }

    return {
      primarySource: 'geolocator_fallback',
      reason: 'Locus missing or sparse — using geolocator',
      dwellMinutes: geoDwell,
      firstPointAt: geoFirst,
      lastPointAt: geoLast,
      totalPoints,
      agreementScore: null,
      locusComplete: false,
      geolocatorSufficient,
    };
  }

  private dwellMinutes(start: Date | null, end: Date | null): number {
    if (!start || !end) return 0;
    return Math.max(0, Math.round((end.getTime() - start.getTime()) / 60_000));
  }

  private agreement(a: number, b: number): number {
    if (a === 0 && b === 0) return 1;
    const max = Math.max(a, b);
    return Math.max(0, 1 - Math.abs(a - b) / max);
  }
}
