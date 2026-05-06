/// just_firebase — Firebase integration for the just ecosystem.
///
/// Provides Auth, Cloud Firestore, Analytics, and Remote Config with:
/// - Reactive [Signal] API via just_signals
/// - Secure token persistence via just_storage (AES-256-GCM)
/// - Offline-first Firestore caching via just_database
/// - Client-side rate limiting and error masking
///
/// ## Quick start
///
/// ```dart
/// // At app startup (after Firebase options are generated):
/// await FirebaseManager().initialize(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
///
/// // Auth
/// final result = await FirebaseManager().auth.signInWithEmail(
///   email, password,
/// );
/// switch (result) {
///   case AuthSuccess(:final user): print('Signed in: ${user.uid}');
///   case AuthFailure(:final error): print('Error: ${error.message}');
/// }
///
/// // Firestore
/// final doc = await FirebaseManager().firestore.getDocument('users/uid');
///
/// // Remote Config
/// final maxLevel = FirebaseManager().remoteConfig.getInt('max_level');
///
/// // Analytics
/// await FirebaseManager().analytics.logLevelStart(1);
/// ```
library;

// Core
export 'src/core/firebase_manager.dart';
export 'src/core/firebase_config.dart';
export 'src/core/firebase_error.dart';

// Auth
export 'src/auth/auth_manager.dart';
export 'src/auth/auth_user.dart';
export 'src/auth/auth_state.dart';

// Firestore
export 'src/firestore/firestore_manager.dart';
export 'src/firestore/firestore_document.dart';
export 'src/firestore/firestore_query.dart';
// firestore_cache is an implementation detail — not exported

// Analytics
export 'src/analytics/analytics_manager.dart';

// Remote Config
export 'src/remote_config/remote_config_manager.dart';
