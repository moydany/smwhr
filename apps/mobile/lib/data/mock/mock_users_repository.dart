import 'dart:io';

import '../models/badge.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/users_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_badges.dart';
import 'mock_latency.dart';
import 'mock_users.dart';

class MockUsersRepository implements UsersRepository {
  /// Auth repo handle so we can read whoever is signed in for `getMe()`.
  final MockAuthRepository _auth;

  MockUsersRepository(this._auth);

  @override
  Future<User> getMe() async {
    await MockLatency.shortDelay();
    final state = _auth.currentState;
    return switch (state) {
      AuthSignedIn(:final user) => user,
      _ => mockCurrentUser, // fallback so dev screens render even pre-login
    };
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
    await MockLatency.simulate();
    final me = await getMe();
    return me.copyWith(
      handle: handle,
      displayName: displayName,
      bio: bio,
      city: city,
      interests: interests,
      language: language,
    );
  }

  @override
  Future<User> uploadAvatar(File file) async {
    await MockLatency.simulate();
    final me = await getMe();
    // Mock: echo back the local file path as a `file://` URL so the
    // edit-profile preview can render it via Image.network/cached.
    return me.copyWith(avatarUrl: Uri.file(file.path).toString());
  }

  @override
  Future<User> removeAvatar() async {
    await MockLatency.simulate();
    final me = await getMe();
    return me.copyWith(clearAvatar: true);
  }

  @override
  Future<User?> getUserByHandle(String handle) async {
    await MockLatency.shortDelay();
    return mockUsersByHandle[handle.trim().toLowerCase()];
  }

  @override
  Future<List<Badge>> getUserBadges(String userIdOrHandle) async {
    await MockLatency.mediumDelay();
    final id = mockUsersByHandle[userIdOrHandle]?.id ?? userIdOrHandle;
    return mockBadges.where((b) => b.userId == id).toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
  }
}
