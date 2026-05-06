/// Configuration knobs for the [FirebaseManager] and its sub-managers.
///
/// All fields have sensible defaults; override only what your app needs.
///
/// ```dart
/// await FirebaseManager().initialize(
///   options: DefaultFirebaseOptions.currentPlatform,
///   config: const JustFirebaseConfig(
///     firestoreCacheTtl: Duration(hours: 2),
///     authMaxRetries: 3,
///   ),
/// );
/// ```
class JustFirebaseConfig {
  const JustFirebaseConfig({
    this.firestoreCacheTtl = const Duration(hours: 1),
    this.firestoreCacheDbName = 'jf_cache',
    this.authMaxRetries = 5,
    this.authRetryWindowSeconds = 900,
    this.remoteConfigMinFetchInterval = const Duration(hours: 12),
    this.enableAnalytics = true,
    this.enableRemoteConfig = true,
    this.enableFirestore = true,
    this.enableAuth = true,
  });

  /// How long a Firestore document stays fresh in the local cache before a
  /// network refresh is attempted.
  final Duration firestoreCacheTtl;

  /// Name of the just_database database used for the Firestore cache.
  final String firestoreCacheDbName;

  /// Maximum failed sign-in attempts before the account is temporarily blocked
  /// on the client side.
  final int authMaxRetries;

  /// Time window (seconds) over which [authMaxRetries] is counted.
  final int authRetryWindowSeconds;

  /// Minimum interval between Remote Config fetches.
  final Duration remoteConfigMinFetchInterval;

  /// Whether to enable Firebase Analytics. Setting to `false` is useful in
  /// debug builds or when the user has opted out of analytics.
  final bool enableAnalytics;

  /// Whether to initialize Remote Config.
  final bool enableRemoteConfig;

  /// Whether to initialize Firestore and the local cache.
  final bool enableFirestore;

  /// Whether to initialize Firebase Auth.
  final bool enableAuth;
}
