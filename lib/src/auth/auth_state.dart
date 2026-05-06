import '../core/firebase_error.dart';
import 'auth_user.dart';

/// Current authentication status.
enum AuthState {
  /// Initial state before Firebase Auth has emitted the first event.
  unknown,

  /// Auth state is being determined (e.g. restoring a persisted session).
  loading,

  /// A user is signed in.
  authenticated,

  /// No user is signed in.
  unauthenticated,
}

/// Result of a sign-in or sign-up operation.
sealed class AuthResult {
  const AuthResult();
}

/// The operation completed and a user is now signed in.
final class AuthSuccess extends AuthResult {
  const AuthSuccess(this.user);

  final JustFirebaseUser user;

  @override
  String toString() => 'AuthSuccess(${user.uid})';
}

/// The operation failed. Check [error] for the reason.
final class AuthFailure extends AuthResult {
  const AuthFailure(this.error);

  final JustFirebaseError error;

  @override
  String toString() => 'AuthFailure($error)';
}
