import '../models/user.dart';

/// Auth contract.
///
/// Mock impl simulates 800–1200 ms latency on every method and persists the
/// session to Hive across cold starts. Real impl in Phase 2 wraps Supabase
/// Auth + the NestJS `/auth/*` endpoints.
abstract class AuthRepository {
  /// Currently authenticated user, or null if signed out.
  Stream<AuthState> watchAuthState();

  /// Last known auth state synchronously (for go_router redirect).
  AuthState get currentState;

  Future<AuthResult> signInWithApple();
  Future<AuthResult> signInWithGoogle();
  Future<AuthResult> requestEmailMagicLink(String email);
  Future<AuthResult> verifyEmailMagicLink(String email, String code);

  /// Persist the onboarding step results and mark onboarding complete.
  Future<User> completeOnboarding({
    required String handle,
    required String displayName,
    required String city,
    required List<String> interests,
    required bool notificationsEnabled,
  });

  Future<bool> checkHandleAvailable(String handle);

  Future<void> signOut();
}

/// Auth lifecycle states emitted by `watchAuthState()`.
sealed class AuthState {
  const AuthState();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

class AuthSignedIn extends AuthState {
  final User user;
  const AuthSignedIn(this.user);
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

/// Result returned by signIn methods.
sealed class AuthResult {
  const AuthResult();
}

class AuthResultNeedsOnboarding extends AuthResult {
  final User user;
  const AuthResultNeedsOnboarding(this.user);
}

class AuthResultReady extends AuthResult {
  final User user;
  const AuthResultReady(this.user);
}

class AuthResultEmailSent extends AuthResult {
  final String email;
  const AuthResultEmailSent(this.email);
}

class AuthResultFailure extends AuthResult {
  final String message;
  const AuthResultFailure(this.message);
}
