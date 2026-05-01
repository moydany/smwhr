import 'dart:io';

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
    String? handle,
    String? displayName,
    String? bio,
    String? city,
    List<String>? interests,
    String? language,
  }) async {
    final body = <String, Object?>{};
    if (handle != null) body['handle'] = HandleValidator.normalize(handle);
    if (displayName != null) body['displayName'] = displayName;
    if (bio != null) body['bio'] = bio;
    if (city != null) body['city'] = city;
    if (interests != null) body['interests'] = interests;
    if (language != null) body['language'] = language;
    final res = await _api.dio.patch<Map<String, dynamic>>('/me', data: body);
    return userFromJson(res.data!);
  }

  @override
  Future<User> uploadAvatar(File file) async {
    final mime = _mimeFor(file.path);
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        contentType: DioMediaType.parse(mime),
      ),
    });
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/me/avatar',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    return userFromJson(res.data!);
  }

  @override
  Future<User> removeAvatar() async {
    final res = await _api.dio.delete<Map<String, dynamic>>('/me/avatar');
    return userFromJson(res.data!);
  }

  static String _mimeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    if (lower.endsWith('.webp')) return 'image/webp';
    // image_picker normalises camera + gallery output to JPEG by default.
    return 'image/jpeg';
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
