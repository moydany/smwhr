import 'dart:io';

import '../models/photo_upload.dart';
import '../models/quest.dart';

abstract class QuestsRepository {
  Future<QuestStatus> getQuestStatus(String eventId);
  Stream<QuestStatus> watchQuestStatus(String eventId);

  /// Boots the active quest. In real mode this initialises Locus +
  /// Geolocator + Hive logging. In mock mode it just spins the timer.
  Future<void> startQuest(String eventId);
  Future<void> stopQuest(String eventId);

  /// Upload the captured photo + optional EXIF metadata. Returns the
  /// backend's verification verdict (per-check booleans + photo id).
  /// The reveal screen renders a soft warning if any check fails — the
  /// upload itself still succeeds and the badge gets issued at
  /// finalize-time, just with a lower score.
  Future<PhotoUploadResult> uploadPhoto({
    required String eventId,
    required File photo,
    PhotoMetadata? metadata,
  });

  /// Forward a tracking batch to the backend. No-op in mock mode.
  Future<void> syncTrackingBatch({
    required String eventId,
    required List<LocusEvent> locusEvents,
    required List<GeolocatorPing> geolocatorPings,
  });

  /// Optional integrity ping (Play Integrity / DeviceCheck attestation).
  Future<void> attestIntegrity(String eventId, String token);

  /// Force-finalize the checkin and (if the verifier passes) mint the
  /// badge. Production path is the `closeEndedEvents` cron 1h after
  /// the event ends; the mobile calls this directly after a photo
  /// capture so the user lands on `/reveal/<realBadgeId>` instead of
  /// a stub. Returns the badge id, or null when the verifier rejects
  /// (score below threshold) — caller should fall back to a "your
  /// badge will be issued after the event" UX.
  Future<String?> finalizeQuest(String eventId);
}
