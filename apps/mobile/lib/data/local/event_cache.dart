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

  Future<void> clear(String eventId) async {
    final box = await _open();
    await box.delete(eventId);
  }

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
