import 'dart:io';

import '../models/badge.dart';
import '../models/user.dart';

abstract class UsersRepository {
  Future<User> getMe();
  Future<User> updateMe({
    String? handle,
    String? displayName,
    String? bio,
    String? city,
    List<String>? interests,
    String? language,
  });

  /// Upload `file` as the current user's avatar. Returns the updated
  /// [User] with the new `avatarUrl` populated. Implementations validate
  /// the mimetype + size on the backend; the mobile only needs to hand
  /// over a file the user picked (gallery or camera).
  Future<User> uploadAvatar(File file);

  /// Clear the current user's avatar. Returns the updated [User].
  Future<User> removeAvatar();

  Future<User?> getUserByHandle(String handle);
  Future<List<Badge>> getUserBadges(String userIdOrHandle);
}
