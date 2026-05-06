## 0.1.0

Initial release.

### Features

- **`FirebaseManager`** — singleton coordinator that initialises all modules in one call; exposes `isInitialized` guard and a top-level `dispose()`.
- **`JustFirebaseConfig`** — immutable configuration for every sub-manager (cache TTL, rate-limit windows, minimum fetch intervals, per-module enable flags).
- **Auth (`JustFirebaseAuth`)**
  - Email/password sign-up and sign-in.
  - Google Sign-In and Play Games sign-in (Android).
  - Anonymous sign-in.
  - Password reset email.
  - ID-token retrieval with optional force-refresh.
  - Account deletion.
  - Client-side rate limiting (configurable retry count and sliding window).
  - Secure session persistence via `just_storage` (AES-256-GCM).
  - Reactive `Signal<AuthState>` and `Signal<JustFirebaseUser?>` via `just_signals`.
- **Firestore (`JustFirestore`)**
  - Offline-first document reads with configurable TTL cache (backed by `just_database`).
  - `getDocument` / `watchDocument` / `documentSignal` for single documents.
  - `getCollection` / `watchCollection` for collections.
  - Fluent query builder: `JustFirestoreQuery` with `JustFirestoreFilter`, `JustFirestoreOrderBy`, and pagination cursor support.
  - `setDocument`, `updateDocument`, `deleteDocument` writes.
  - Atomic `JustFirestoreBatch` for grouped writes.
- **Remote Config (`JustRemoteConfig`)**
  - In-app defaults via `setDefaults`.
  - `fetchAndActivate` with configurable minimum fetch interval.
  - Typed accessors: `getString`, `getBool`, `getInt`, `getDouble`.
  - Reactive `Signal<T>` watcher via `watch<T>`.
  - `configSignal` exposing all active values as a `Map`.
- **Analytics (`JustFirebaseAnalytics`)**
  - Platform-safe wrapper (all methods are no-ops on Windows, Linux, and macOS).
  - `logEvent`, `setUserId`, `setUserProperty`, `logScreenView`, `setEnabled`.
  - Convenience helpers: `logLogin`, `logSignUp`, `logLevelStart`, `logLevelComplete`, `logEarnVirtualCurrency`.
- **Error hierarchy** — sealed `JustFirebaseError` with typed subclasses `AuthError`, `FirestoreError`, `RemoteConfigError`, `NetworkError`, and `UnknownFirebaseError` for exhaustive error handling.
