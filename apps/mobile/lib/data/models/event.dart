import 'event_category.dart';
import 'lat_lng.dart';

/// Domain model for a smwhr event.
///
/// Mirrors `GET /events/:slug`. The geofence polygon is the closed loop
/// of LatLng vertices used for tracker setup (`Locus.addGeofence`) and the
/// Reconciliation Engine's dwell calculation.
class Event {
  final String id;
  final String slug;
  final String title;
  final String? artistName;
  final String venueName;
  final String city;
  final String countryCode;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? posterUrl;
  final String? heroImageUrl;
  final String description;
  final EventCategory category;
  final List<LatLng> geofencePolygon;
  final int dwellMinimumMin;
  final String? ticketmasterUrl;
  final String? promoterName;
  final int intentCount;
  final int verifiedAttendeeCount;
  final bool isFeatured;
  final String? badgeFrameUrl;

  const Event({
    required this.id,
    required this.slug,
    required this.title,
    this.artistName,
    required this.venueName,
    required this.city,
    required this.countryCode,
    required this.startsAt,
    this.endsAt,
    this.posterUrl,
    this.heroImageUrl,
    required this.description,
    required this.category,
    required this.geofencePolygon,
    this.dwellMinimumMin = 30,
    this.ticketmasterUrl,
    this.promoterName,
    this.intentCount = 0,
    this.verifiedAttendeeCount = 0,
    this.isFeatured = false,
    this.badgeFrameUrl,
  });

  Duration get timeUntilStart => startsAt.difference(DateTime.now());

  bool get isUpcoming => DateTime.now().isBefore(startsAt);

  bool get isLive {
    final now = DateTime.now();
    final end = endsAt ?? startsAt.add(const Duration(hours: 4));
    return now.isAfter(startsAt) && now.isBefore(end);
  }

  bool get isPast {
    final end = endsAt ?? startsAt.add(const Duration(hours: 4));
    return DateTime.now().isAfter(end);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Event && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Intent ("I'll be there") record.
class Intent {
  final String id;
  final String eventId;
  final String userId;
  final DateTime createdAt;

  const Intent({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.createdAt,
  });
}
