# Just Firebase

Firebase integration for the **just ecosystem** — Auth, Cloud Firestore, Analytics, and Remote Config, wrapped with reactive signals, secure token persistence, and offline-first caching.

---

## Features

| Module | Highlights |
|---|---|
| **Auth** | Email/password, Google, Play Games, anonymous sign-in; client-side rate limiting; secure session persistence via AES-256-GCM |
| **Firestore** | Offline-first reads with configurable TTL cache; reactive `Signal` bindings; atomic batch writes; fluent query builder |
| **Analytics** | Safe wrapper with platform guards (no-ops on desktop); convenience helpers for common game events |
| **Remote Config** | Typed accessors; reactive `Signal<T>` watchers; configurable minimum fetch interval |

All modules use [`just_signals`](https://pub.dev/packages/just_signals) for reactive state and expose errors through a sealed `JustFirebaseError` hierarchy so you can exhaustively handle failures.

---

## Getting started

### 1. Add the dependency

```yaml
dependencies:
  just_firebase: ^0.1.0
```

### 2. Configure Firebase

Follow the [FlutterFire setup guide](https://firebase.flutter.dev/docs/overview) to add `google-services.json` / `GoogleService-Info.plist` and run `flutterfire configure` to generate `firebase_options.dart`.

### 3. Initialise at app startup

```dart
import 'package:just_firebase/just_firebase.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseManager().initialize(
    options: DefaultFirebaseOptions.currentPlatform,
    // Optional — override any default:
    config: const JustFirebaseConfig(
      firestoreCacheTtl: Duration(hours: 2),
      remoteConfigMinFetchInterval: Duration(hours: 6),
    ),
  );

  runApp(const MyApp());
}
```

---

## Usage

### Authentication

```dart
final auth = FirebaseManager().auth;

// Reactive state — rebuild UI automatically
SignalBuilder(
  signal: auth.authState,
  builder: (context, state, _) => switch (state) {
    AuthState.authenticated => const HomeScreen(),
    AuthState.unauthenticated => const LoginScreen(),
    _ => const SplashScreen(),
  },
);

// Sign in
final result = await auth.signInWithEmail(email, password);
switch (result) {
  case AuthSuccess(:final user):
    print('Welcome ${user.displayName ?? user.uid}');
  case AuthFailure(:final error):
    print('Sign-in failed: ${error.message}');
}

// Google / Play Games
await auth.signInWithGoogle();
await auth.signInWithPlayGames(); // Android only

// Sign out
await auth.signOut();
```

### Firestore

```dart
final db = FirebaseManager().firestore;

// Read a document (served from cache when fresh)
final doc = await db.getDocument('players/${auth.currentUser.value!.uid}');
if (doc != null && doc.exists) {
  final score = doc.get<int>('highScore') ?? 0;
}

// Reactive document binding
final scoreSignal = db.documentSignal<int>(
  'players/${uid}',
  (map) => map['highScore'] as int? ?? 0,
);

// Query a collection
final leaderboard = await db.getCollection(
  'players',
  query: const JustFirestoreQuery(
    filters: [
      JustFirestoreFilter('score', FilterOperator.isGreaterThan, 0),
    ],
    orderBy: [JustFirestoreOrderBy('score', OrderDirection.descending)],
    limit: 10,
  ),
);

// Write / update
await db.setDocument('players/$uid', {'highScore': 9999});
await db.updateDocument('players/$uid', {'lastSeen': DateTime.now().toIso8601String()});

// Atomic batch
final batch = db.batch()
  ..set('players/$uid', {'active': true})
  ..update('stats/global', {'totalPlayers': 1});
await batch.commit();
```

### Remote Config

```dart
final rc = FirebaseManager().remoteConfig;

// Set in-app defaults before initialise
rc.setDefaults({
  'max_level': 50,
  'ads_enabled': true,
  'welcome_message': 'Welcome!',
});

// Fetch latest values
await rc.fetchAndActivate();

// Typed reads
final maxLevel = rc.getInt('max_level');
final adsEnabled = rc.getBool('ads_enabled');

// Reactive watcher — rebuilds on every fetch-and-activate
final maxLevelSignal = rc.watch<int>('max_level', 50, (v) => v.asInt());
```

### Analytics

```dart
final analytics = FirebaseManager().analytics;

await analytics.setUserId(uid);
await analytics.logLogin('email');
await analytics.logLevelStart(1);
await analytics.logLevelComplete(1, score: 4200);
await analytics.logEarnVirtualCurrency(currencyName: 'coins', value: 100);

// Custom event
await analytics.logEvent('tutorial_skip', parameters: {'step': 3});
```

---

## Configuration reference

`JustFirebaseConfig` accepts the following parameters (all optional):

| Parameter | Default | Description |
|---|---|---|
| `firestoreCacheTtl` | `Duration(hours: 1)` | How long a cached document is considered fresh |
| `firestoreCacheDbName` | `'jf_cache'` | Local SQLite database name for the Firestore cache |
| `authMaxRetries` | `5` | Failed sign-in attempts before rate-limiting kicks in |
| `authRetryWindowSeconds` | `900` | Sliding window (seconds) for the retry counter |
| `remoteConfigMinFetchInterval` | `Duration(hours: 12)` | Minimum time between Remote Config fetches |
| `enableAuth` | `true` | Disable to skip initialising the Auth module |
| `enableFirestore` | `true` | Disable to skip initialising the Firestore module |
| `enableAnalytics` | `true` | Disable to skip initialising the Analytics module |
| `enableRemoteConfig` | `true` | Disable to skip initialising the Remote Config module |

---

## Error handling

All write and sign-in methods return either a result type or a nullable `JustFirebaseError`. Errors are sealed so you can switch exhaustively:

```dart
final error = await db.setDocument('players/$uid', data);
if (error != null) {
  switch (error) {
    case AuthError(:final retryAfterSeconds):
      showRetryBanner(retryAfterSeconds);
    case NetworkError():
      showOfflineBanner();
    default:
      log(error.message);
  }
}
```

---

## Additional information

- **Contributing:** see [CONTRIBUTING.md](CONTRIBUTING.md)
- **Issues:** open an issue on the [GitHub repository](https://github.com/just-unknown-dev/just-firebase/issues)
- **Licence:** BSD-3-Clause
