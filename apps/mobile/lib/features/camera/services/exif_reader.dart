import 'dart:io';

import 'package:native_exif/native_exif.dart';

import '../../../data/models/photo_upload.dart';

/// Reads EXIF metadata from a captured photo and packages it as a
/// [PhotoMetadata] for the backend.
///
/// Failure modes (file missing / no EXIF block / corrupt tags / native
/// channel error) all collapse to a [PhotoMetadata] with whatever
/// fields we *could* read — typically `null` everywhere. We never
/// throw; the upload still goes through, the backend just records a
/// negative `isExifValid` verdict.
class ExifReader {
  const ExifReader();

  Future<PhotoMetadata> read(File file) async {
    if (!file.existsSync()) {
      return const PhotoMetadata();
    }

    Exif? exif;
    try {
      exif = await Exif.fromPath(file.path);
      // Read in parallel — three independent native channel hops.
      final results = await Future.wait([
        exif.getOriginalDate(),
        exif.getLatLong(),
        exif.getAttributes(),
      ]);
      final timestamp = results[0] as DateTime?;
      final latLong = results[1] as ExifLatLong?;
      final raw = results[2] as Map<String, Object>?;
      return PhotoMetadata(
        exifTimestamp: timestamp?.toUtc(),
        exifLatitude: latLong?.latitude,
        exifLongitude: latLong?.longitude,
        exifRaw: raw,
      );
    } catch (_) {
      return const PhotoMetadata();
    } finally {
      try {
        await exif?.close();
      } catch (_) {/* best-effort */}
    }
  }
}
