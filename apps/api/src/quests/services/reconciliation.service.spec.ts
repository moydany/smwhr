import { ReconciliationService } from './reconciliation.service';

const svc = new ReconciliationService();

function locus(eventType: string, minutesAgo: number) {
  return {
    id: 'x',
    userId: 'u',
    eventId: 'e',
    eventType,
    latitude: 0,
    longitude: 0,
    accuracy: null,
    altitude: null,
    speed: null,
    heading: null,
    activity: null,
    confidence: null,
    timestamp: new Date(Date.now() - minutesAgo * 60_000),
    receivedAt: new Date(),
    isInsidePolygon: false,
    rawPayload: null,
  } as any;
}

function ping(minutesAgo: number) {
  return {
    id: 'y',
    userId: 'u',
    eventId: 'e',
    latitude: 0,
    longitude: 0,
    accuracy: null,
    altitude: null,
    timestamp: new Date(Date.now() - minutesAgo * 60_000),
    receivedAt: new Date(),
    isInsidePolygon: false,
    batteryLevel: null,
  } as any;
}

describe('ReconciliationService', () => {
  it('locus complete + geolocator agrees → cross_validated', () => {
    const r = svc.reconcile({
      locusEvents: [locus('GEOFENCE_ENTER', 90), locus('LOCATION_UPDATE', 60), locus('GEOFENCE_EXIT', 30)],
      geolocatorPings: [ping(85), ping(60), ping(35)],
    });
    expect(r.primarySource).toBe('cross_validated');
    expect(r.dwellMinutes).toBe(60);
    expect(r.agreementScore).toBeGreaterThan(0.8);
  });

  it('locus complete only → locus_complete', () => {
    const r = svc.reconcile({
      locusEvents: [locus('GEOFENCE_ENTER', 90), locus('GEOFENCE_EXIT', 30)],
      geolocatorPings: [],
    });
    expect(r.primarySource).toBe('locus_complete');
    expect(r.dwellMinutes).toBe(60);
    expect(r.agreementScore).toBeNull();
  });

  it('locus partial (no exit) + geolocator sufficient → locus_partial', () => {
    const r = svc.reconcile({
      locusEvents: [locus('GEOFENCE_ENTER', 90), locus('LOCATION_UPDATE', 60)],
      geolocatorPings: [ping(85), ping(55), ping(35)],
    });
    expect(r.primarySource).toBe('locus_partial');
    expect(r.dwellMinutes).toBeGreaterThan(0);
  });

  it('geolocator only → geolocator_fallback', () => {
    const r = svc.reconcile({
      locusEvents: [],
      geolocatorPings: [ping(85), ping(60), ping(40), ping(20)],
    });
    expect(r.primarySource).toBe('geolocator_fallback');
    expect(r.dwellMinutes).toBe(65);
  });

  it('no points → insufficient', () => {
    const r = svc.reconcile({ locusEvents: [], geolocatorPings: [] });
    expect(r.primarySource).toBe('insufficient');
    expect(r.dwellMinutes).toBe(0);
  });

  it('locus complete with strong divergence → divergence_conservative (smaller dwell)', () => {
    // locus says 60 min, geolocator says 10 min
    const r = svc.reconcile({
      locusEvents: [locus('GEOFENCE_ENTER', 90), locus('GEOFENCE_EXIT', 30)],
      geolocatorPings: [ping(35), ping(30), ping(25)],
    });
    expect(r.primarySource).toBe('divergence_conservative');
    expect(r.dwellMinutes).toBe(10);
    expect(r.agreementScore).toBeLessThanOrEqual(0.6);
  });
});
