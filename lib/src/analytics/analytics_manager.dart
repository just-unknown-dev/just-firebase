import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart' as fb;
import 'package:flutter/foundation.dart';

import '../core/firebase_config.dart';

/// Wraps Firebase Analytics with graceful no-ops on unsupported platforms.
///
/// Analytics is not available on desktop platforms (Windows, Linux, macOS).
/// All methods silently succeed on those platforms rather than throwing.
///
/// Obtain via [FirebaseManager().analytics] after initialization.
class JustFirebaseAnalytics {
  JustFirebaseAnalytics({required JustFirebaseConfig config})
    : _enabled = config.enableAnalytics;

  final bool _enabled;
  fb.FirebaseAnalytics? _analytics;

  bool get _isSupported {
    if (!_enabled) return false;
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (!_isSupported) return;
    try {
      _analytics = fb.FirebaseAnalytics.instance;
    } catch (e) {
      debugPrint('JustFirebaseAnalytics: init failed ($e)');
    }
  }

  void dispose() {
    _analytics = null;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Logs a custom event with optional [parameters].
  ///
  /// Event names must be 1–40 characters; alphanumeric and underscores only.
  Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (!_isSupported || _analytics == null) return;
    try {
      await _analytics!.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('JustFirebaseAnalytics: logEvent failed ($e)');
    }
  }

  /// Sets the user ID for attribution. Pass `null` to clear.
  Future<void> setUserId(String? id) async {
    if (!_isSupported || _analytics == null) return;
    try {
      await _analytics!.setUserId(id: id);
    } catch (e) {
      debugPrint('JustFirebaseAnalytics: setUserId failed ($e)');
    }
  }

  /// Sets a custom user property. Pass `null` as [value] to clear.
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (!_isSupported || _analytics == null) return;
    try {
      await _analytics!.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('JustFirebaseAnalytics: setUserProperty failed ($e)');
    }
  }

  /// Logs a screen view event.
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_isSupported || _analytics == null) return;
    try {
      await _analytics!.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (e) {
      debugPrint('JustFirebaseAnalytics: logScreenView failed ($e)');
    }
  }

  /// Enables or disables analytics data collection.
  ///
  /// When disabled, no data is sent to Firebase. Persists across app restarts.
  Future<void> setEnabled(bool enabled) async {
    if (!_isSupported || _analytics == null) return;
    try {
      await _analytics!.setAnalyticsCollectionEnabled(enabled);
    } catch (e) {
      debugPrint('JustFirebaseAnalytics: setEnabled failed ($e)');
    }
  }

  // ── Convenience event helpers ─────────────────────────────────────────────

  /// Logs a login event with the given [method].
  Future<void> logLogin(String method) => logEvent(
    'login',
    parameters: {'method': method},
  );

  /// Logs a sign-up event with the given [method].
  Future<void> logSignUp(String method) => logEvent(
    'sign_up',
    parameters: {'method': method},
  );

  /// Logs a level start event.
  Future<void> logLevelStart(int level) => logEvent(
    'level_start',
    parameters: {'level': level},
  );

  /// Logs a level complete event with optional [score].
  Future<void> logLevelComplete(int level, {int? score}) {
    final params = <String, Object>{'level': level, 'success': true};
    if (score != null) params['score'] = score;
    return logEvent('level_end', parameters: params);
  }

  /// Logs a purchase or reward event.
  Future<void> logEarnVirtualCurrency({
    required String currencyName,
    required int value,
  }) => logEvent(
    'earn_virtual_currency',
    parameters: {'virtual_currency_name': currencyName, 'value': value},
  );
}
