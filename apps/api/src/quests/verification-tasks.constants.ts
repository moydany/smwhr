/**
 * Number of randomized geolocator spot-checks the mobile fires during
 * the event window. Roughly one per half-hour, clamped so short shows
 * still get enough coverage and long festivals don't over-poll.
 *
 * Lives outside `quests.service.ts` so both the status response and the
 * verification-tasks ledger derive the same `M` for the "spot checks
 * N/M" task — keeping the formula in one place prevents drift.
 */
export function targetSpotCheckCount(startsAt: Date, endsAt: Date): number {
  const minutes = Math.max(0, (endsAt.getTime() - startsAt.getTime()) / 60_000);
  const raw = Math.round(minutes / 30);
  return Math.min(6, Math.max(3, raw));
}
