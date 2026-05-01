import 'package:hive_flutter/hive_flutter.dart';

import '../models/photo_upload.dart';

/// On-device queue of photo captures waiting for a successful upload.
///
/// Schema constraint: at most one Photo row per `(userId, eventId)` on
/// the backend, so we only ever queue one photo per event here too. A
/// second capture for the same event overwrites the first — the user
/// re-took it before we got a chance to ship the original.
///
/// Storage: a single Hive box `pending_photos` keyed by eventId. Each
/// value is a [PendingPhoto] (file path + EXIF metadata + capture
/// time). The actual JPEG lives on disk under the per-event camera dir
/// (`<docs>/camera/<eventId>/...`); the queue only stores the path.
///
/// Lifecycle:
///   1. Camera screen captures → `enqueue(...)` writes the entry.
///   2. Camera screen tries an immediate upload via the repo. On
///      success → `clear(eventId)`. On failure → leave queued.
///   3. `TrackingSync` ticks call `drain(eventId, uploader)` to retry.
///   4. `buildLocalQuestStatus` reads `pending(eventId)` to light up
///      the photo task in the UI even before the upload lands.
class PhotoQueue {
  PhotoQueue._(this._box);

  static const String boxName = 'pending_photos';

  final Box<dynamic> _box;

  /// Opens (or reuses) the Hive box. Cheap to call multiple times —
  /// `Hive.openBox` is idempotent for already-open boxes.
  static Future<PhotoQueue> open() async {
    final box = await Hive.openBox<dynamic>(boxName);
    return PhotoQueue._(box);
  }

  Future<void> close() async => _box.close();

  Future<void> enqueue(String eventId, PendingPhoto photo) async {
    await _box.put(eventId, photo.toJson());
  }

  Future<void> clear(String eventId) async {
    await _box.delete(eventId);
  }

  PendingPhoto? pending(String eventId) {
    final raw = _box.get(eventId);
    if (raw is Map) {
      try {
        return PendingPhoto.fromJson(raw.cast<String, dynamic>());
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Every event id that currently has a queued photo. Used by the
  /// boot drainer + diagnostics screens.
  List<String> pendingEventIds() {
    return _box.keys.cast<String>().toList(growable: false);
  }
}

/// A photo waiting for a successful upload. The `filePath` points at a
/// JPEG written by the camera screen under the per-event scratch dir.
/// EXIF metadata is captured at the same moment so a delayed upload
/// still ships the original timestamp + GPS to the verifier.
class PendingPhoto {
  final String filePath;
  final DateTime capturedAt;
  final PhotoMetadata metadata;

  const PendingPhoto({
    required this.filePath,
    required this.capturedAt,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'capturedAt': capturedAt.toIso8601String(),
        'exifTimestamp': metadata.exifTimestamp?.toIso8601String(),
        'exifLatitude': metadata.exifLatitude,
        'exifLongitude': metadata.exifLongitude,
      };

  factory PendingPhoto.fromJson(Map<String, dynamic> json) {
    return PendingPhoto(
      filePath: json['filePath'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      metadata: PhotoMetadata(
        exifTimestamp: json['exifTimestamp'] is String
            ? DateTime.tryParse(json['exifTimestamp'] as String)
            : null,
        exifLatitude: (json['exifLatitude'] as num?)?.toDouble(),
        exifLongitude: (json['exifLongitude'] as num?)?.toDouble(),
      ),
    );
  }
}
