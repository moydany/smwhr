import 'event.dart';

/// Active quest state surfaced to the UI.
///
/// In mock mode, this is mutated by `MockQuestsRepository`. In real mode
/// it's mapped from `GET /quests/:eventId/status`. The verification
/// signals come in two layers: the legacy [QuestChecks] flags (kept for
/// the pill + summary widgets) and the richer per-task data
/// ([inPolygonGeolocatorCount], [firstInPolygonAt], etc.) used to build
/// the active-quest task checklist.
class QuestStatus {
  final String eventId;
  final bool isActive;
  final int dwellMinutes;
  final QuestChecks checks;
  final DateTime? startedAt;

  /// In-polygon geolocator pings recorded server-side. Drives the
  /// "spot checks" task — N (this count) of M ([targetSpotCheckCount]).
  final int inPolygonGeolocatorCount;

  /// In-polygon Locus events recorded server-side. Used as a fallback
  /// signal for arrival when the spot-check track is still warming up.
  final int inPolygonLocusCount;

  /// Earliest in-polygon timestamp across both tracks. Lights up the
  /// "arrival" task and unlocks the camera CTA.
  final DateTime? firstInPolygonAt;

  /// Number of spot-checks the mobile should aim to land — roughly one
  /// per half-hour of event window, clamped to [3, 6]. Computed by the
  /// backend so it stays consistent across clients.
  final int targetSpotCheckCount;

  /// Persisted task ledger from the backend (`/quests/:id/status`
  /// `tasks` array). When non-empty, this is the canonical source of
  /// truth for the active-quest checklist; when empty, the [tasks]
  /// getter falls back to the older client-side derivation so older
  /// backends (or pre-ledger builds) still render a sensible list.
  final List<VerificationTask> serverTasks;

  /// Photos the user has captured for this event, oldest first. Drives
  /// the mini-gallery on the event detail screen. Empty when the user
  /// hasn't captured anything yet (or when the backend doesn't ship
  /// the field — older builds).
  final List<EventPhoto> photos;

  /// Set the moment the badge for this event has been issued for the
  /// current user — `null` until reconciliation runs and passes the
  /// gates. The detail screen swaps the "QUEST ACTIVE" indicator for
  /// a "Ver tu insignia" CTA when this transitions to non-null.
  final String? badgeId;

  const QuestStatus({
    required this.eventId,
    required this.isActive,
    required this.dwellMinutes,
    required this.checks,
    this.startedAt,
    this.inPolygonGeolocatorCount = 0,
    this.inPolygonLocusCount = 0,
    this.firstInPolygonAt,
    this.targetSpotCheckCount = 3,
    this.serverTasks = const [],
    this.photos = const [],
    this.badgeId,
  });

  /// True once the user has been confirmed inside the venue at least
  /// once. After this, the camera CTA unlocks even before the dwell
  /// threshold — under the new task model the photo is one signal of
  /// many, not the single gate.
  bool get hasArrived => firstInPolygonAt != null || checks.gpsVerified;

  /// Tasks the user can see progress on. Order is the order rendered.
  ///
  /// Prefers [serverTasks] (the persisted ledger) when present so the
  /// UI matches what the reconciliation engine sees. Falls back to a
  /// client-side derivation when the backend doesn't ship a `tasks`
  /// array — keeps older API builds working during rollout.
  ///
  /// Local-photo overlay: when the server still reports `photo:
  /// pending` but the device has a captured photo waiting to upload
  /// (mapper sets `checks.photoCapture = true` when the queue is
  /// non-empty), upgrade the photo task to `active` so the user
  /// doesn't see a flicker between "captured" and "pending" the moment
  /// the network returns and the first server response lands before
  /// the upload drainer fires.
  List<VerificationTask> get tasks {
    if (serverTasks.isNotEmpty) {
      if (!checks.photoCapture) return serverTasks;
      // Local capture present (queue has a pending photo OR backend
      // already saw it). Mark the task `done` immediately — the
      // bytes are guaranteed to live somewhere, and the claim flow
      // (`_ensurePhotoUploaded`) drains the queue before finalize so
      // a not-yet-uploaded local capture still ends up on the server
      // by the time the verifier scores. Showing `active` here made
      // the user think the capture didn't register — they'd just
      // taken a clearly-visible photo and the task was still
      // unchecked.
      return serverTasks.map((t) {
        if (t.id != VerificationTaskId.photo) return t;
        if (t.status == VerificationTaskStatus.done) return t;
        return VerificationTask(
          id: t.id,
          status: VerificationTaskStatus.done,
          evidenceAt: t.evidenceAt,
          progressNumerator: t.progressNumerator,
          progressDenominator: t.progressDenominator,
        );
      }).toList(growable: false);
    }
    return [
      VerificationTask(
        id: VerificationTaskId.arrival,
        status: hasArrived
            ? VerificationTaskStatus.done
            : VerificationTaskStatus.pending,
        evidenceAt: firstInPolygonAt,
      ),
      VerificationTask(
        id: VerificationTaskId.spotChecks,
        status: inPolygonGeolocatorCount >= targetSpotCheckCount
            ? VerificationTaskStatus.done
            : (inPolygonGeolocatorCount > 0
                ? VerificationTaskStatus.active
                : VerificationTaskStatus.pending),
        progressNumerator: inPolygonGeolocatorCount,
        progressDenominator: targetSpotCheckCount,
      ),
      VerificationTask(
        id: VerificationTaskId.photo,
        status: checks.photoCapture
            ? VerificationTaskStatus.done
            : (hasArrived
                ? VerificationTaskStatus.active
                : VerificationTaskStatus.pending),
      ),
    ];
  }

  /// Returns true when enough tasks have completed to issue the badge.
  /// Under the task model the rule is: arrival + dwell + photo, with
  /// spot-checks as a soft signal that boosts confidence but doesn't
  /// gate the badge by itself.
  bool isReadyForCapture(int dwellMinimumMin) {
    final dwellPassed = dwellMinutes >= dwellMinimumMin;
    return isActive && hasArrived && dwellPassed && checks.deviceTrusted &&
        checks.integrityActive;
  }

  factory QuestStatus.notStarted(String eventId) => QuestStatus(
        eventId: eventId,
        isActive: false,
        dwellMinutes: 0,
        checks: const QuestChecks.allFalse(),
      );

  QuestStatus copyWith({
    bool? isActive,
    int? dwellMinutes,
    QuestChecks? checks,
    DateTime? startedAt,
    int? inPolygonGeolocatorCount,
    int? inPolygonLocusCount,
    DateTime? firstInPolygonAt,
    int? targetSpotCheckCount,
    List<VerificationTask>? serverTasks,
    List<EventPhoto>? photos,
    String? badgeId,
  }) {
    return QuestStatus(
      eventId: eventId,
      isActive: isActive ?? this.isActive,
      dwellMinutes: dwellMinutes ?? this.dwellMinutes,
      checks: checks ?? this.checks,
      startedAt: startedAt ?? this.startedAt,
      inPolygonGeolocatorCount:
          inPolygonGeolocatorCount ?? this.inPolygonGeolocatorCount,
      inPolygonLocusCount: inPolygonLocusCount ?? this.inPolygonLocusCount,
      firstInPolygonAt: firstInPolygonAt ?? this.firstInPolygonAt,
      targetSpotCheckCount: targetSpotCheckCount ?? this.targetSpotCheckCount,
      serverTasks: serverTasks ?? this.serverTasks,
      photos: photos ?? this.photos,
      badgeId: badgeId ?? this.badgeId,
    );
  }
}

/// One photo captured for an event. Backend representation matches the
/// `photos` array in `GET /quests/:id/status`. The `localFilePath`
/// slot is set ONLY for photos that haven't uploaded yet — the
/// repository prepends a synthetic entry while the queue still has a
/// pending capture so the gallery renders the just-taken shot
/// instantly instead of waiting for the next status poll.
class EventPhoto {
  final String id;
  final String? publicUrl;
  final String? localFilePath;
  final DateTime capturedAt;
  final bool isInsideGeofence;
  final bool isWithinTimeWindow;
  final bool isExifValid;

  const EventPhoto({
    required this.id,
    required this.publicUrl,
    this.localFilePath,
    required this.capturedAt,
    required this.isInsideGeofence,
    required this.isWithinTimeWindow,
    required this.isExifValid,
  });
}

/// One row in the active-quest task checklist. Derived from
/// [QuestStatus]; never persisted on its own.
class VerificationTask {
  final VerificationTaskId id;
  final VerificationTaskStatus status;

  /// When this task transitioned to [VerificationTaskStatus.done].
  /// Null while pending/active.
  final DateTime? evidenceAt;

  /// For tasks that count progress (e.g. spot-checks N of M). Null on
  /// boolean tasks like arrival/photo.
  final int? progressNumerator;
  final int? progressDenominator;

  const VerificationTask({
    required this.id,
    required this.status,
    this.evidenceAt,
    this.progressNumerator,
    this.progressDenominator,
  });

  bool get isDone => status == VerificationTaskStatus.done;
  bool get isActive => status == VerificationTaskStatus.active;
  bool get isPending => status == VerificationTaskStatus.pending;
}

/// Server mirror of [VERIFICATION_TASK_IDS] in
/// `apps/api/src/quests/services/verification-tasks.service.ts`. The
/// continuous-`dwell` task was retired in R0.1 — verification is now
/// driven by the spot-check ratio, surfaced as [spotChecks].
enum VerificationTaskId { arrival, spotChecks, photo }

enum VerificationTaskStatus { pending, active, done }

/// Four verification checks shown on the active quest screen.
class QuestChecks {
  final bool gpsVerified;
  final bool deviceTrusted;
  final bool integrityActive;
  final bool photoCapture;

  const QuestChecks({
    required this.gpsVerified,
    required this.deviceTrusted,
    required this.integrityActive,
    required this.photoCapture,
  });

  const QuestChecks.allFalse()
      : gpsVerified = false,
        deviceTrusted = false,
        integrityActive = false,
        photoCapture = false;

  bool get areAllPassing =>
      gpsVerified && deviceTrusted && integrityActive && photoCapture;

  int get passingCount =>
      (gpsVerified ? 1 : 0) +
      (deviceTrusted ? 1 : 0) +
      (integrityActive ? 1 : 0) +
      (photoCapture ? 1 : 0);

  QuestChecks copyWith({
    bool? gpsVerified,
    bool? deviceTrusted,
    bool? integrityActive,
    bool? photoCapture,
  }) {
    return QuestChecks(
      gpsVerified: gpsVerified ?? this.gpsVerified,
      deviceTrusted: deviceTrusted ?? this.deviceTrusted,
      integrityActive: integrityActive ?? this.integrityActive,
      photoCapture: photoCapture ?? this.photoCapture,
    );
  }
}

/// Raw event captured by Locus during a quest. Persisted to Hive locally,
/// uploaded in batches by `TrackingSync` (Session 7).
class LocusEvent {
  final String id;
  final String eventId;
  final LocusEventType type;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final Map<String, dynamic> raw;

  const LocusEvent({
    required this.id,
    required this.eventId,
    required this.type,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.raw = const {},
  });
}

enum LocusEventType {
  geofenceEnter,
  geofenceExit,
  geofenceDwell,
  locationUpdate,
  motionChange,
  heartbeat,
}

/// Periodic geolocator ping (shadow tracker, every 5 min during quests).
class GeolocatorPing {
  final String id;
  final String eventId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isInsidePolygon;

  const GeolocatorPing({
    required this.id,
    required this.eventId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isInsidePolygon,
  });
}

/// Status pill shown on the "Mis quests" list. Derived server-side
/// (`MyQuestsService.listForUser`) so the list and event-detail
/// screens never disagree about whether an event is live or post.
enum MyQuestStatus { upcoming, live, verified, unverified }

/// Lifecycle phase for an event from the current user's perspective.
/// Mirrors the backend enum exactly — keep these strings in sync.
enum QuestPhase { pre, during, post }

/// One entry on the "Mis quests" list — an event the user RSVP'd to,
/// joined with whatever verification + badge data already exists.
class MyQuestEntry {
  final Event event;
  final DateTime intentCreatedAt;
  final QuestPhase phase;
  final MyQuestStatus status;
  final QuestVerification? verification;
  final BadgeSummary? badge;

  const MyQuestEntry({
    required this.event,
    required this.intentCreatedAt,
    required this.phase,
    required this.status,
    this.verification,
    this.badge,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyQuestEntry && other.event.id == event.id;

  @override
  int get hashCode => event.id.hashCode;
}

/// Snapshot of the current user's `Checkin` row for an event. Null
/// until reconciliation has run — even successful runs return a row,
/// so a non-null verification with `isVerified: false` is the
/// "we tried, didn't make the threshold" signal.
class QuestVerification {
  final bool isVerified;
  final double verificationScore;
  final DateTime? reconciledAt;

  const QuestVerification({
    required this.isVerified,
    required this.verificationScore,
    this.reconciledAt,
  });
}

/// Lightweight badge reference — just enough to deep-link into the
/// reveal/badge-detail screen without requiring a full Badge fetch.
class BadgeSummary {
  final String id;
  final int serialNumber;
  final DateTime awardedAt;

  const BadgeSummary({
    required this.id,
    required this.serialNumber,
    required this.awardedAt,
  });
}
