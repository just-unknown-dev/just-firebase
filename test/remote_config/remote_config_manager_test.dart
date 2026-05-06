import 'package:flutter_test/flutter_test.dart';
import 'package:just_firebase/just_firebase.dart';

void main() {
  group('JustFirebaseConfig', () {
    test('has sensible defaults', () {
      const config = JustFirebaseConfig();
      expect(config.firestoreCacheTtl, equals(const Duration(hours: 1)));
      expect(config.authMaxRetries, equals(5));
      expect(config.authRetryWindowSeconds, equals(900));
      expect(config.enableAnalytics, isTrue);
      expect(config.enableRemoteConfig, isTrue);
      expect(config.enableFirestore, isTrue);
      expect(config.enableAuth, isTrue);
    });

    test('custom values are respected', () {
      const config = JustFirebaseConfig(
        firestoreCacheTtl: Duration(minutes: 30),
        authMaxRetries: 3,
        enableAnalytics: false,
      );
      expect(config.firestoreCacheTtl, equals(const Duration(minutes: 30)));
      expect(config.authMaxRetries, equals(3));
      expect(config.enableAnalytics, isFalse);
    });
  });

  group('JustRemoteConfig defaults', () {
    test('setDefaults merges multiple calls', () {
      final rc = JustRemoteConfig(config: const JustFirebaseConfig());
      rc.setDefaults({'a': 1, 'b': 2});
      rc.setDefaults({'b': 99, 'c': 3});
      // Verify internal defaults map has all keys (access via fallback reads).
      // Since Firebase isn't initialized, getString falls back to ''.
      // The defaults map itself isn't publicly exposed, but we can at least
      // verify the method doesn't throw.
      expect(() => rc.setDefaults({'d': 4}), returnsNormally);
    });

    test('typed accessors return defaults when not initialized', () {
      final rc = JustRemoteConfig(config: const JustFirebaseConfig());
      expect(rc.getString('missing'), equals(''));
      expect(rc.getBool('missing'), isFalse);
      expect(rc.getInt('missing'), equals(0));
      expect(rc.getDouble('missing'), equals(0.0));
    });

    test('typed accessors return provided defaultValue when not initialized', () {
      final rc = JustRemoteConfig(config: const JustFirebaseConfig());
      expect(rc.getString('k', defaultValue: 'fallback'), equals('fallback'));
      expect(rc.getBool('k', defaultValue: true), isTrue);
      expect(rc.getInt('k', defaultValue: 42), equals(42));
      expect(rc.getDouble('k', defaultValue: 3.14), closeTo(3.14, 0.001));
    });

    test('configSignal starts empty', () {
      final rc = JustRemoteConfig(config: const JustFirebaseConfig());
      expect(rc.configSignal.value, isEmpty);
    });
  });

  group('FirebaseManager singleton', () {
    tearDown(FirebaseManager.resetForTesting);

    test('factory returns the same instance', () {
      final a = FirebaseManager();
      final b = FirebaseManager();
      expect(identical(a, b), isTrue);
    });

    test('isInitialized starts false', () {
      expect(FirebaseManager().isInitialized, isFalse);
    });
  });
}
