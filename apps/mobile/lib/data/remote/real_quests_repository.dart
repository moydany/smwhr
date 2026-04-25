// ignore_for_file: unused_field
import 'dart:io';

import '../models/quest.dart';
import '../repositories/quests_repository.dart';
import 'api_client.dart';

class RealQuestsRepository implements QuestsRepository {
  RealQuestsRepository(this._api);

  final ApiClient _api;

  @override
  Future<QuestStatus> getQuestStatus(String eventId) =>
      throw UnimplementedError('GET /quests/$eventId/status — Phase 2.');

  @override
  Stream<QuestStatus> watchQuestStatus(String eventId) =>
      Stream.error(UnimplementedError(
        'Stream of GET /quests/$eventId/status with Locus + Geolocator '
        'reductions — Phase 2.',
      ));

  @override
  Future<void> startQuest(String eventId) async {
    // Real impl: register Locus + Geolocator + Hive logging here.
    throw UnimplementedError(
      'startQuest($eventId) — Phase 2 dual-track wiring.',
    );
  }

  @override
  Future<void> stopQuest(String eventId) async {
    throw UnimplementedError(
      'stopQuest($eventId) — Phase 2 dual-track teardown.',
    );
  }

  @override
  Future<QuestStatus> uploadPhoto({
    required String eventId,
    required File photo,
  }) =>
      throw UnimplementedError(
        'POST /quests/$eventId/photo (multipart) — Phase 2.',
      );

  @override
  Future<void> syncTrackingBatch({
    required String eventId,
    required List<LocusEvent> locusEvents,
    required List<GeolocatorPing> geolocatorPings,
  }) =>
      throw UnimplementedError(
        'POST /quests/$eventId/sync — Phase 2 dual-track upload.',
      );

  @override
  Future<void> attestIntegrity(String eventId, String token) =>
      throw UnimplementedError(
        'POST /quests/$eventId/integrity — Phase 2.',
      );
}
