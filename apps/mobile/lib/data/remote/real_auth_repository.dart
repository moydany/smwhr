// ignore_for_file: unused_field
import '../../shared/utils/handle_validator.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import 'api_client.dart';

/// Phase 2 stub. Each method documents the API endpoint it'll hit and
/// throws UnimplementedError until the NestJS backend is live. Wire
/// these up against `docs/API.md` contracts when ready — the rest of
/// the app already consumes the AuthRepository interface, so the
/// switch is just flipping the provider in lib/data/providers.dart.
class RealAuthRepository implements AuthRepository {
  RealAuthRepository(this._api);

  final ApiClient _api;

  @override
  AuthState get currentState => throw UnimplementedError(
        'RealAuthRepository.currentState — Phase 2.',
      );

  @override
  Stream<AuthState> watchAuthState() => throw UnimplementedError(
        'RealAuthRepository.watchAuthState — Phase 2 (Supabase auth + Hive).',
      );

  @override
  Future<AuthResult> signInWithApple() => throw UnimplementedError(
        'POST /auth/apple — Phase 2.',
      );

  @override
  Future<AuthResult> signInWithGoogle() => throw UnimplementedError(
        'POST /auth/google — Phase 2.',
      );

  @override
  Future<AuthResult> requestEmailMagicLink(String email) =>
      throw UnimplementedError('POST /auth/email/request — Phase 2.');

  @override
  Future<AuthResult> verifyEmailMagicLink(String email, String code) =>
      throw UnimplementedError('POST /auth/email/verify — Phase 2.');

  @override
  Future<User> completeOnboarding({
    required String handle,
    required String displayName,
    required String city,
    required List<String> interests,
    required bool notificationsEnabled,
  }) {
    final canonical = HandleValidator.normalize(handle);
    return Future.error(
      UnimplementedError(
        'POST /me/onboarding — Phase 2 (handle=$canonical).',
      ),
    );
  }

  @override
  Future<bool> checkHandleAvailable(String handle) =>
      throw UnimplementedError(
        'GET /users/check-handle/$handle — Phase 2.',
      );

  @override
  Future<void> signOut() => throw UnimplementedError(
        'POST /auth/logout — Phase 2.',
      );
}
