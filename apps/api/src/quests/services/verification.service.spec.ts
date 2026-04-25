import { VerificationService } from './verification.service';

describe('VerificationService', () => {
  const svc = new VerificationService();

  it('full dwell + good tracking + agreement + trusted + photo → high score', () => {
    const r = svc.score({
      dwellMinutes: 90,
      dwellMinimumMin: 60,
      totalPointsCollected: 30,
      agreementScore: 0.92,
      integrityVerdict: 'trusted',
      primarySource: 'locus',
      photo: { isExifValid: true, isInsideGeofence: true, isWithinTimeWindow: true },
    });
    expect(r.parts.dwell).toBe(35);
    expect(r.parts.tracking).toBe(25);
    expect(r.parts.crossValidation).toBe(10);
    expect(r.parts.integrity).toBe(15);
    expect(r.parts.photo).toBe(15);
    expect(r.total).toBe(100);
    expect(r.isVerified).toBe(true);
  });

  it('partial dwell + no photo + no integrity → below threshold', () => {
    const r = svc.score({
      dwellMinutes: 20,
      dwellMinimumMin: 60,
      totalPointsCollected: 8,
      agreementScore: null,
      integrityVerdict: null,
      primarySource: 'locus',
      photo: null,
    });
    expect(r.parts.dwell).toBeLessThan(15);
    expect(r.parts.tracking).toBeLessThan(15);
    expect(r.total).toBeLessThan(60);
    expect(r.isVerified).toBe(false);
  });

  it('divergence_conservative applies 0.7× penalty', () => {
    const a = svc.score({ dwellMinutes: 90, dwellMinimumMin: 60, totalPointsCollected: 30, agreementScore: 0.92, integrityVerdict: 'trusted', primarySource: 'locus', photo: null });
    const b = svc.score({ dwellMinutes: 90, dwellMinimumMin: 60, totalPointsCollected: 30, agreementScore: 0.92, integrityVerdict: 'trusted', primarySource: 'divergence_conservative', photo: null });
    expect(b.total).toBeLessThan(a.total);
    expect(b.parts.penaltyMultiplier).toBe(0.7);
  });

  it('clamps score in [0, 100]', () => {
    const r = svc.score({
      dwellMinutes: 5000,
      dwellMinimumMin: 60,
      totalPointsCollected: 5000,
      agreementScore: 0.99,
      integrityVerdict: 'trusted',
      primarySource: 'locus',
      photo: { isExifValid: true, isInsideGeofence: true, isWithinTimeWindow: true },
    });
    expect(r.total).toBe(100);
  });

  it('agreement 0.7 grants 5 pts; 0.5 grants 0 pts', () => {
    const a = svc.score({ dwellMinutes: 60, dwellMinimumMin: 60, totalPointsCollected: 10, agreementScore: 0.7, integrityVerdict: null, primarySource: 'locus', photo: null });
    const b = svc.score({ dwellMinutes: 60, dwellMinimumMin: 60, totalPointsCollected: 10, agreementScore: 0.5, integrityVerdict: null, primarySource: 'locus', photo: null });
    expect(a.parts.crossValidation).toBe(5);
    expect(b.parts.crossValidation).toBe(0);
  });
});
