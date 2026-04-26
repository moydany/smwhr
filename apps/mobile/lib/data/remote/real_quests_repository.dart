import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../features/quest/services/quest_tracker.dart';
import '../models/photo_upload.dart';
import '../models/quest.dart';
import '../repositories/quests_repository.dart';
import 'api_client.dart';
import 'mappers.dart';
import 'quest_payloads.dart';

/// Backend-facing implementation of [QuestsRepository].
///
/// HTTP calls (status / sync / photo / integrity) are owned here. The
/// on-device tracker lifecycle (start/stop + Hive logging + periodic
/// sync) is owned by [QuestTracker]; we delegate to it so the screen
/// keeps calling `repo.startQuest(eventId)` without knowing whether
/// we're in mock or real mode.
class RealQuestsRepository implements QuestsRepository {
  RealQuestsRepository(this._api, {required this.questTracker});

  final ApiClient _api;
  final QuestTracker questTracker;

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
  Future<void> startQuest(String eventId) => questTracker.startQuest(eventId);

  @override
  Future<void> stopQuest(String eventId) => questTracker.stopQuest(eventId);

  @override
  Future<PhotoUploadResult> uploadPhoto({
    required String eventId,
    required File photo,
    PhotoMetadata? metadata,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(photo.path),
      if (metadata?.exifTimestamp != null)
        'exifTimestamp': metadata!.exifTimestamp!.toIso8601String(),
      if (metadata?.exifLatitude != null)
        'exifLatitude': metadata!.exifLatitude!.toString(),
      if (metadata?.exifLongitude != null)
        'exifLongitude': metadata!.exifLongitude!.toString(),
      if (metadata?.exifRaw != null && metadata!.exifRaw!.isNotEmpty)
        // Backend's UploadPhotoDto expects exifRaw as JSON string in the
        // multipart body (it's then parsed server-side into Json).
        'exifRaw': jsonEncode(metadata.exifRaw),
    });
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/quests/$eventId/photo',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    return PhotoUploadResult.fromJson(res.data!);
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
        'locusEvents': locusEvents.map(locusEventToJson).toList(),
        'geolocatorPings': geolocatorPings.map(geolocatorPingToJson).toList(),
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
}
