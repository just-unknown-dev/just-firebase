import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_storage/just_storage.dart';

import '../core/firebase_config.dart';
import '../core/firebase_error.dart';
import 'auth_state.dart';
import 'auth_user.dart';

/// Manages Firebase Authentication with reactive signals, secure token
/// persistence, and client-side rate limiting.
///
/// Obtain via [FirebaseManager().auth] after initialization.
class JustFirebaseAuth {
  JustFirebaseAuth({required JustFirebaseConfig config}) : _config = config;

  final JustFirebaseConfig _config;
  final fb.FirebaseAuth _fbAuth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final GoogleSignIn _playGamesSignIn = GoogleSignIn(
    signInOption: SignInOption.games,
  );

  JustSecureStorage? _secureStorage;
  StreamSubscription<fb.User?>? _authStateSub;

  // ── Reactive state ────────────────────────────────────────────────────────

  final Signal<JustFirebaseUser?> _currentUser = Signal(
    null,
    debugLabel: 'firebase.currentUser',
  );
  final Signal<AuthState> _authState = Signal(
    AuthState.unknown,
    debugLabel: 'firebase.authState',
  );

  /// The currently signed-in user, or `null` when signed out.
  Signal<JustFirebaseUser?> get currentUser => _currentUser;

  /// The current authentication state.
  Signal<AuthState> get authState => _authState;

  // ── Rate limiting ─────────────────────────────────────────────────────────

  // email → (attempt count, window start epoch ms)
  final Map<String, (int, int)> _rateLimitMap = {};

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      _secureStorage = await JustStorage.encrypted();
    } catch (e) {
      debugPrint('JustFirebaseAuth: secure storage unavailable ($e)');
    }

    _authState.value = AuthState.loading;

    _authStateSub = _fbAuth.authStateChanges().listen(
      (user) {
        if (user == null) {
          _currentUser.value = null;
          _authState.value = AuthState.unauthenticated;
        } else {
          _currentUser.value = JustFirebaseUser.fromFirebase(user);
          _authState.value = AuthState.authenticated;
          _persistUser(_currentUser.value!);
        }
      },
      onError: (Object e) {
        debugPrint('JustFirebaseAuth: auth state error ($e)');
        _authState.value = AuthState.unauthenticated;
      },
    );

    // Restore cached user for immediate UI while waiting for Firebase.
    await _restorePersistedUser();
  }

  void dispose() {
    _authStateSub?.cancel();
    _authStateSub = null;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Signs in with [email] and [password].
  Future<AuthResult> signInWithEmail(String email, String password) async {
    final rateCheck = _checkRateLimit(email);
    if (rateCheck != null) return AuthFailure(rateCheck);

    try {
      final cred = await _fbAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _clearRateLimit(email);
      return AuthSuccess(JustFirebaseUser.fromFirebase(cred.user!));
    } on fb.FirebaseAuthException catch (e) {
      _recordFailedAttempt(email);
      return AuthFailure(AuthError.fromFirebase(e));
    } catch (e) {
      return AuthFailure(UnknownFirebaseError(originalError: e));
    }
  }

  /// Creates a new account with [email], [password], and optional [displayName].
  Future<AuthResult> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final cred = await _fbAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (displayName != null) {
        await cred.user!.updateDisplayName(displayName);
        await cred.user!.reload();
      }
      final user = JustFirebaseUser.fromFirebase(
        _fbAuth.currentUser ?? cred.user!,
      );
      return AuthSuccess(user);
    } on fb.FirebaseAuthException catch (e) {
      return AuthFailure(AuthError.fromFirebase(e));
    } catch (e) {
      return AuthFailure(UnknownFirebaseError(originalError: e));
    }
  }

  /// Signs in with a Google account.
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const AuthFailure(
          AuthError(
            message: 'Sign-in was cancelled.',
            code: 'cancelled-popup-request',
          ),
        );
      }
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _fbAuth.signInWithCredential(credential);
      return AuthSuccess(JustFirebaseUser.fromFirebase(cred.user!));
    } on fb.FirebaseAuthException catch (e) {
      return AuthFailure(AuthError.fromFirebase(e));
    } catch (e) {
      return AuthFailure(UnknownFirebaseError(originalError: e));
    }
  }

  /// Signs in with Google Play Games on Android.
  ///
  /// Returns an [AuthFailure] with `unsupported-platform` on non-Android
  /// platforms.
  Future<AuthResult> signInWithPlayGames() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const AuthFailure(
        AuthError(
          message: 'Play Games sign-in is only supported on Android.',
          code: 'unsupported-platform',
        ),
      );
    }

    try {
      final googleUser = await _playGamesSignIn.signIn();
      if (googleUser == null) {
        return const AuthFailure(
          AuthError(
            message: 'Sign-in was cancelled.',
            code: 'cancelled-popup-request',
          ),
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _fbAuth.signInWithCredential(credential);
      return AuthSuccess(JustFirebaseUser.fromFirebase(cred.user!));
    } on fb.FirebaseAuthException catch (e) {
      return AuthFailure(AuthError.fromFirebase(e));
    } catch (e) {
      return AuthFailure(UnknownFirebaseError(originalError: e));
    }
  }

  /// Signs in anonymously. Creates a new guest account if no anonymous session
  /// is currently active.
  Future<AuthResult> signInAnonymously() async {
    try {
      final cred = await _fbAuth.signInAnonymously();
      return AuthSuccess(JustFirebaseUser.fromFirebase(cred.user!));
    } on fb.FirebaseAuthException catch (e) {
      return AuthFailure(AuthError.fromFirebase(e));
    } catch (e) {
      return AuthFailure(UnknownFirebaseError(originalError: e));
    }
  }

  /// Signs out the current user and clears the persisted session.
  Future<void> signOut() async {
    try {
      await Future.wait([
        _fbAuth.signOut(),
        _googleSignIn.signOut(),
        _playGamesSignIn.signOut(),
      ]);
    } catch (e) {
      debugPrint('JustFirebaseAuth: sign-out error ($e)');
    }
    await _clearPersistedUser();
  }

  /// Sends a password-reset email to [email].
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _fbAuth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('JustFirebaseAuth: password reset failed (${e.code})');
    }
  }

  /// Returns a fresh ID token for the current user, or `null` if not signed in.
  ///
  /// Set [forceRefresh] to `true` to bypass the cached token.
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      return await _fbAuth.currentUser?.getIdToken(forceRefresh);
    } catch (e) {
      debugPrint('JustFirebaseAuth: getIdToken failed ($e)');
      return null;
    }
  }

  /// Deletes the current user account. The user must have signed in recently.
  Future<AuthResult?> deleteAccount() async {
    final user = _fbAuth.currentUser;
    if (user == null) return null;
    try {
      await user.delete();
      await _clearPersistedUser();
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return AuthFailure(AuthError.fromFirebase(e));
    } catch (e) {
      return AuthFailure(UnknownFirebaseError(originalError: e));
    }
  }

  // ── Rate limiting ─────────────────────────────────────────────────────────

  AuthError? _checkRateLimit(String email) {
    final entry = _rateLimitMap[email];
    if (entry == null) return null;
    final (count, windowStart) = entry;
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowMs = _config.authRetryWindowSeconds * 1000;
    if (now - windowStart > windowMs) {
      _rateLimitMap.remove(email);
      return null;
    }
    if (count >= _config.authMaxRetries) {
      final elapsed = now - windowStart;
      final remaining = ((windowMs - elapsed) / 1000).ceil();
      return AuthError.rateLimited(remaining);
    }
    return null;
  }

  void _recordFailedAttempt(String email) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = _rateLimitMap[email];
    if (entry == null) {
      _rateLimitMap[email] = (1, now);
    } else {
      final (count, windowStart) = entry;
      _rateLimitMap[email] = (count + 1, windowStart);
    }
  }

  void _clearRateLimit(String email) => _rateLimitMap.remove(email);

  // ── Persistence ───────────────────────────────────────────────────────────

  static final String _kUserKey = _hashKey('jf_auth_user');

  static String _hashKey(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Future<void> _persistUser(JustFirebaseUser user) async {
    try {
      await _secureStorage?.writeJson(_kUserKey, user, (u) => u.toJson());
    } catch (e) {
      debugPrint('JustFirebaseAuth: persist user failed ($e)');
    }
  }

  Future<void> _restorePersistedUser() async {
    try {
      final user = await _secureStorage?.readJson<JustFirebaseUser>(
        _kUserKey,
        JustFirebaseUser.fromJson,
      );
      if (user != null && _currentUser.value == null) {
        _currentUser.value = user;
        // Don't change authState here — wait for the Firebase stream to confirm.
      }
    } catch (e) {
      debugPrint('JustFirebaseAuth: restore user failed ($e)');
    }
  }

  Future<void> _clearPersistedUser() async {
    try {
      await _secureStorage?.delete(_kUserKey);
    } catch (e) {
      debugPrint('JustFirebaseAuth: clear persisted user failed ($e)');
    }
  }
}
