import '../models/badge.dart';
import '../models/event.dart';
import '../models/event_category.dart';
import '../models/lat_lng.dart';
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
/// Dart [Event]. `geofencePolygon` is the GeoJSON outer ring surfaced by
/// `EventsService` (array of `[lng, lat]` pairs). Empty when the event has
/// no polygon — trackers fall back to the radius+center.
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
    geofencePolygon: _polygonFromGeoJson(json['geofencePolygon']),
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

/// Inverse of [eventFromJson] — produces a JSON shape the local
/// [EventCache] can persist and re-hydrate offline. Mirrors the field
/// names the backend would have returned so the same parser works for
/// both sources. Field omissions match `eventFromJson`'s defaults.
Map<String, dynamic> eventToCacheJson(Event event) {
  return {
    'id': event.id,
    'slug': event.slug,
    'title': event.title,
    if (event.artistName != null) 'artist': event.artistName,
    'venueName': event.venueName,
    'city': event.city,
    'countryCode': event.countryCode,
    'startsAt': event.startsAt.toIso8601String(),
    if (event.endsAt != null) 'endsAt': event.endsAt!.toIso8601String(),
    if (event.heroImageUrl != null) 'heroImageUrl': event.heroImageUrl,
    'description': event.description,
    'category': event.category.slug,
    'geofencePolygon':
        event.geofencePolygon.map((p) => [p.longitude, p.latitude]).toList(),
    'dwellMinimumMin': event.dwellMinimumMin,
    if (event.ticketmasterUrl != null) ...{
      'externalSource': 'ticketmaster',
      'externalUrl': event.ticketmasterUrl,
    },
    'intentCount': event.intentCount,
    'badgeCount': event.verifiedAttendeeCount,
    'isFeatured': event.isFeatured,
    if (event.badgeFrameUrl != null)
      'badgeTemplate': {'frameSvgUrl': event.badgeFrameUrl},
  };
}

List<LatLng> _polygonFromGeoJson(Object? raw) {
  if (raw is! List) return const [];
  final out = <LatLng>[];
  for (final coord in raw) {
    if (coord is! List || coord.length < 2) continue;
    final lng = coord[0];
    final lat = coord[1];
    if (lng is! num || lat is! num) continue;
    out.add(LatLng(lat.toDouble(), lng.toDouble()));
  }
  return List.unmodifiable(out);
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
  final inPolygonLocus = (json['inPolygonLocusCount'] as int?) ?? 0;
  final inPolygonGeolocator = (json['inPolygonGeolocatorCount'] as int?) ?? 0;
  final firstInPolygonAt = _date(json['firstInPolygonAt']);
  final targetSpotChecks = (json['targetSpotCheckCount'] as int?) ?? 3;
  final dwellMinutes = (checkin?['dwellMinutes'] as int?) ?? 0;
  final hasIntegrity = checkin?['integrityVerdict'] != null;

  // gpsVerified flips on the first confirmed in-polygon point (locus or
  // geolocator). The legacy fallback — `pointsCollected > 0` — still
  // applies for older backends that haven't shipped the in-polygon
  // counts yet, so the pill / summary widgets keep working.
  final gpsVerified = firstInPolygonAt != null ||
      inPolygonLocus > 0 ||
      inPolygonGeolocator > 0 ||
      pointsCollected > 0;

  final photosJson = json['photos'] as List?;
  final photos = <EventPhoto>[
    if (photosJson != null)
      for (final p in photosJson.cast<Map<String, dynamic>>())
        EventPhoto(
          id: p['id'] as String,
          publicUrl: p['publicUrl'] as String?,
          capturedAt: _date(p['createdAt']) ?? DateTime.now(),
          isInsideGeofence: p['isInsideGeofence'] as bool? ?? false,
          isWithinTimeWindow: p['isWithinTimeWindow'] as bool? ?? false,
          isExifValid: p['isExifValid'] as bool? ?? false,
        ),
  ];

  final tasksJson = json['tasks'] as List?;
  final serverTasks = <VerificationTask>[
    if (tasksJson != null)
      for (final t in tasksJson.cast<Map<String, dynamic>>())
        if (_taskIdFromString(t['taskId'] as String?) != null)
          VerificationTask(
            id: _taskIdFromString(t['taskId'] as String?)!,
            status: _taskStatusFromString(t['status'] as String?) ??
                VerificationTaskStatus.pending,
            evidenceAt: _date(t['evidenceAt']),
            progressNumerator: t['progressN'] as int?,
            progressDenominator: t['progressM'] as int?,
          ),
  ];

  return QuestStatus(
    eventId: eventId,
    isActive: phase == 'during',
    dwellMinutes: dwellMinutes,
    checks: QuestChecks(
      gpsVerified: gpsVerified,
      deviceTrusted: hasIntegrity,
      integrityActive: hasIntegrity,
      photoCapture: checkin?['photoId'] != null,
    ),
    startedAt: _date(checkin?['firstPointAt']) ?? firstInPolygonAt,
    inPolygonGeolocatorCount: inPolygonGeolocator,
    inPolygonLocusCount: inPolygonLocus,
    firstInPolygonAt: firstInPolygonAt,
    targetSpotCheckCount: targetSpotChecks,
    serverTasks: serverTasks,
    photos: photos,
    badgeId: (json['badge'] as Map<String, dynamic>?)?['id'] as String?,
  );
}

VerificationTaskId? _taskIdFromString(String? raw) {
  switch (raw) {
    case 'arrival':
      return VerificationTaskId.arrival;
    case 'spot_checks':
      return VerificationTaskId.spotChecks;
    case 'photo':
      return VerificationTaskId.photo;
    default:
      // Unknown / retired ids (e.g. legacy 'dwell' from older backends)
      // are dropped — the consumer renders only what we recognise.
      return null;
  }
}

VerificationTaskStatus? _taskStatusFromString(String? raw) {
  switch (raw) {
    case 'done':
      return VerificationTaskStatus.done;
    case 'active':
      return VerificationTaskStatus.active;
    case 'pending':
      return VerificationTaskStatus.pending;
    default:
      return null;
  }
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  if (v is String) {
    // API returns timestamps without timezone suffix — treat as UTC, convert to local.
    final s = (v.endsWith('Z') || v.contains('+') || v.contains('-', 11)) ? v : '${v}Z';
    return DateTime.tryParse(s)?.toLocal();
  }
  return null;
}

MyQuestEntry myQuestEntryFromJson(Map<String, dynamic> json) {
  final eventJson = json['event'] as Map<String, dynamic>;
  // The endpoint ships only the event fields the list needs, not the
  // full Event payload — fields like geofence/description/countryCode
  // are absent. We still want to reuse the existing Event class so
  // the row widgets and the tap → eventDetail navigation just work;
  // missing fields get safe defaults.
  final event = Event(
    id: eventJson['id'] as String,
    slug: eventJson['slug'] as String,
    title: eventJson['title'] as String,
    artistName: eventJson['artistName'] as String?,
    venueName: eventJson['venueName'] as String,
    city: eventJson['city'] as String,
    countryCode: 'MX',
    description: '',
    category: EventCategory.fromSlug(eventJson['category'] as String) ??
        EventCategory.music,
    heroImageUrl: eventJson['heroImageUrl'] as String?,
    startsAt: DateTime.parse(eventJson['startsAt'] as String),
    endsAt: DateTime.parse(eventJson['endsAt'] as String),
    geofencePolygon: const [],
  );
  final phase = QuestPhase.values.byName(json['phase'] as String);
  final status = MyQuestStatus.values.byName(json['status'] as String);
  final ck = json['checkin'] as Map<String, dynamic>?;
  final bd = json['badge'] as Map<String, dynamic>?;
  return MyQuestEntry(
    event: event,
    intentCreatedAt: DateTime.parse(json['intentCreatedAt'] as String),
    phase: phase,
    status: status,
    verification: ck == null
        ? null
        : QuestVerification(
            isVerified: ck['isVerified'] as bool,
            verificationScore: (ck['verificationScore'] as num).toDouble(),
            reconciledAt: ck['reconciledAt'] == null
                ? null
                : DateTime.parse(ck['reconciledAt'] as String),
          ),
    badge: bd == null
        ? null
        : BadgeSummary(
            id: bd['id'] as String,
            serialNumber: bd['serialNumber'] as int,
            awardedAt: DateTime.parse(bd['awardedAt'] as String),
          ),
  );
}
