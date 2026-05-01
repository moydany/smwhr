import '../../../data/models/quest.dart';
import '../../../data/repositories/quests_repository.dart';

/// Boot/resume sweep that starts the tracker for any event the user
/// has intent on AND that's currently live. Without this, the user
/// has to manually navigate to event_detail for every live event to
/// trigger the auto-start hook on that screen — friction the user
/// doesn't want when they're already at the venue with the app in
/// their pocket.
///
/// Idempotent: `QuestTracker.startQuest` short-circuits when the
/// requested eventId already matches its active quest, so re-runs on
/// every foreground are safe.
///
/// Per locked decision #9, only one quest is active at a time. If
/// multiple intents are simultaneously live (rare — overlapping
/// events the user RSVP'd to), we pick the first as ordered by the
/// backend's `/me/quests` (sorted by `event.startsAt DESC`, which
/// roughly means "the most-recently-started"). The user can switch
/// by stopping the active one and entering a different event.
class AutoStartLiveQuestsService {
  AutoStartLiveQuestsService({required this.repository});

  final QuestsRepository repository;

  /// Returns the eventId we ended up starting (or that was already
  /// active and matched), or `null` if there was nothing live, the
  /// network/permissions failed, or the tracker rejected the start.
  Future<String?> run() async {
    final List<MyQuestEntry> entries;
    try {
      entries = await repository.listMyQuests();
    } catch (_) {
      // Offline / 5xx / auth lapsed. Next foreground retries.
      return null;
    }
    final live = entries.where((e) => e.status == MyQuestStatus.live).toList()
      ..sort((a, b) => b.event.startsAt.compareTo(a.event.startsAt));
    if (live.isEmpty) return null;

    final pick = live.first;
    try {
      await repository.startQuest(pick.event.id);
      return pick.event.id;
    } catch (_) {
      // Permission denied, tracker conflict (another quest already
      // active for a different event), event lookup failed, etc.
      // Silent — the user can navigate to event_detail to retry the
      // permission flow with explicit UI.
      return null;
    }
  }
}
