/// Minimal value class for geographic coordinates.
///
/// Pinned here (instead of importing one from `geolocator` / `locus`) so
/// domain models stay free of plugin types — the plugins map to/from this
/// at the boundary.
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          other.latitude == latitude &&
          other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}
