import {
  VerificationService,
  VERIFIED_SPOT_CHECK_RATIO,
} from './verification.service';

describe('VerificationService', () => {
  const svc = new VerificationService();

  // Defaults shared by happy-path tests — keep them in one place so
  // each case only spells out what it's asserting against.
  const baseInput = {
    inPolygonGeolocatorCount: 4,
    targetSpotCheckCount: 4,
    hasArrived: true,
    totalPointsCollected: 30,
    agreementScore: 0.92,
    integrityVerdict: 'trusted',
    primarySource: 'cross_validated',
    photo: { isExifValid: true, isInsideGeofence: true, isWithinTimeWindow: true },
  };

  it('full presence + good tracking + agreement + trusted + photo → maxes out', () => {
    const r = svc.score(baseInput);
    expect(r.parts.presence).toBe(35);
    expect(r.parts.presenceRatio).toBe(1);
    expect(r.parts.tracking).toBe(25);
    expect(r.parts.crossValidation).toBe(10);
    expect(r.parts.integrity).toBe(15);
    expect(r.parts.photo).toBe(15);
    expect(r.total).toBe(100);
    expect(r.isVerified).toBe(true);
  });

  it('presence at the gate (ratio = 0.4) gets full credit AND verifies', () => {
    // 8 of 20 attempts landed inside — exactly the gate. The "8 of 20
    // across different hours" example from the design doc.
    const r = svc.score({
      ...baseInput,
      inPolygonGeolocatorCount: 8,
      targetSpotCheckCount: 20,
    });
    expect(r.parts.presenceRatio).toBeCloseTo(0.4, 5);
    expect(r.parts.presence).toBe(35);
    expect(r.isVerified).toBe(true);
  });

  it('presence below the gate (ratio < 0.4) blocks issuance even if total clears the threshold', () => {
    // Score everything else maxed, but only 1 of 10 spot-checks landed
    // inside (ratio 0.1). Hard gate must reject.
    const r = svc.score({
      ...baseInput,
      inPolygonGeolocatorCount: 1,
      targetSpotCheckCount: 10,
    });
    expect(r.parts.presence).toBeLessThan(35);
    expect(r.parts.presenceRatio).toBeCloseTo(0.1, 5);
    // Even if total clears the threshold from tracking + integrity +
    // photo, the spot-check gate must dominate.
    expect(r.isVerified).toBe(false);
  });

  it('presence scales linearly up to the gate', () => {
    // 4/20 = 0.2 = exactly half the gate ratio (0.4) → half the
    // presence points (35/2 = 17.5, rounds to 18).
    const r = svc.score({
      ...baseInput,
      inPolygonGeolocatorCount: 4,
      targetSpotCheckCount: 20,
    });
    expect(r.parts.presenceRatio).toBeCloseTo(VERIFIED_SPOT_CHECK_RATIO / 2, 5);
    expect(r.parts.presence).toBe(18);
  });

  it('hasArrived = false vetoes verification regardless of score', () => {
    // User somehow has lots of in-polygon spot-checks recorded but the
    // arrival sanity flag is false (data corruption / replay attack).
    // Still rejected.
    const r = svc.score({
      ...baseInput,
      hasArrived: false,
    });
    expect(r.total).toBeGreaterThanOrEqual(40);
    expect(r.isVerified).toBe(false);
  });

  it('zero spot-checks scheduled → presence ratio is 0, not NaN', () => {
    const r = svc.score({
      ...baseInput,
      inPolygonGeolocatorCount: 0,
      targetSpotCheckCount: 0,
    });
    expect(r.parts.presenceRatio).toBe(0);
    expect(r.parts.presence).toBe(0);
    expect(r.isVerified).toBe(false);
  });

  it('partial presence + no photo + no integrity → below threshold', () => {
    const r = svc.score({
      ...baseInput,
      inPolygonGeolocatorCount: 1,
      targetSpotCheckCount: 4,
      totalPointsCollected: 8,
      agreementScore: null,
      integrityVerdict: null,
      photo: null,
    });
    expect(r.parts.presence).toBeLessThan(35);
    expect(r.parts.tracking).toBeLessThan(15);
    expect(r.total).toBeLessThan(40);
    expect(r.isVerified).toBe(false);
  });

  it('divergence_conservative applies 0.7× penalty', () => {
    const a = svc.score({ ...baseInput, photo: null });
    const b = svc.score({
      ...baseInput,
      photo: null,
      primarySource: 'divergence_conservative',
    });
    expect(b.total).toBeLessThan(a.total);
    expect(b.parts.penaltyMultiplier).toBe(0.7);
  });

  it('clamps total in [0, 100]', () => {
    const r = svc.score({
      ...baseInput,
      inPolygonGeolocatorCount: 999,
      targetSpotCheckCount: 1,
      totalPointsCollected: 5000,
      agreementScore: 0.99,
    });
    expect(r.total).toBe(100);
  });

  it('agreement 0.7 grants 5 pts; 0.5 grants 0 pts', () => {
    const a = svc.score({
      ...baseInput,
      agreementScore: 0.7,
      integrityVerdict: null,
      photo: null,
    });
    const b = svc.score({
      ...baseInput,
      agreementScore: 0.5,
      integrityVerdict: null,
      photo: null,
    });
    expect(a.parts.crossValidation).toBe(5);
    expect(b.parts.crossValidation).toBe(0);
  });
});
