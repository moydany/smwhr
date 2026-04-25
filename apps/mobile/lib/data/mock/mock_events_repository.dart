import 'dart:async';

import '../models/event.dart';
import '../models/event_category.dart';
import '../repositories/auth_repository.dart';
import '../repositories/events_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_events.dart';
import 'mock_intents.dart';
import 'mock_latency.dart';

class MockEventsRepository implements EventsRepository {
  final MockAuthRepository _auth;

  /// Cache of intents in memory. Hydrated from `mockSeededIntents` and
  /// mutated by setIntent / removeIntent.
  final List<Intent> _intents = [...mockSeededIntents];

  /// Per-event intent count streams (broadcast).
  final Map<String, StreamController<int>> _intentCountControllers = {};

  MockEventsRepository(this._auth);

  String get _currentUserId => switch (_auth.currentState) {
        AuthSignedIn(:final user) => user.id,
        _ => 'user-moi-001',
      };

  @override
  Future<List<Event>> listEvents({
    EventCategory? category,
    String? city,
    int limit = 30,
    int offset = 0,
  }) async {
    await MockLatency.mediumDelay();
    Iterable<Event> filtered = mockEvents;
    if (category != null) {
      filtered = filtered.where((e) => e.category == category);
    }
    if (city != null && city.isNotEmpty) {
      filtered = filtered.where(
        (e) => e.city.toLowerCase() == city.toLowerCase(),
      );
    }
    final sorted = filtered.toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return sorted.skip(offset).take(limit).toList();
  }

  @override
  Future<List<Event>> listFeatured() async {
    await MockLatency.shortDelay();
    return mockEvents.where((e) => e.isFeatured).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  @override
  Future<Event?> getEventBySlug(String slug) async {
    await MockLatency.shortDelay();
    return mockEventsBySlug[slug];
  }

  @override
  Future<Event?> getEventById(String id) async {
    await MockLatency.shortDelay();
    return mockEventsById[id];
  }

  @override
  Future<Event> setIntent(String eventId) async {
    await MockLatency.shortDelay();
    final event = mockEventsById[eventId];
    if (event == null) {
      throw StateError('Unknown event: $eventId');
    }
    final exists = _intents.any(
      (i) => i.eventId == eventId && i.userId == _currentUserId,
    );
    if (!exists) {
      _intents.add(Intent(
        id: 'int-${DateTime.now().millisecondsSinceEpoch}',
        eventId: eventId,
        userId: _currentUserId,
        createdAt: DateTime.now(),
      ));
      _emitIntentCount(eventId);
    }
    return event;
  }

  @override
  Future<Event> removeIntent(String eventId) async {
    await MockLatency.shortDelay();
    final event = mockEventsById[eventId];
    if (event == null) {
      throw StateError('Unknown event: $eventId');
    }
    _intents.removeWhere(
      (i) => i.eventId == eventId && i.userId == _currentUserId,
    );
    _emitIntentCount(eventId);
    return event;
  }

  @override
  Future<bool> hasIntent(String eventId) async {
    return _intents.any(
      (i) => i.eventId == eventId && i.userId == _currentUserId,
    );
  }

  @override
  Stream<int> watchIntentCount(String eventId) {
    final controller = _intentCountControllers.putIfAbsent(
      eventId,
      () => StreamController<int>.broadcast(),
    );
    // Push initial value on listen.
    Future.microtask(() => _emitIntentCount(eventId));
    return controller.stream;
  }

  void _emitIntentCount(String eventId) {
    final controller = _intentCountControllers[eventId];
    if (controller == null || controller.isClosed) return;
    final base = mockEventsById[eventId]?.intentCount ?? 0;
    final delta = _intents
        .where((i) => i.eventId == eventId && i.userId != _currentUserId)
        .length;
    final myIntent = _intents.any(
      (i) => i.eventId == eventId && i.userId == _currentUserId,
    );
    controller.add(base + delta + (myIntent ? 1 : 0));
  }

  void dispose() {
    for (final c in _intentCountControllers.values) {
      c.close();
    }
    _intentCountControllers.clear();
  }
}
