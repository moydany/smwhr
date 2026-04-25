import 'dart:async';

import 'package:dio/dio.dart';

import '../models/event.dart';
import '../models/event_category.dart';
import '../repositories/events_repository.dart';
import 'api_client.dart';
import 'mappers.dart';

/// Backend [GET /events] returns `{items, total, limit, offset}`. We
/// project to `List<Event>` for the mobile contract.
class RealEventsRepository implements EventsRepository {
  RealEventsRepository(this._api);

  final ApiClient _api;

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
      return eventFromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Event?> getEventById(String id) async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/events/by-id/$id');
      return eventFromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Event> setIntent(String eventId) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/events/$eventId/intent',
    );
    return eventFromJson(res.data!);
  }

  @override
  Future<Event> removeIntent(String eventId) async {
    final res = await _api.dio.delete<Map<String, dynamic>>(
      '/events/$eventId/intent',
    );
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
