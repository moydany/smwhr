import '../../../data/local/tracking_db.dart';
import 'tracking_sync.dart';

/// Best-effort drain of any tracker rows left in Hive from a quest that
/// ended before the network came back.
///
/// Walks `TrackingDb.recordedEventIds()` (the cumulative list of every
/// event id ever opened on this device), opens each event's boxes, and
/// asks `TrackingSync.syncBatch` to drain. If the box is fully synced
/// after the call (no rows left to send), we also drop the id from the
/// index so the next boot doesn't keep reopening dead boxes.
///
/// Failure is silent — `syncBatch` already swallows transient HTTP
/// errors; we just leave the id in the index for the next boot.
///
/// Called from `main.dart` after the auth token is loaded; one-shot,
/// runs in the background, never blocks the splash.
class BootDrainService {
  BootDrainService({required this.db, required this.sync});

  final TrackingDb db;
  final TrackingSync sync;

  Future<void> run() async {
    final ids = await db.recordedEventIds();
    for (final id in ids) {
      try {
        await db.open(id);
        await sync.syncBatch(id);
        // If everything synced, the box is "clean" — drop the index entry.
        final unsyncedLocus = await db.unsyncedLocusEvents(id);
        final unsyncedPings = await db.unsyncedGeolocatorPings(id);
        if (unsyncedLocus.isEmpty && unsyncedPings.isEmpty) {
          await db.forgetEventId(id);
        }
      } catch (_) {
        // Box couldn't open / corrupted / etc. Skip; next boot tries again.
      } finally {
        await db.close(id);
      }
    }
  }
}
