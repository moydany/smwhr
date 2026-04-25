import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/quest.dart';
import '../repositories/quests_repository.dart';
import 'api_client.dart';
import 'mappers.dart';

/// Phase 2 subset — the API-callable methods (status / sync / photo /
/// integrity) are wired; the on-device tracker lifecycle (start/stop +
/// the live status stream that drives `active_quest_screen.dart`) stays
/// stubbed until the Locus + Geolocator + Hive plumbing lands. Today none
/// of the seeded events are inside the active window so this isn't a
/// soft-launch blocker.
class RealQuestsRepository implements QuestsRepository {
  RealQuestsRepository(this._api);

  final ApiClient _api;

  @override
  Future<QuestStatus> getQuestStatus(String eventId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/quests/$eventId/status',
    );
    return questStatusFromJson(res.data!);
  }

  @override
  Stream<QuestStatus> watchQuestStatus(String eventId) async* {
    while (true) {
      try {
        final res = await _api.dio.get<Map<String, dynamic>>(
          '/quests/$eventId/status',
        );
        yield questStatusFromJson(res.data!);
      } catch (_) {
        // swallow transient failures
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  @override
  Future<void> startQuest(String eventId) async {
    // The quest controller (Locus + Geolocator + Hive logging) is a
    // mobile-only orchestrator — there's nothing to call on the backend
    // here. Wired in the dual-track tracker integration session.
    throw UnimplementedError(
      'startQuest($eventId) — Phase 2 dual-track wiring (mobile-only).',
    );
  }

  @override
  Future<void> stopQuest(String eventId) async {
    throw UnimplementedError(
      'stopQuest($eventId) — Phase 2 dual-track teardown.',
    );
  }

  @override
  Future<QuestStatus> uploadPhoto({
    required String eventId,
    required File photo,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(photo.path),
      // EXIF metadata is supplied by the QuestTracker / camera service. The
      // ApiClient call site can extend the FormData when those land.
    });
    await _api.dio.post<Map<String, dynamic>>(
      '/quests/$eventId/photo',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    return getQuestStatus(eventId);
  }

  @override
  Future<void> syncTrackingBatch({
    required String eventId,
    required List<LocusEvent> locusEvents,
    required List<GeolocatorPing> geolocatorPings,
  }) async {
    await _api.dio.post<Map<String, dynamic>>(
      '/quests/$eventId/sync',
      data: {
        'locusEvents': locusEvents.map(_locusToJson).toList(),
        'geolocatorPings': geolocatorPings.map(_pingToJson).toList(),
        'clientTimestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Future<void> attestIntegrity(String eventId, String token) async {
    await _api.dio.post<void>(
      '/quests/$eventId/integrity',
      data: {
        'platform': Platform.isIOS ? 'ios' : 'android',
        'token': token,
        'verifiedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Map<String, dynamic> _locusToJson(LocusEvent e) => {
        'eventType': _locusEventTypeToBackend(e.type),
        'latitude': e.latitude ?? 0,
        'longitude': e.longitude ?? 0,
        if (e.accuracy != null) 'accuracy': e.accuracy,
        'timestamp': e.timestamp.toIso8601String(),
        if (e.raw.isNotEmpty) 'rawPayload': e.raw,
      };

  Map<String, dynamic> _pingToJson(GeolocatorPing p) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracy': p.accuracy,
        'timestamp': p.timestamp.toIso8601String(),
      };

  String _locusEventTypeToBackend(LocusEventType t) => switch (t) {
        LocusEventType.geofenceEnter => 'GEOFENCE_ENTER',
        LocusEventType.geofenceExit => 'GEOFENCE_EXIT',
        LocusEventType.geofenceDwell => 'LOCATION_UPDATE',
        LocusEventType.locationUpdate => 'LOCATION_UPDATE',
        LocusEventType.motionChange => 'MOTION_CHANGE',
        LocusEventType.heartbeat => 'LOCATION_UPDATE',
      };
}
