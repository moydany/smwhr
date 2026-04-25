// ignore_for_file: unused_field
import '../models/badge.dart';
import '../models/user.dart';
import '../repositories/users_repository.dart';
import 'api_client.dart';

class RealUsersRepository implements UsersRepository {
  RealUsersRepository(this._api);

  final ApiClient _api;

  @override
  Future<User> getMe() =>
      throw UnimplementedError('GET /me — Phase 2.');

  @override
  Future<User> updateMe({
    String? displayName,
    String? bio,
    String? city,
    List<String>? interests,
  }) =>
      throw UnimplementedError('PATCH /me — Phase 2.');

  @override
  Future<User?> getUserByHandle(String handle) =>
      throw UnimplementedError('GET /users/$handle — Phase 2.');

  @override
  Future<List<Badge>> getUserBadges(String userIdOrHandle) =>
      throw UnimplementedError(
        'GET /users/$userIdOrHandle/badges — Phase 2.',
      );
}
