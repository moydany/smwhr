import 'package:dio/dio.dart';

import '../../shared/utils/handle_validator.dart';
import '../models/badge.dart';
import '../models/user.dart';
import '../repositories/users_repository.dart';
import 'api_client.dart';
import 'mappers.dart';

class RealUsersRepository implements UsersRepository {
  RealUsersRepository(this._api);

  final ApiClient _api;

  @override
  Future<User> getMe() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/me');
    return userFromJson(res.data!);
  }

  @override
  Future<User> updateMe({
    String? displayName,
    String? bio,
    String? city,
    List<String>? interests,
  }) async {
    final body = <String, Object?>{};
    if (displayName != null) body['displayName'] = displayName;
    if (bio != null) body['bio'] = bio;
    if (city != null) body['city'] = city;
    if (interests != null) body['interests'] = interests;
    final res = await _api.dio.patch<Map<String, dynamic>>('/me', data: body);
    return userFromJson(res.data!);
  }

  @override
  Future<User?> getUserByHandle(String handle) async {
    final canonical = HandleValidator.normalize(handle);
    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/users/$canonical');
      return userFromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<Badge>> getUserBadges(String userIdOrHandle) async {
    final canonical = HandleValidator.normalize(userIdOrHandle);
    final res = await _api.dio.get<List<dynamic>>('/users/$canonical/badges');
    return res.data!
        .map((e) => badgeFromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
