import 'package:hive_flutter/hive_flutter.dart';

import '../../models/quest.dart';

/// Hive TypeAdapter for [GeolocatorPing].
///
/// **typeId allocation (do not reuse / shuffle):**
///   1 — LocusEvent          (see locus_event_adapter.dart)
///   2 — GeolocatorPing      ← this adapter
///   3-9 — reserved for future tracker additions
class GeolocatorPingAdapter extends TypeAdapter<GeolocatorPing> {
  @override
  final int typeId = 2;

  @override
  GeolocatorPing read(BinaryReader reader) {
    final id = reader.readString();
    final eventId = reader.readString();
    final timestampMs = reader.readInt();
    final lat = reader.readDouble();
    final lng = reader.readDouble();
    final acc = reader.readDouble();
    final isInside = reader.readBool();
    return GeolocatorPing(
      id: id,
      eventId: eventId,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true),
      latitude: lat,
      longitude: lng,
      accuracy: acc,
      isInsidePolygon: isInside,
    );
  }

  @override
  void write(BinaryWriter writer, GeolocatorPing obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.eventId);
    writer.writeInt(obj.timestamp.toUtc().millisecondsSinceEpoch);
    writer.writeDouble(obj.latitude);
    writer.writeDouble(obj.longitude);
    writer.writeDouble(obj.accuracy);
    writer.writeBool(obj.isInsidePolygon);
  }
}
