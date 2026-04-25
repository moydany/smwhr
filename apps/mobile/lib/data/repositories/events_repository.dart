import '../models/event.dart';
import '../models/event_category.dart';

abstract class EventsRepository {
  /// Paginated catalogue. `category == null` means all.
  Future<List<Event>> listEvents({
    EventCategory? category,
    String? city,
    int limit = 30,
    int offset = 0,
  });

  Future<Event?> getEventBySlug(String slug);
  Future<Event?> getEventById(String id);

  Future<List<Event>> listFeatured();

  Future<Event> setIntent(String eventId);
  Future<Event> removeIntent(String eventId);
  Future<bool> hasIntent(String eventId);

  /// Stream of intent counts for an event (useful when you have a
  /// long-lived event detail screen).
  Stream<int> watchIntentCount(String eventId);
}
