import '../models/badge.dart';
import '../models/user.dart';

abstract class UsersRepository {
  Future<User> getMe();
  Future<User> updateMe({
    String? displayName,
    String? bio,
    String? city,
    List<String>? interests,
  });
  Future<User?> getUserByHandle(String handle);
  Future<List<Badge>> getUserBadges(String userIdOrHandle);
}
