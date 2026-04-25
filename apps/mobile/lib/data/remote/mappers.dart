import '../models/badge.dart';
import '../models/event.dart';
import '../models/event_category.dart';
import '../models/quest.dart';
import '../models/user.dart';

/// Maps the backend /me + /users/:handle JSON shape to the Dart [User].
///
/// Backend fields the mobile doesn't surface yet (avatarUrl, lastActiveAt,
/// pushToken, etc.) are read where present and otherwise defaulted.
User userFromJson(Map<String, dynamic> json) {
  return User(
    id: json['id'] as String,
    handle: json['handle'] as String? ?? '',
    displayName: (json['displayName'] as String?) ?? '',
    email: json['email'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    bio: json['bio'] as String?,
    city: (json['city'] as String?) ?? '',
    countryCode: (json['countryCode'] as String?) ?? 'MX',
    interests: ((json['interests'] as List?) ?? const [])
        .map((e) => e as String)
        .toList(growable: false),
    language: (json['language'] as String?) ?? 'es',
    onboardingCompletedAt: _date(json['onboardingCompletedAt']),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    questsCount: (json['questsCount'] as int?) ?? 0,
    venuesCount: (json['venuesCount'] as int?) ?? 0,
    artistsCount: (json['artistsCount'] as int?) ?? 0,
  );
}

/// Used by AuthTokenStore for offline cache. Mirrors userFromJson reads.
Map<String, dynamic> userToJson(User u) => {
      'id': u.id,
      'handle': u.handle,
      'displayName': u.displayName,
      'email': u.email,
      'avatarUrl': u.avatarUrl,
      'bio': u.bio,
      'city': u.city,
      'countryCode': u.countryCode,
      'interests': u.interests,
      'language': u.language,
      'onboardingCompletedAt': u.onboardingCompletedAt?.toIso8601String(),
      'createdAt': u.createdAt.toIso8601String(),
      'questsCount': u.questsCount,
      'venuesCount': u.venuesCount,
      'artistsCount': u.artistsCount,
    };

/// Maps the backend Event JSON (incl. embedded badgeTemplate) to the
/// Dart [Event]. Several mobile fields don't have a 1:1 backend column
/// (geofencePolygon, ticketmasterUrl, promoterName) — reasonable
/// defaults until we surface them.
Event eventFromJson(Map<String, dynamic> json) {
  final categorySlug = json['category'] as String? ?? 'music';
  final template = json['badgeTemplate'] as Map<String, dynamic>?;
  return Event(
    id: json['id'] as String,
    slug: json['slug'] as String,
    title: json['title'] as String,
    artistName: json['artist'] as String?,
    venueName: (json['venueName'] as String?) ?? '',
    city: (json['city'] as String?) ?? '',
    countryCode: (json['countryCode'] as String?) ?? 'MX',
    startsAt: _date(json['startsAt']) ?? DateTime.now(),
    endsAt: _date(json['endsAt']),
    posterUrl: json['heroImageUrl'] as String?,
    heroImageUrl: json['heroImageUrl'] as String?,
    description: (json['description'] as String?) ?? '',
    category: EventCategory.fromSlug(categorySlug) ?? EventCategory.music,
    geofencePolygon: const [],
    dwellMinimumMin: (json['dwellMinimumMin'] as int?) ?? 30,
    ticketmasterUrl:
        (json['externalSource'] as String?) == 'ticketmaster'
            ? json['externalUrl'] as String?
            : null,
    promoterName: null,
    intentCount: (json['intentCount'] as int?) ?? 0,
    verifiedAttendeeCount: (json['badgeCount'] as int?) ?? 0,
    isFeatured: (json['isFeatured'] as bool?) ?? false,
    badgeFrameUrl: template?['frameSvgUrl'] as String?,
  );
}

/// Maps the backend Badge JSON (with embedded event + template) to the
/// Dart [Badge]. The backend returns verificationScore as int 0-100; the
/// mobile model uses double 0..1.
Badge badgeFromJson(Map<String, dynamic> json) {
  final event = json['event'] as Map<String, dynamic>?;
  final template = json['template'] as Map<String, dynamic>?;
  final scoreRaw = json['verificationScore'];
  final score = scoreRaw is num ? scoreRaw.toDouble() / 100.0 : 0.0;
  final eventCategory = EventCategory.fromSlug(
        (event?['category'] as String?) ?? 'music',
      ) ??
      EventCategory.music;
  return Badge(
    id: json['id'] as String,
    eventId: json['eventId'] as String,
    userId: json['userId'] as String,
    eventTitle: (event?['title'] as String?) ?? '',
    artistName: event?['artist'] as String?,
    venueName: (event?['venueName'] as String?) ?? '',
    city: (event?['city'] as String?) ?? '',
    countryCode: (event?['countryCode'] as String?) ?? 'MX',
    eventDate: _date(event?['startsAt']) ?? DateTime.now(),
    category: eventCategory,
    capturedPhotoUrl: null,
    composedBadgeUrl: json['composedImageUrl'] as String?,
    frameUrl: (template?['frameSvgUrl'] as String?) ?? '',
    serial: (json['serialNumber'] as int?) ?? 0,
    totalIssued: json['totalForEvent'] as int?,
    verificationScore: score,
    issuedAt: _date(json['awardedAt']) ?? DateTime.now(),
  );
}

/// Maps the backend GET /quests/:eventId/status response to the mobile
/// [QuestStatus]. The mobile model's `isActive` and four [QuestChecks]
/// flags are derived from the backend's phase + checkin since the
/// backend doesn't track per-tracker state.
QuestStatus questStatusFromJson(Map<String, dynamic> json) {
  final eventId = json['eventId'] as String;
  final phase = json['phase'] as String? ?? 'pre';
  final checkin = json['checkin'] as Map<String, dynamic>?;
  final pointsCollected = (json['pointsCollected'] as int?) ?? 0;
  final dwellMinutes = (checkin?['dwellMinutes'] as int?) ?? 0;
  final hasIntegrity = checkin?['integrityVerdict'] != null;

  return QuestStatus(
    eventId: eventId,
    isActive: phase == 'during',
    dwellMinutes: dwellMinutes,
    checks: QuestChecks(
      gpsVerified: pointsCollected > 0,
      deviceTrusted: hasIntegrity,
      integrityActive: hasIntegrity,
      photoCapture: checkin?['photoId'] != null,
    ),
    startedAt: _date(checkin?['firstPointAt']),
  );
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  if (v is String) {
    return DateTime.tryParse(v);
  }
  return null;
}
