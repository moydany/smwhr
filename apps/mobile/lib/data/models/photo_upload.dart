/// EXIF metadata extracted from a captured photo, sent to the backend
/// alongside the multipart file. Each field is optional — the backend
/// derives `isExifValid` from the combination of timestamp + lat + lng,
/// and tolerates a fully-empty payload (the verdict will just be
/// negative, not an error).
class PhotoMetadata {
  /// `DateTimeOriginal` from the photo's EXIF block. Backend compares
  /// against the event's [start − 30 min, end + 30 min] window for the
  /// `isWithinTimeWindow` check.
  final DateTime? exifTimestamp;

  /// EXIF GPS latitude in degrees, signed (south negative). Backend
  /// runs PostGIS `ST_Contains` against the event polygon for
  /// `isInsideGeofence`.
  final double? exifLatitude;

  /// EXIF GPS longitude in degrees, signed (west negative).
  final double? exifLongitude;

  /// Full EXIF tag dump for forensics. Stored as JSON on the backend
  /// (`Photo.exifRaw`); used post-launch when we add anti-spoofing
  /// heuristics (camera model, software, edit history, etc.).
  final Map<String, Object>? exifRaw;

  const PhotoMetadata({
    this.exifTimestamp,
    this.exifLatitude,
    this.exifLongitude,
    this.exifRaw,
  });

  /// True if at least one field is set — i.e. there's something worth
  /// sending. An empty payload still goes through (so the backend can
  /// record "no EXIF" for forensic purposes), but the camera screen
  /// uses this to decide whether to skip the form-field encoding.
  bool get hasAny =>
      exifTimestamp != null ||
      exifLatitude != null ||
      exifLongitude != null ||
      (exifRaw?.isNotEmpty ?? false);
}

/// Backend response from `POST /quests/:id/photo`. Mirrors the JSON
/// returned by `QuestsService.uploadPhoto`. The reveal screen surfaces
/// failed verifications as soft warnings — the photo still uploads,
/// the user still gets to the reveal, but the badge issued downstream
/// will have a lower verification score.
class PhotoUploadResult {
  final String photoId;
  final bool isExifValid;
  final bool isWithinTimeWindow;
  final bool isInsideGeofence;

  /// True when this upload was NOT the first photo for the event —
  /// the badge already anchored to a previous photo, so this one is
  /// part of the user's record of the moment without changing
  /// verification. The camera screen uses this to skip the reveal
  /// flow on subsequent captures.
  final bool isAdditionalPhoto;

  const PhotoUploadResult({
    required this.photoId,
    required this.isExifValid,
    required this.isWithinTimeWindow,
    required this.isInsideGeofence,
    this.isAdditionalPhoto = false,
  });

  /// All three checks passed. The badge issued at finalize-time will
  /// max out the photo-derived components of the verification score.
  bool get isFullyVerified =>
      isExifValid && isWithinTimeWindow && isInsideGeofence;

  /// `true` if any of the three checks failed. Used by the camera screen
  /// to decide whether to render a soft-warning banner before pushing
  /// to the reveal.
  bool get hasWarning => !isFullyVerified;

  factory PhotoUploadResult.fromJson(Map<String, dynamic> json) {
    return PhotoUploadResult(
      photoId: json['photoId'] as String,
      isExifValid: json['isExifValid'] as bool? ?? false,
      isWithinTimeWindow: json['isWithinTimeWindow'] as bool? ?? false,
      isInsideGeofence: json['isInsideGeofence'] as bool? ?? false,
      isAdditionalPhoto: json['isAdditionalPhoto'] as bool? ?? false,
    );
  }
}
