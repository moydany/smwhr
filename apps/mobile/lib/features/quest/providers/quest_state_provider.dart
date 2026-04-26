import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/event.dart';
import '../../../data/models/quest.dart';
import '../../../data/providers.dart';

/// Backend-sourced quest status for [eventId]. Polls every 5s in real
/// mode (see `RealQuestsRepository.watchQuestStatus`); the mock impl
/// emits whenever its in-memory state changes.
///
/// The active screen subscribes to this; a future enhancement
/// (locked decision: post-soft-launch) will additionally derive
/// `dwellMinutes` locally from the most-recent geofence-dwell event in
/// `TrackingDb` so the UI bumps faster than the backend's 30-min sync
/// cadence. For R0.1 the backend is the single source of truth.
final questStatusProvider =
    StreamProvider.autoDispose.family<QuestStatus, String>((ref, eventId) {
  final repo = ref.watch(questsRepositoryProvider);
  return repo.watchQuestStatus(eventId);
});

/// Hydrates the [Event] for the active quest screen so we can show the
/// venue header + drive the dwell threshold from `dwellMinimumMin`.
final questEventProvider =
    FutureProvider.autoDispose.family<Event?, String>((ref, eventId) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getEventById(eventId);
});
