// Smoke test: verifies that the just_firebase barrel export resolves cleanly.
// Full test suites are in their own subdirectories:
//   test/auth/
//   test/firestore/
//   test/remote_config/

import 'package:flutter_test/flutter_test.dart';
import 'package:just_firebase/just_firebase.dart';

void main() {
  test('FirebaseManager singleton is accessible', () {
    // This only verifies the public API surface compiles and the singleton
    // is reachable — no Firebase connection is needed.
    final manager = FirebaseManager();
    expect(manager.isInitialized, isFalse);
    FirebaseManager.resetForTesting();
  });
}
