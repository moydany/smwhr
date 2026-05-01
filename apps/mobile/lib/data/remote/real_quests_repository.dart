import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../features/quest/services/local_quest_status.dart';
import '../../features/quest/services/quest_tracker.dart';
import '../local/photo_queue.dart';
import '../local/tracking_db.dart';
import '../models/photo_upload.dart';
import '../models/quest.dart';
import '../repositories/events_repository.dart';
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
  RealQuestsRepository(
    this._api, {
    required this.questTracker,
    required this.trackingDb,
    required this.photoQueue,
    required this.eventsRepository,
  });

  final ApiClient _api;
  final QuestTracker questTracker;
  final TrackingDb trackingDb;
  final PhotoQueue photoQueue;
  final EventsRepository eventsRepository;

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
      QuestStatus? next;
      try {
        final res = await _api.dio.get<Map<String, dynamic>>(
          '/quests/$eventId/status',
        );
        next = questStatusFromJson(res.data!);
      } catch (_) {
        // Network is down or backend unreachable. Fall back to a
        // locally-derived status so the active-quest checklist keeps
        // updating from the trackers + photo queue. The mobile model's
        // `tasks` getter falls through to client-side derivation when
        // `serverTasks` is empty, which is exactly what the local
        // builder produces.
        next = await _localStatusOrNull(eventId);
      }
      if (next != null) {
        final pending = photoQueue.pending(eventId);
        if (pending != null) {
          // Force `photoCapture = true` so the active-quest checklist
          // + the model's `tasks` getter render the photo task as
          // captured-but-pending instead of flickering back to "—"
          // between the first server response and the next upload
          // drain tick.
          if (!next.checks.photoCapture) {
            next = next.copyWith(
              checks: next.checks.copyWith(photoCapture: true),
            );
          }
          // Inject a synthetic gallery entry pointing at the local
          // file so the user sees their just-captured photo
          // instantly. The real backend entry replaces it on the
          // next poll after the drainer uploads. We dedupe by
          // checking whether any server photo's capturedAt matches
          // the queued capture time within ~2s.
          final alreadyShipped = next.photos.any((p) =>
              p.capturedAt
                  .difference(pending.capturedAt)
                  .abs() <
              const Duration(seconds: 2));
          if (!alreadyShipped) {
            final synthetic = EventPhoto(
              id: 'pending-${pending.capturedAt.microsecondsSinceEpoch}',
              publicUrl: null,
              localFilePath: pending.filePath,
              capturedAt: pending.capturedAt,
              isInsideGeofence: false,
              isWithinTimeWindow: false,
              isExifValid: false,
            );
            next = next.copyWith(
              photos: [synthetic, ...next.photos],
            );
          }
        }
        yield next;
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  Future<QuestStatus?> _localStatusOrNull(String eventId) async {
    try {
      final event = await eventsRepository.getEventById(eventId);
      if (event == null) return null;
      return await buildLocalQuestStatus(
        eventId: eventId,
        event: event,
        trackingDb: trackingDb,
        photoQueue: photoQueue,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> startQuest(String eventId) async {
    await questTracker.startQuest(eventId);
    // Stub integrity attestation. Real DeviceCheck (iOS) / Play
    // Integrity (Android) tokens land post-launch — for R0.1 the
    // backend records `pending_verification` as the verdict for any
    // non-null token, and the mobile mapper flips
    // `deviceTrusted + integrityActive` true on the active-quest screen.
    // Non-blocking: a failure here doesn't stop the tracker.
    try {
      await attestIntegrity(
        eventId,
        'dev-stub-${Platform.isIOS ? 'ios' : 'android'}',
      );
    } catch (_) {/* swallow — integrity is best-effort in R0.1 */}
  }

  @override
  Future<void> stopQuest(String eventId) => questTracker.stopQuest(eventId);

  @override
  Future<PhotoUploadResult> uploadPhoto({
    required String eventId,
    required File photo,
    PhotoMetadata? metadata,
  }) async {
    final form = FormData.fromMap({
      // Explicit `image/jpeg` content type. Without this Dio falls back
      // on `lookupMediaType(filename)` and — in some Flutter/iOS combos
      // — that returns `application/octet-stream`, which the Supabase
      // photos bucket rejects with `mime type ... is not supported`.
      // The backend then re-throws as 502 BAD_GATEWAY (storage.service:
      // STORAGE_UPLOAD_FAILED). Pinning the type kills all guessing.
      'file': await MultipartFile.fromFile(
        photo.path,
        contentType: DioMediaType('image', 'jpeg'),
      ),
      if (metadata?.exifTimestamp != null)
        'exifTimestamp': metadata!.exifTimestamp!.toIso8601String(),
      if (metadata?.exifLatitude != null)
        'exifLatitude': metadata!.exifLatitude!.toString(),
      if (metadata?.exifLongitude != null)
        'exifLongitude': metadata!.exifLongitude!.toString(),
      // exifRaw is omitted intentionally: the backend's
      // UploadPhotoMetadataDto types it as `@IsObject()`, which rejects
      // any string — and multipart can't carry nested JSON natively.
      // The three top-level fields above are what the verifier actually
      // scores; the raw blob is only useful post-launch for forensic
      // anti-spoofing heuristics.
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

  @override
  Future<String?> finalizeQuest(String eventId) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/quests/$eventId/finalize',
    );
    // Backend returns `{ checkin, scoreBreakdown, badgeId }`. badgeId is
    // null when score < threshold (the verifier didn't pass).
    return res.data?['badgeId'] as String?;
  }

  @override
  Future<List<MyQuestEntry>> listMyQuests() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/me/quests');
    final data = res.data ?? const {};
    final list = (data['quests'] as List?) ?? const [];
    return list
        .cast<Map<String, dynamic>>()
        .map(myQuestEntryFromJson)
        .toList(growable: false);
  }
}
