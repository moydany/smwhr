import 'dart:async';

import '../../../data/local/photo_queue.dart';
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

/// Closure that ships a single queued photo to the backend. Same
/// decoupling rationale as [SyncBatchFn] — TrackingSync stays free of
/// HTTP plumbing.
typedef PhotoUploadFn = Future<void> Function({
  required String eventId,
  required PendingPhoto photo,
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
    PhotoQueue? photoQueue,
    PhotoUploadFn? photoUploadFn,
    Duration? defaultInterval,
  })  : _db = db,
        _syncFn = syncFn,
        _photoQueue = photoQueue,
        _photoUploadFn = photoUploadFn,
        _defaultInterval = defaultInterval ?? const Duration(minutes: 30);

  /// Production cadence per locked decision #4. The provider in
  /// `data/providers.dart` overrides this from `Env.questSyncIntervalSeconds`
  /// for dev / smoke testing.
  static const Duration productionInterval = Duration(minutes: 30);

  final TrackingDb _db;
  final SyncBatchFn _syncFn;
  final PhotoQueue? _photoQueue;
  final PhotoUploadFn? _photoUploadFn;
  final Duration _defaultInterval;
  final Map<String, Timer> _timers = {};
  // Coalesces concurrent `drainPendingPhoto` calls per eventId. Two
  // callers fire this method — the camera screen (immediately after
  // capture) and the periodic timer (every sync tick). When a photo
  // upload takes longer than the sync interval (very common on 4G
  // for full-res JPGs), the timer-driven call observes the still-
  // queued entry and uploads it AGAIN, giving the backend two Photo
  // rows for one capture. The mutex collapses overlapping calls into
  // a single in-flight Future.
  final Map<String, Future<void>> _drainInFlight = {};

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
      // Fire-and-forget; errors are handled inside each call.
      syncBatch(eventId);
      drainPendingPhoto(eventId);
    });
  }

  /// Tries to ship the photo queued for [eventId], if any. Cleared on
  /// success; left in place on failure so the next tick (or
  /// `finalSync`) retries. No-op when the queue is empty or no
  /// uploader was wired in (mocks / tests).
  ///
  /// Concurrency: a drain already in flight for the same eventId is
  /// returned as-is — see `_drainInFlight` for why.
  Future<void> drainPendingPhoto(String eventId) async {
    final inFlight = _drainInFlight[eventId];
    if (inFlight != null) return inFlight;

    final future = _doDrain(eventId);
    _drainInFlight[eventId] = future;
    try {
      await future;
    } finally {
      _drainInFlight.remove(eventId);
    }
  }

  Future<void> _doDrain(String eventId) async {
    final queue = _photoQueue;
    final upload = _photoUploadFn;
    if (queue == null || upload == null) return;
    final pending = queue.pending(eventId);
    if (pending == null) return;
    try {
      await upload(eventId: eventId, photo: pending);
      await queue.clear(eventId);
    } catch (_) {
      // Transient — next tick retries.
    }
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
    await drainPendingPhoto(eventId);
  }
}
