// ignore_for_file: unused_field
import '../models/badge.dart';
import '../repositories/badges_repository.dart';
import 'api_client.dart';

class RealBadgesRepository implements BadgesRepository {
  RealBadgesRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Badge>> listMyBadges() =>
      throw UnimplementedError('GET /me/badges — Phase 2.');

  @override
  Future<Badge?> getBadge(String badgeId) =>
      throw UnimplementedError('GET /badges/$badgeId — Phase 2.');

  @override
  Future<String> getShareImageUrl(String badgeId) =>
      throw UnimplementedError('GET /badges/$badgeId/share — Phase 2.');
}
