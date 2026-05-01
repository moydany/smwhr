import 'dart:async';

import 'package:dio/dio.dart';

import '../../features/quest/services/quest_reminder.dart';
import '../local/event_cache.dart';
import '../models/event.dart';
import '../models/event_category.dart';
import '../repositories/events_repository.dart';
import 'api_client.dart';
import 'mappers.dart';

/// Backend [GET /events] returns `{items, total, limit, offset}`. We
/// project to `List<Event>` for the mobile contract.
///
/// `getEventBy*` and `setIntent` write through to [EventCache] so the
/// dual-track quest can boot offline at the venue (no network → fall
/// back to the cache → still get the polygon for `Locus.addPolygon`).
class RealEventsRepository implements EventsRepository {
  RealEventsRepository(
    this._api, {
    required EventCache cache,
    required QuestReminderService reminders,
  })  : _cache = cache,
        _reminders = reminders;

  final ApiClient _api;
  final EventCache _cache;
  final QuestReminderService _reminders;

  @override
  Future<List<Event>> listEvents({
    EventCategory? category,
    String? city,
    int limit = 30,
    int offset = 0,
  }) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/events',
      queryParameters: {
        if (category != null) 'category': category.slug,
        if (city != null && city.isNotEmpty) 'city': city,
        'limit': limit,
        'offset': offset,
      },
    );
    return _items(res.data!);
  }

  @override
  Future<List<Event>> listFeatured() async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/events',
      queryParameters: {'featured': true, 'limit': 30},
    );
    return _items(res.data!);
  }

  @override
  Future<Event?> getEventBySlug(String slug) async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/events/$slug');
      final event = eventFromJson(res.data!);
      await _cache.save(event);
      return event;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      // Network / server error → try the cache so we degrade gracefully.
      // We can't look up by slug in the cache without scanning, so we skip
      // the offline fallback here; the by-id path below handles the
      // common case (active quest reads via `getEventById`).
      rethrow;
    }
  }

  @override
  Future<Event?> getEventById(String id) async {
    try {
      final res =
          await _api.dio.get<Map<String, dynamic>>('/events/by-id/$id');
      final event = eventFromJson(res.data!);
      await _cache.save(event);
      return event;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      // Offline / server unreachable → return whatever the cache has.
      // QuestTracker.startQuest needs the polygon and that's exactly
      // what we cached on the most recent successful read.
      final cached = await _cache.get(id);
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<Event> setIntent(String eventId) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/events/$eventId/intent',
    );
    final event = eventFromJson(res.data!);
    // Pin the event in the cache as soon as the user commits — this is
    // the canonical "user intends to verify this event" signal.
    await _cache.save(event);
    // Wake the user up the moment the event goes live. Tap → app opens
    // → AutoStartLiveQuestsService engages the tracker. Errors here
    // are non-fatal: notifications are nice-to-have, not the gate.
    try {
      await _reminders.schedule(
        eventId: event.id,
        eventTitle: event.title,
        startsAt: event.startsAt,
      );
    } catch (_) {/* swallow — RSVP itself succeeded */}
    return event;
  }

  @override
  Future<Event> removeIntent(String eventId) async {
    final res = await _api.dio.delete<Map<String, dynamic>>(
      '/events/$eventId/intent',
    );
    await _cache.clear(eventId);
    try {
      await _reminders.cancel(eventId);
    } catch (_) {/* swallow */}
    return eventFromJson(res.data!);
  }

  @override
  Future<bool> hasIntent(String eventId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/events/$eventId/intent',
    );
    return res.data?['has'] == true;
  }

  /// R0.1 fallback: poll `/events/by-id/:id` every 30s and emit the
  /// `intentCount`. Replaceable with a Supabase realtime channel post-launch
  /// without changing the mobile call sites.
  @override
  Stream<int> watchIntentCount(String eventId) async* {
    Event? last;
    while (true) {
      try {
        final r = await _api.dio.get<Map<String, dynamic>>(
          '/events/by-id/$eventId',
        );
        final ev = eventFromJson(r.data!);
        if (last == null || ev.intentCount != last.intentCount) {
          yield ev.intentCount;
          last = ev;
        }
      } catch (_) {
        // swallow transient failures; next tick will retry
      }
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }

  List<Event> _items(Map<String, dynamic> body) {
    final items = body['items'] as List? ?? const [];
    return items
        .map((e) => eventFromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
