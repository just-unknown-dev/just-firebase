// ignore_for_file: avoid_print

/// just_firebase — complete usage example
///
/// Demonstrates initialisation and every public API:
///   - FirebaseManager setup with JustFirebaseConfig
///   - Auth (email, Google, anonymous)
///   - Firestore (reads, writes, query, batch, reactive signal)
///   - Remote Config (defaults, fetch, typed accessors, watcher)
///   - Analytics (standard helpers + custom event)
///
/// This file is intentionally self-contained and does NOT import Flutter
/// widgets so it can be read without running a full app.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:just_firebase/just_firebase.dart';

// ---------------------------------------------------------------------------
// Stub FirebaseOptions — replace with DefaultFirebaseOptions.currentPlatform
// from your generated firebase_options.dart.
// ---------------------------------------------------------------------------
final _firebaseOptions = const FirebaseOptions(
  apiKey: 'YOUR_API_KEY',
  appId: 'YOUR_APP_ID',
  messagingSenderId: 'YOUR_SENDER_ID',
  projectId: 'YOUR_PROJECT_ID',
);

// ---------------------------------------------------------------------------
// 1. Initialise
// ---------------------------------------------------------------------------
Future<void> initFirebase() async {
  await FirebaseManager().initialize(
    options: _firebaseOptions,
    config: const JustFirebaseConfig(
      // Cache Firestore documents for two hours instead of the default one.
      firestoreCacheTtl: Duration(hours: 2),
      // Fetch Remote Config at most once every six hours.
      remoteConfigMinFetchInterval: Duration(hours: 6),
      // Allow up to 3 failed sign-ins per 5-minute window.
      authMaxRetries: 3,
      authRetryWindowSeconds: 300,
    ),
  );

  print('Firebase ready: ${FirebaseManager().isInitialized}');
}

// ---------------------------------------------------------------------------
// 2. Auth
// ---------------------------------------------------------------------------
Future<void> authExample() async {
  final auth = FirebaseManager().auth;

  // --- Email / password sign-up ---
  final signUpResult = await auth.signUpWithEmail(
    'player@example.com',
    's3cureP@ssword',
    displayName: 'Player One',
  );

  switch (signUpResult) {
    case AuthSuccess(:final user):
      print('Signed up: uid=${user.uid}  name=${user.displayName}');
    case AuthFailure(:final error):
      print('Sign-up failed [${error.code}]: ${error.message}');
      return;
  }

  // --- Email / password sign-in ---
  final signInResult = await auth.signInWithEmail(
    'player@example.com',
    's3cureP@ssword',
  );
  if (signInResult case AuthSuccess(:final user)) {
    print('Signed in: ${user.email}  verified=${user.isEmailVerified}');
  }

  // --- Google sign-in ---
  final googleResult = await auth.signInWithGoogle();
  if (googleResult case AuthFailure(:final error)) {
    print('Google sign-in failed: ${error.message}');
  }

  // --- Anonymous sign-in (useful for guests) ---
  await auth.signInAnonymously();

  // --- Reactive state ---
  // authState is a Signal<AuthState>; subscribe via just_signals or
  // wrap in a SignalBuilder widget in your UI layer.
  print('Auth state: ${auth.authState.value}');
  print('Current user: ${auth.currentUser.value?.uid}');

  // --- Password reset ---
  await auth.sendPasswordResetEmail('player@example.com');

  // --- Get ID token (e.g. for backend verification) ---
  final token = await auth.getIdToken(forceRefresh: true);
  print('ID token length: ${token?.length}');

  // --- Sign out ---
  await auth.signOut();
  print('Signed out. State: ${auth.authState.value}');
}

// ---------------------------------------------------------------------------
// 3. Firestore
// ---------------------------------------------------------------------------
Future<void> firestoreExample(String uid) async {
  final db = FirebaseManager().firestore;

  // --- Write a document ---
  final writeError = await db.setDocument('players/$uid', {
    'displayName': 'Player One',
    'highScore': 0,
    'level': 1,
  });
  if (writeError != null) {
    print('Write error: ${writeError.message}');
    return;
  }

  // --- Read a document (cache-first) ---
  final doc = await db.getDocument('players/$uid');
  if (doc != null && doc.exists) {
    final score = doc.get<int>('highScore') ?? 0;
    print('High score: $score  (fromCache=${doc.fromCache})');
  }

  // --- Force a network refresh ---
  final fresh = await db.getDocument('players/$uid', forceRefresh: true);
  print('Fresh fetch at: ${fresh?.fetchedAt}');

  // --- Partial update ---
  await db.updateDocument('players/$uid', {'highScore': 9999});

  // --- Collection query with filter + sort + limit ---
  final leaderboard = await db.getCollection(
    'players',
    query: const JustFirestoreQuery(
      filters: [
        JustFirestoreFilter('highScore', FilterOperator.isGreaterThan, 0),
      ],
      orderBy: [JustFirestoreOrderBy('highScore', OrderDirection.descending)],
      limit: 10,
    ),
  );
  print('Top ${leaderboard.length} players fetched');

  // --- Real-time stream ---
  final stream = db.watchDocument('players/$uid');
  final subscription = stream.listen((snap) {
    print('Live update: ${snap?.data}');
  });
  // Remember to cancel in your dispose logic.
  await subscription.cancel();

  // --- Reactive Signal binding ---
  final highScoreSignal = db.documentSignal<int>(
    'players/$uid',
    (map) => map['highScore'] as int? ?? 0,
  );
  print('Signal value: ${highScoreSignal.value}');

  // --- Atomic batch ---
  final batchError =
      await (db.batch()
            ..set('players/$uid', {'active': true}, merge: true)
            ..update('stats/global', {'activePlayers': 1})
            ..delete('temp/placeholder'))
          .commit();
  if (batchError != null) print('Batch error: ${batchError.message}');

  // --- Delete ---
  await db.deleteDocument('temp/placeholder');
}

// ---------------------------------------------------------------------------
// 4. Remote Config
// ---------------------------------------------------------------------------
Future<void> remoteConfigExample() async {
  final rc = FirebaseManager().remoteConfig;

  // Set safe in-app defaults before the first fetch resolves.
  rc.setDefaults({
    'max_level': 50,
    'ads_enabled': true,
    'welcome_message': 'Welcome!',
    'boss_speed_multiplier': 1.0,
  });

  // Fetch and activate the latest server values.
  await rc.fetchAndActivate();

  // Typed accessors.
  final maxLevel = rc.getInt('max_level');
  final adsEnabled = rc.getBool('ads_enabled');
  final welcomeMsg = rc.getString('welcome_message');
  final bossSpeed = rc.getDouble('boss_speed_multiplier');
  print(
    'Config: maxLevel=$maxLevel  ads=$adsEnabled  boss=$bossSpeed  msg="$welcomeMsg"',
  );

  // Reactive watcher — value updates automatically after each fetchAndActivate.
  final maxLevelSignal = rc.watch<int>('max_level', 50, (v) => v.asInt());
  print('maxLevel signal: ${maxLevelSignal.value}');

  // All active values as a single signal (useful for diagnostics).
  print('All config keys: ${rc.configSignal.value.keys.join(', ')}');
}

// ---------------------------------------------------------------------------
// 5. Analytics
// ---------------------------------------------------------------------------
Future<void> analyticsExample(String uid) async {
  final analytics = FirebaseManager().analytics;

  // Identify the user.
  await analytics.setUserId(uid);
  await analytics.setUserProperty(name: 'preferred_ship', value: 'cruiser');

  // Screen tracking.
  await analytics.logScreenView(screenName: 'MainMenu');

  // Auth events.
  await analytics.logLogin('email');
  await analytics.logSignUp('google');

  // Game events.
  await analytics.logLevelStart(1);
  await analytics.logLevelComplete(1, score: 4200);
  await analytics.logEarnVirtualCurrency(currencyName: 'coins', value: 100);

  // Arbitrary custom event.
  await analytics.logEvent('tutorial_skip', parameters: {'step': 3});

  // Disable collection (e.g. user opted out).
  await analytics.setEnabled(false);
}

// ---------------------------------------------------------------------------
// 6. Error handling — exhaustive switch on the sealed hierarchy
// ---------------------------------------------------------------------------
Future<void> errorHandlingExample(String uid) async {
  final error = await FirebaseManager().firestore.setDocument('players/$uid', {
    'score': -1,
  });

  if (error == null) return; // success

  switch (error) {
    case AuthError(:final retryAfterSeconds):
      print('Auth error — retry in ${retryAfterSeconds}s');
    case FirestoreError():
      print('Firestore error [${error.code}]: ${error.message}');
    case NetworkError():
      print('No network — queued for later');
    case RemoteConfigError():
      print('Remote Config error: ${error.message}');
    case UnknownFirebaseError():
      print('Unknown error: ${error.originalError}');
  }
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
Future<void> main() async {
  await initFirebase();

  await authExample();

  // Use a dummy UID for the remaining examples.
  const uid = 'example_uid_123';

  await firestoreExample(uid);
  await remoteConfigExample();
  await analyticsExample(uid);
  await errorHandlingExample(uid);

  FirebaseManager().dispose();
  print('Done.');
}
