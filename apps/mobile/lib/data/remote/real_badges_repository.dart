import 'package:dio/dio.dart';

import '../models/badge.dart';
import '../repositories/badges_repository.dart';
import 'api_client.dart';
import 'mappers.dart';

class RealBadgesRepository implements BadgesRepository {
  RealBadgesRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Badge>> listMyBadges() async {
    final res = await _api.dio.get<List<dynamic>>('/me/badges');
    return res.data!
        .map((e) => badgeFromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Badge?> getBadge(String badgeId) async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/badges/$badgeId',
      );
      return badgeFromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<String> getShareImageUrl(String badgeId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/badges/$badgeId/share',
    );
    final body = res.data!;
    return (body['shareImageUrl'] as String?) ??
        (body['composedImageUrl'] as String?) ??
        '';
  }
}
