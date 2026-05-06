import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../analytics/analytics_manager.dart';
import '../auth/auth_manager.dart';
import '../firestore/firestore_manager.dart';
import '../remote_config/remote_config_manager.dart';
import 'firebase_config.dart';

/// Central coordinator for all just_firebase services.
///
/// Obtain the singleton via [FirebaseManager.instance] or the [FirebaseManager()]
/// factory constructor. Call [initialize] once at app startup before using any
/// sub-manager.
///
/// ```dart
/// await FirebaseManager().initialize(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
///
/// // Auth
/// final result = await FirebaseManager().auth.signInAnonymously();
///
/// // Firestore
/// final doc = await FirebaseManager().firestore.getDocument('users/uid');
///
/// // Remote Config
/// final value = FirebaseManager().remoteConfig.getString('feature_flag');
/// ```
class FirebaseManager {
  static FirebaseManager? _instance;

  static FirebaseManager get instance {
    _instance ??= FirebaseManager._internal();
    return _instance!;
  }

  factory FirebaseManager() => instance;

  FirebaseManager._internal();

  /// The auth sub-manager. Available after [initialize].
  late final JustFirebaseAuth auth;

  /// The Firestore sub-manager. Available after [initialize] when
  /// [JustFirebaseConfig.enableFirestore] is `true`.
  late final JustFirestore firestore;

  /// The analytics sub-manager. Available after [initialize] when
  /// [JustFirebaseConfig.enableAnalytics] is `true`.
  late final JustFirebaseAnalytics analytics;

  /// The remote config sub-manager. Available after [initialize] when
  /// [JustFirebaseConfig.enableRemoteConfig] is `true`.
  late final JustRemoteConfig remoteConfig;

  bool _initialized = false;

  /// Whether [initialize] has completed successfully.
  bool get isInitialized => _initialized;

  /// Initializes Firebase and all enabled sub-managers.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  ///
  /// [options] are the platform-specific Firebase connection parameters
  /// (typically `DefaultFirebaseOptions.currentPlatform` from the generated
  /// `firebase_options.dart`).
  Future<void> initialize({
    required FirebaseOptions options,
    JustFirebaseConfig config = const JustFirebaseConfig(),
  }) async {
    if (_initialized) return;

    await Firebase.initializeApp(options: options);

    auth = JustFirebaseAuth(config: config);
    firestore = JustFirestore(config: config);
    analytics = JustFirebaseAnalytics(config: config);
    remoteConfig = JustRemoteConfig(config: config);

    if (config.enableAuth) {
      await _safeInit('Auth', () => auth.initialize());
    }
    if (config.enableFirestore) {
      await _safeInit('Firestore', () => firestore.initialize());
    }
    if (config.enableAnalytics) {
      await _safeInit('Analytics', () => analytics.initialize());
    }
    if (config.enableRemoteConfig) {
      await _safeInit('RemoteConfig', () => remoteConfig.initialize());
    }

    _initialized = true;
  }

  /// Disposes all sub-managers and releases resources.
  ///
  /// After calling [dispose] the singleton is reset; [initialize] must be
  /// called again before using any sub-manager.
  void dispose() {
    if (!_initialized) return;
    auth.dispose();
    firestore.dispose();
    analytics.dispose();
    remoteConfig.dispose();
    _initialized = false;
    _instance = null;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _safeInit(String name, Future<void> Function() init) async {
    try {
      await init();
    } catch (e) {
      debugPrint('FirebaseManager: $name init failed ($e)');
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance?.dispose();
    _instance = null;
  }
}
