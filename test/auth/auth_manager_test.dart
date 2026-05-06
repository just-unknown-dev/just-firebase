import 'package:flutter_test/flutter_test.dart';
import 'package:just_firebase/just_firebase.dart';

void main() {
  group('AuthState', () {
    test('has all expected values', () {
      expect(AuthState.values, containsAll([
        AuthState.unknown,
        AuthState.loading,
        AuthState.authenticated,
        AuthState.unauthenticated,
      ]));
    });
  });

  group('AuthResult sealed class', () {
    test('AuthSuccess holds user', () {
      const user = _fakeUser;
      const result = AuthSuccess(user);
      expect(result.user.uid, equals('test-uid'));
    });

    test('AuthFailure holds error', () {
      const error = AuthError(message: 'Test error', code: 'test/error');
      const result = AuthFailure(error);
      expect(result.error.message, equals('Test error'));
    });

    test('can switch on sealed result', () {
      const AuthResult result = AuthSuccess(_fakeUser);
      final message = switch (result) {
        AuthSuccess(:final user) => 'ok:${user.uid}',
        AuthFailure(:final error) => 'err:${error.code}',
      };
      expect(message, equals('ok:test-uid'));
    });
  });

  group('JustFirebaseUser', () {
    test('fromJson / toJson round-trips correctly', () {
      const user = _fakeUser;
      final json = user.toJson();
      final restored = JustFirebaseUser.fromJson(json);

      expect(restored.uid, equals(user.uid));
      expect(restored.email, equals(user.email));
      expect(restored.isAnonymous, equals(user.isAnonymous));
      expect(restored.displayName, equals(user.displayName));
      expect(restored.isEmailVerified, equals(user.isEmailVerified));
    });

    test('equality is based on uid', () {
      const a = _fakeUser;
      final b = JustFirebaseUser.fromJson(a.toJson());
      expect(a, equals(b));
    });

    test('copyWith preserves unchanged fields', () {
      const user = _fakeUser;
      final updated = user.copyWith(displayName: 'Updated');
      expect(updated.uid, equals(user.uid));
      expect(updated.email, equals(user.email));
      expect(updated.displayName, equals('Updated'));
    });
  });

  group('JustFirebaseError sealed class', () {
    test('AuthError.rateLimited sets retryAfterSeconds', () {
      final err = AuthError.rateLimited(60);
      expect(err.code, equals('auth/too-many-requests'));
      expect(err.retryAfterSeconds, equals(60));
    });

    test('NetworkError has sensible defaults', () {
      const err = NetworkError();
      expect(err.code, equals('network/unavailable'));
      expect(err.message, isNotEmpty);
    });

    test('UnknownFirebaseError wraps original', () {
      final original = Exception('raw');
      final err = UnknownFirebaseError(originalError: original);
      expect(err.originalError, same(original));
      expect(err.message, isNotEmpty);
    });
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

const _fakeUser = _FakeUser();

class _FakeUser implements JustFirebaseUser {
  const _FakeUser();

  @override
  String get uid => 'test-uid';

  @override
  bool get isAnonymous => false;

  @override
  String? get email => 'test@example.com';

  @override
  String? get displayName => 'Test User';

  @override
  String? get photoUrl => null;

  @override
  bool get isEmailVerified => true;

  @override
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'isAnonymous': isAnonymous,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'isEmailVerified': isEmailVerified,
  };

  @override
  JustFirebaseUser copyWith({
    String? displayName,
    String? photoUrl,
    bool? isEmailVerified,
  }) => JustFirebaseUser.fromJson({
    ...toJson(),
    'displayName': ?displayName,
    'photoUrl': ?photoUrl,
    'isEmailVerified': ?isEmailVerified,
  });

  @override
  bool operator ==(Object other) =>
      other is JustFirebaseUser && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'FakeUser($uid)';
}
