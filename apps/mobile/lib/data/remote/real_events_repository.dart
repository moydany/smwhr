// ignore_for_file: unused_field
import '../models/event.dart';
import '../models/event_category.dart';
import '../repositories/events_repository.dart';
import 'api_client.dart';

class RealEventsRepository implements EventsRepository {
  RealEventsRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Event>> listEvents({
    EventCategory? category,
    String? city,
    int limit = 30,
    int offset = 0,
  }) =>
      throw UnimplementedError(
        'GET /events?category=${category?.slug ?? ''}&city=${city ?? ''}'
        '&limit=$limit&offset=$offset — Phase 2.',
      );

  @override
  Future<List<Event>> listFeatured() =>
      throw UnimplementedError('GET /events?featured=true — Phase 2.');

  @override
  Future<Event?> getEventBySlug(String slug) =>
      throw UnimplementedError('GET /events/$slug — Phase 2.');

  @override
  Future<Event?> getEventById(String id) =>
      throw UnimplementedError(
        'GET /events?id=$id — Phase 2 (or by-slug lookup).',
      );

  @override
  Future<Event> setIntent(String eventId) =>
      throw UnimplementedError('POST /events/$eventId/intent — Phase 2.');

  @override
  Future<Event> removeIntent(String eventId) =>
      throw UnimplementedError(
        'DELETE /events/$eventId/intent — Phase 2.',
      );

  @override
  Future<bool> hasIntent(String eventId) =>
      throw UnimplementedError(
        'GET /events/$eventId/intent — Phase 2.',
      );

  @override
  Stream<int> watchIntentCount(String eventId) =>
      Stream.error(UnimplementedError(
        'WS /events/$eventId/intents — Phase 2 (Supabase realtime or '
        'long-poll fallback).',
      ));
}
