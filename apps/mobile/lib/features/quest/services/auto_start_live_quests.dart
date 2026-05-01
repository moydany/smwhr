import '../../../data/local/event_cache.dart';
import '../../../data/models/event.dart';
import '../../../data/models/quest.dart';
import '../../../data/repositories/quests_repository.dart';

/// Boot/resume sweep that starts the tracker for any event the user
/// has intent on AND that's currently live. Without this, the user
/// has to manually navigate to event_detail for every live event to
/// trigger the auto-start hook on that screen — friction the user
/// doesn't want when they're already at the venue with the app in
/// their pocket.
///
/// Two paths in priority order:
///   1. Online — fetch `/me/quests`, pick the first entry whose
///      `status == live`, call `startQuest(eventId)`.
///   2. Offline / backend down — scan the local [EventCache] for
///      events that are live right now (by client clock against
///      cached `startsAt` / `endsAt`) and engage any of them. The
///      tracker is fully local: pings write to Hive regardless of
///      network, so this guarantees GPS recording even when the
///      venue has no signal at boot.
///
/// Idempotent: `QuestTracker.startQuest` short-circuits when the
/// requested eventId already matches its active quest, so re-runs on
/// every foreground are safe.
///
/// Per locked decision #9, only one quest is active at a time. If
/// multiple intents are simultaneously live (rare — overlapping
/// events the user RSVP'd to), we pick the most-recently-started.
class AutoStartLiveQuestsService {
  AutoStartLiveQuestsService({
    required this.repository,
    required this.eventCache,
  });

  final QuestsRepository repository;
  final EventCache eventCache;

  /// Returns the eventId we ended up starting (or that was already
  /// active and matched), or `null` if there was nothing live, no
  /// cached fallback, or the tracker rejected the start.
  Future<String?> run() async {
    final pickId = await _pickLiveEventId();
    if (pickId == null) return null;
    try {
      await repository.startQuest(pickId);
      return pickId;
    } catch (_) {
      // Permission denied, tracker conflict (another quest already
      // active for a different event), event lookup failed, etc.
      // Silent — the user can navigate to event_detail to retry the
      // permission flow with explicit UI.
      return null;
    }
  }

  Future<String?> _pickLiveEventId() async {
    // Online path first — backend is the canonical source of intent
    // state, so when it's reachable we trust it.
    try {
      final entries = await repository.listMyQuests();
      final live = entries
          .where((e) => e.status == MyQuestStatus.live)
          .toList()
        ..sort((a, b) => b.event.startsAt.compareTo(a.event.startsAt));
      if (live.isNotEmpty) return live.first.event.id;
    } catch (_) {
      // Fall through to the offline path. Common at venue arrival
      // when the building's signal is dead.
    }

    // Offline / backend down — scan local cache. The cache holds
    // every event the user has ever opened or RSVP'd to (write-
    // through on `getEventById`, `getEventBySlug`, `setIntent`); for
    // the at-the-venue scenario the relevant event was almost
    // certainly cached when the user set their intent. We can't tell
    // here whether intent is still set on each cached event (would
    // need a separate intent index), so we trust the cache as a
    // best-effort proxy: if a cached event is live right now, kick
    // the tracker on. The backend's `/sync` endpoint enforces intent
    // when uploads finally land, so a tracker started speculatively
    // for a non-RSVP'd event still can't earn a badge.
    final cached = await eventCache.all();
    final liveLocal = cached.where(_isLiveNow).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    if (liveLocal.isNotEmpty) return liveLocal.first.id;
    return null;
  }

  /// Mirrors `Event.isLive` from the model: `now` falls between
  /// `startsAt` and `endsAt` (defaults to startsAt + 4h when
  /// endsAt is missing).
  bool _isLiveNow(Event e) {
    final now = DateTime.now();
    final end = e.endsAt ?? e.startsAt.add(const Duration(hours: 4));
    return now.isAfter(e.startsAt) && now.isBefore(end);
  }
}
