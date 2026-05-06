import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;

/// A safe, user-facing error from just_firebase operations.
///
/// Internal Firebase error codes are preserved for debugging but the [message]
/// is always safe to show to users (no credentials, tokens, or stack traces).
sealed class JustFirebaseError {
  const JustFirebaseError({
    required this.message,
    this.code,
    this.originalError,
  });

  /// Safe, human-readable description of the error.
  final String message;

  /// Firebase error code, e.g. `'auth/wrong-password'`, `'permission-denied'`.
  final String? code;

  /// The original exception — for logging only, never expose to users.
  final Object? originalError;

  @override
  String toString() => 'JustFirebaseError($code): $message';
}

/// Authentication-specific error (sign-in, sign-up, token refresh, etc.).
final class AuthError extends JustFirebaseError {
  const AuthError({
    required super.message,
    super.code,
    super.originalError,
    this.retryAfterSeconds,
  });

  /// Populated when rate-limiting is in effect. Number of seconds the caller
  /// should wait before retrying.
  final int? retryAfterSeconds;

  factory AuthError.fromFirebase(FirebaseAuthException e) {
    return AuthError(
      message: _authMessage(e.code),
      code: e.code,
      originalError: e,
    );
  }

  factory AuthError.rateLimited(int retryAfterSeconds) => AuthError(
    message: 'Too many attempts. Please wait before trying again.',
    code: 'auth/too-many-requests',
    retryAfterSeconds: retryAfterSeconds,
  );
}

/// Firestore read/write error.
final class FirestoreError extends JustFirebaseError {
  const FirestoreError({
    required super.message,
    super.code,
    super.originalError,
  });

  factory FirestoreError.fromFirebase(FirebaseException e) {
    return FirestoreError(
      message: _firestoreMessage(e.code),
      code: e.code,
      originalError: e,
    );
  }
}

/// Remote Config fetch/activate error.
final class RemoteConfigError extends JustFirebaseError {
  const RemoteConfigError({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Network connectivity error.
final class NetworkError extends JustFirebaseError {
  const NetworkError({super.message = 'No internet connection.', super.originalError})
    : super(code: 'network/unavailable');
}

/// Catch-all for unexpected errors.
final class UnknownFirebaseError extends JustFirebaseError {
  const UnknownFirebaseError({super.originalError})
    : super(
        message: 'An unexpected error occurred. Please try again.',
        code: 'unknown',
      );
}

// ── Message helpers ──────────────────────────────────────────────────────────

String _authMessage(String code) {
  return switch (code) {
    'user-not-found' => 'No account found for this email.',
    'wrong-password' || 'invalid-credential' => 'Incorrect email or password.',
    'email-already-in-use' => 'An account with this email already exists.',
    'invalid-email' => 'Please enter a valid email address.',
    'weak-password' => 'Password must be at least 6 characters.',
    'user-disabled' => 'This account has been disabled.',
    'too-many-requests' => 'Too many attempts. Please try again later.',
    'network-request-failed' => 'No internet connection.',
    'requires-recent-login' => 'Please sign in again to continue.',
    'account-exists-with-different-credential' =>
      'An account already exists with a different sign-in method.',
    'popup-closed-by-user' || 'cancelled-popup-request' => 'Sign-in was cancelled.',
    _ => 'Authentication failed. Please try again.',
  };
}

String _firestoreMessage(String? code) {
  return switch (code) {
    'permission-denied' => 'You do not have permission to access this data.',
    'not-found' => 'The requested data was not found.',
    'unavailable' => 'Service temporarily unavailable. Please try again.',
    'deadline-exceeded' => 'Request timed out. Please check your connection.',
    'resource-exhausted' => 'Service limit reached. Please try again later.',
    _ => 'Failed to access data. Please try again.',
  };
}
