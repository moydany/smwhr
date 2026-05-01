import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/event.dart';
import '../remote/mappers.dart';

/// On-device cache of events the user has interacted with — primarily
/// the one with an active intent ("I'll be there") so the dual-track
/// quest can start at the venue even when the network is dead.
///
/// Storage: a single Hive box `events_cache` keyed by event id, each
/// value a `Map<String, dynamic>` mirroring the backend JSON shape.
/// Reusing the wire format means [eventFromJson] is the single source
/// of parsing logic — no second model to keep in sync.
///
/// We don't bother evicting on quota; events are tiny (~1 KB each) and
/// the app at most caches a few dozen across a user's lifetime.
class EventCache {
  static const String _boxName = 'events_cache';

  Box<dynamic>? _box;

  Future<Box<dynamic>> _open() async {
    return _box ??= await Hive.openBox(_boxName);
  }

  Future<void> save(Event event) async {
    final box = await _open();
    // Serialise as a JSON string. If we stored the raw Map, Hive would
    // reload nested objects as `Map<dynamic, dynamic>` after a cold
    // restart and the `badgeTemplate as Map<String, dynamic>?` cast in
    // `eventFromJson` would explode.
    await box.put(event.id, jsonEncode(eventToCacheJson(event)));
  }

  Future<Event?> get(String eventId) async {
    final box = await _open();
    final raw = box.get(eventId);
    if (raw is! String) return null;
    return eventFromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Scan the cache for an event with the given slug. O(n) over
  /// cached entries — fine at our scale (≤ a few dozen per user) and
  /// avoids maintaining a parallel slug→id index. Used by the offline
  /// fallback in `RealEventsRepository.getEventBySlug` so the event
  /// detail screen still loads when the venue has no network.
  Future<Event?> getBySlug(String slug) async {
    final box = await _open();
    for (final raw in box.values) {
      if (raw is! String) continue;
      try {
        final event = eventFromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (event.slug == slug) return event;
      } catch (_) {/* corrupt row, skip */}
    }
    return null;
  }

  /// All cached events. Used by the auto-start service when the
  /// `/me/quests` lookup fails — we scan local events and engage the
  /// tracker for any that are currently live, so a venue with no
  /// network still gets a quest started.
  Future<List<Event>> all() async {
    final box = await _open();
    final out = <Event>[];
    for (final raw in box.values) {
      if (raw is! String) continue;
      try {
        out.add(eventFromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {/* corrupt row, skip */}
    }
    return out;
  }

  Future<void> clear(String eventId) async {
    final box = await _open();
    await box.delete(eventId);
  }

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
