import 'dart:async';

import '../../../data/local/tracking_db.dart';
import '../../../data/models/quest.dart';

/// Closure that ships a batch up to the backend. Decoupled from the
/// repository class so [TrackingSync] doesn't need to know about Dio /
/// auth interceptors / etc. — and so we don't form the cycle
/// `RealQuestsRepository → QuestTracker → TrackingSync → RealQuestsRepository`.
typedef SyncBatchFn = Future<void> Function({
  required String eventId,
  required List<LocusEvent> locusEvents,
  required List<GeolocatorPing> geolocatorPings,
});

/// Periodic uploader for the dual-track tracker.
///
/// Cadence: every 30 minutes during an active quest (locked decision #4).
/// Tests can override the interval. A final sync runs on `stopQuest` to
/// drain any rows the last tick missed.
///
/// Failure mode: any exception thrown by the [SyncBatchFn] is swallowed;
/// the local rows stay marked unsynced and the next tick (or finalSync)
/// retries. `markSynced` only runs after a successful POST.
class TrackingSync {
  TrackingSync({
    required TrackingDb db,
    required SyncBatchFn syncFn,
    Duration? defaultInterval,
  })  : _db = db,
        _syncFn = syncFn,
        _defaultInterval = defaultInterval ?? const Duration(minutes: 30);

  /// Production cadence per locked decision #4. The provider in
  /// `data/providers.dart` overrides this from `Env.questSyncIntervalSeconds`
  /// for dev / smoke testing.
  static const Duration productionInterval = Duration(minutes: 30);

  final TrackingDb _db;
  final SyncBatchFn _syncFn;
  final Duration _defaultInterval;
  final Map<String, Timer> _timers = {};

  /// Arms a `Timer.periodic` that calls [syncBatch] every [interval].
  /// Replaces any existing timer for [eventId]. When [interval] is omitted,
  /// uses the instance's [_defaultInterval] (set at construction time
  /// from `Env.questSyncIntervalSeconds`).
  void schedulePeriodic(
    String eventId, {
    Duration? interval,
  }) {
    final effective = interval ?? _defaultInterval;
    _timers[eventId]?.cancel();
    _timers[eventId] = Timer.periodic(effective, (_) {
      // Fire-and-forget; errors are handled inside syncBatch.
      syncBatch(eventId);
    });
  }

  /// Cancels the scheduled timer for [eventId], if any. Does NOT drain.
  void cancel(String eventId) {
    _timers.remove(eventId)?.cancel();
  }

  void cancelAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }

  /// Reads everything unsynced for [eventId], POSTs it, and marks the
  /// returned ids as synced. No-op when there's nothing pending.
  Future<void> syncBatch(String eventId) async {
    final locusEvents = await _db.unsyncedLocusEvents(eventId);
    final pings = await _db.unsyncedGeolocatorPings(eventId);
    if (locusEvents.isEmpty && pings.isEmpty) return;
    try {
      await _syncFn(
        eventId: eventId,
        locusEvents: locusEvents,
        geolocatorPings: pings,
      );
      await _db.markSynced(
        locusIds: locusEvents.map((e) => e.id).toList(growable: false),
        pingIds: pings.map((p) => p.id).toList(growable: false),
      );
    } catch (_) {
      // Transient — next tick / finalSync retries.
    }
  }

  /// Stops the timer for [eventId] and drains any remaining unsynced rows.
  /// Called by `QuestTracker.stopQuest`.
  Future<void> finalSync(String eventId) async {
    cancel(eventId);
    await syncBatch(eventId);
  }
}
