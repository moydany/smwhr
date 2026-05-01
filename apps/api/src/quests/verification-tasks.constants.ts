/**
 * Number of randomized geolocator spot-checks the mobile fires during
 * the event window. The slot-based scheduler in `GeolocatorTracker.
 * startRandomized` divides the event into this many equal slots and
 * fires one ping per slot at a random offset, so a higher count buys
 * both more chances to land in-polygon and tighter time-distribution
 * (each fire is constrained to a different slot, naturally satisfying
 * the "no consecutive checks" requirement).
 *
 * Roughly one per 12 minutes, clamped so:
 *   - even very short events still get a few attempts (min 4 → covers
 *     a 15-min event with 1 ping every ~4 min)
 *   - very long events don't over-poll (max 20 → covers up to 4 hours
 *     at canonical cadence; longer events hit the ceiling)
 *
 * Paired with `VERIFIED_SPOT_CHECK_RATIO = 0.4`, a user passes by
 * landing inside the polygon for 40% of attempts. For a typical 4h
 * concert: 20 attempts, 8 inside is enough. For a 1h event: 5
 * attempts, 2 inside.
 *
 * Lives outside `quests.service.ts` so both the status response and the
 * verification-tasks ledger derive the same `M` for the "spot checks
 * N/M" task — keeping the formula in one place prevents drift.
 *
 * Mobile mirrors this in:
 *   - `apps/mobile/lib/features/quest/services/quest_tracker.dart`
 *     (`_targetSpotCheckCount` — used to schedule the random timers)
 *   - `apps/mobile/lib/features/quest/services/local_quest_status.dart`
 *     (`_targetSpotCheckCount` — used for the offline UI N/M display)
 * Keep all three in sync.
 */
export function targetSpotCheckCount(startsAt: Date, endsAt: Date): number {
  const minutes = Math.max(0, (endsAt.getTime() - startsAt.getTime()) / 60_000);
  const raw = Math.round(minutes / 12);
  return Math.min(20, Math.max(4, raw));
}
