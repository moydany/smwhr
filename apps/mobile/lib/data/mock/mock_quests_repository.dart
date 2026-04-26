import 'dart:async';
import 'dart:io';

import '../models/photo_upload.dart';
import '../models/quest.dart';
import '../repositories/quests_repository.dart';
import 'mock_latency.dart';

/// Mock quest repo — simulates the magic of the active quest screen with
/// a Timer that pretends 1 second of wall time = 1 minute of dwell.
///
/// Behaviour per active eventId:
/// - On `startQuest`: emit `isActive: true`, dwellMinutes: 0, all checks
///   off. After 800 ms, flip `gpsVerified` and `deviceTrusted` true. After
///   1.6 s, flip `integrityActive`. Then increment dwellMinutes every
///   second up to 90 (caps to keep the timer bounded).
/// - On `uploadPhoto`: simulate 1.5 s upload, then flip `photoCapture`.
/// - On `stopQuest`: cancel the timer, set `isActive: false`.
class MockQuestsRepository implements QuestsRepository {
  final Map<String, _QuestRuntime> _runtimes = {};

  _QuestRuntime _runtime(String eventId) {
    return _runtimes.putIfAbsent(
      eventId,
      () => _QuestRuntime(eventId),
    );
  }

  @override
  Future<QuestStatus> getQuestStatus(String eventId) async {
    await MockLatency.shortDelay();
    return _runtime(eventId).status;
  }

  @override
  Stream<QuestStatus> watchQuestStatus(String eventId) {
    return _runtime(eventId).statusStream;
  }

  @override
  Future<void> startQuest(String eventId) async {
    await MockLatency.simulate();
    _runtime(eventId).start();
  }

  @override
  Future<void> stopQuest(String eventId) async {
    await MockLatency.shortDelay();
    _runtime(eventId).stop();
  }

  @override
  Future<PhotoUploadResult> uploadPhoto({
    required String eventId,
    required File photo,
    PhotoMetadata? metadata,
  }) async {
    // Heavier latency — feels like a real upload.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    _runtime(eventId).flipPhotoCapture();
    // Mock always returns "all good" — exercising the soft-warning path
    // requires the real backend's PostGIS check.
    return PhotoUploadResult(
      photoId: 'mock-photo-$eventId',
      isExifValid: true,
      isWithinTimeWindow: true,
      isInsideGeofence: true,
    );
  }

  @override
  Future<void> syncTrackingBatch({
    required String eventId,
    required List<LocusEvent> locusEvents,
    required List<GeolocatorPing> geolocatorPings,
  }) async {
    await MockLatency.shortDelay();
    // No-op in mock — pretend the batch went up.
  }

  @override
  Future<void> attestIntegrity(String eventId, String token) async {
    await MockLatency.shortDelay();
  }

  @override
  Future<String?> finalizeQuest(String eventId) async {
    await MockLatency.shortDelay();
    // Mock badge id matches one of the seeded mock badges so the
    // reveal screen + profile collection grid both light up.
    return 'bdg-001';
  }

  void dispose() {
    for (final r in _runtimes.values) {
      r.dispose();
    }
    _runtimes.clear();
  }
}

class _QuestRuntime {
  final String eventId;

  QuestStatus _status;
  final StreamController<QuestStatus> _controller =
      StreamController<QuestStatus>.broadcast();

  Timer? _dwellTimer;
  Timer? _checksTimer1;
  Timer? _checksTimer2;

  _QuestRuntime(this.eventId)
      : _status = QuestStatus.notStarted(eventId);

  QuestStatus get status => _status;
  Stream<QuestStatus> get statusStream async* {
    yield _status;
    yield* _controller.stream;
  }

  void _emit(QuestStatus s) {
    _status = s;
    _controller.add(s);
  }

  void start() {
    stop(); // idempotent
    _emit(_status.copyWith(
      isActive: true,
      dwellMinutes: 0,
      checks: const QuestChecks.allFalse(),
      startedAt: DateTime.now(),
    ));

    _checksTimer1 = Timer(const Duration(milliseconds: 800), () {
      _emit(_status.copyWith(
        checks: _status.checks.copyWith(
          gpsVerified: true,
          deviceTrusted: true,
        ),
      ));
    });

    _checksTimer2 = Timer(const Duration(milliseconds: 1600), () {
      _emit(_status.copyWith(
        checks: _status.checks.copyWith(integrityActive: true),
      ));
    });

    _dwellTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status.dwellMinutes >= 90) {
        _dwellTimer?.cancel();
        return;
      }
      _emit(_status.copyWith(dwellMinutes: _status.dwellMinutes + 1));
    });
  }

  void stop() {
    _dwellTimer?.cancel();
    _checksTimer1?.cancel();
    _checksTimer2?.cancel();
    if (_status.isActive) {
      _emit(_status.copyWith(isActive: false));
    }
  }

  void flipPhotoCapture() {
    _emit(_status.copyWith(
      checks: _status.checks.copyWith(photoCapture: true),
    ));
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
