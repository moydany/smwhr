import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../models/quest.dart';

/// Hive TypeAdapter for [LocusEvent].
///
/// **typeId allocation (do not reuse / shuffle):**
///   1 — LocusEvent          ← this adapter
///   2 — GeolocatorPing      (see geolocator_ping_adapter.dart)
///   3-9 — reserved for future tracker additions
///
/// `LocusEventType` is persisted as its `index` (an int). Reordering the
/// enum cases would corrupt previously-stored rows — append-only.
///
/// `raw` (`Map<String, dynamic>`) is serialised as a JSON string so we don't
/// have to register adapters for every plugin payload shape.
class LocusEventAdapter extends TypeAdapter<LocusEvent> {
  @override
  final int typeId = 1;

  @override
  LocusEvent read(BinaryReader reader) {
    final id = reader.readString();
    final eventId = reader.readString();
    final typeIndex = reader.readByte();
    final timestampMs = reader.readInt();
    final hasLat = reader.readBool();
    final lat = hasLat ? reader.readDouble() : null;
    final hasLng = reader.readBool();
    final lng = hasLng ? reader.readDouble() : null;
    final hasAcc = reader.readBool();
    final acc = hasAcc ? reader.readDouble() : null;
    final rawJson = reader.readString();
    final raw = rawJson.isEmpty
        ? const <String, dynamic>{}
        : (jsonDecode(rawJson) as Map<String, dynamic>);

    final type = typeIndex < LocusEventType.values.length
        ? LocusEventType.values[typeIndex]
        : LocusEventType.locationUpdate;

    return LocusEvent(
      id: id,
      eventId: eventId,
      type: type,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true),
      latitude: lat,
      longitude: lng,
      accuracy: acc,
      raw: raw,
    );
  }

  @override
  void write(BinaryWriter writer, LocusEvent obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.eventId);
    writer.writeByte(obj.type.index);
    writer.writeInt(obj.timestamp.toUtc().millisecondsSinceEpoch);
    writer.writeBool(obj.latitude != null);
    if (obj.latitude != null) writer.writeDouble(obj.latitude!);
    writer.writeBool(obj.longitude != null);
    if (obj.longitude != null) writer.writeDouble(obj.longitude!);
    writer.writeBool(obj.accuracy != null);
    if (obj.accuracy != null) writer.writeDouble(obj.accuracy!);
    writer.writeString(obj.raw.isEmpty ? '' : jsonEncode(obj.raw));
  }
}
