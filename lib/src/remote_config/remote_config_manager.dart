import 'package:firebase_remote_config/firebase_remote_config.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:just_signals/just_signals.dart';

import '../core/firebase_config.dart';

/// Manages Firebase Remote Config with reactive signal support.
///
/// Register default values with [setDefaults] before calling [initialize].
/// After initialization, use [getString], [getBool], [getInt], or [getDouble]
/// to read values synchronously, or [watch] to bind a [Signal] that updates
/// whenever the config is re-fetched and activated.
///
/// ```dart
/// FirebaseManager().remoteConfig.setDefaults({
///   'feature_new_ui': false,
///   'max_level': 50,
/// });
///
/// await FirebaseManager().initialize(options: ...);
///
/// // Reactive
/// final featureEnabled = FirebaseManager().remoteConfig
///     .watch('feature_new_ui', false, (v) => v.asBool());
///
/// // One-shot
/// final maxLevel = FirebaseManager().remoteConfig.getInt('max_level');
/// ```
class JustRemoteConfig {
  JustRemoteConfig({required JustFirebaseConfig config}) : _config = config;

  final JustFirebaseConfig _config;
  fb.FirebaseRemoteConfig? _rc;

  Map<String, dynamic> _defaults = {};

  final Signal<Map<String, dynamic>> _configSignal = Signal(
    const {},
    debugLabel: 'firebase.remoteConfig',
  );

  // Stores refresh callbacks for each watch signal, keyed by config key.
  final Map<String, _WatchEntry> _watchEntries = {};

  /// Reactive map of all currently active Remote Config values.
  Signal<Map<String, dynamic>> get configSignal => _configSignal;

  // ── Setup (call before initialize) ───────────────────────────────────────

  /// Registers default values used before the first successful fetch.
  ///
  /// Defaults are also used as fallbacks when the key is not present in the
  /// remote config. Safe to call multiple times — later calls merge.
  void setDefaults(Map<String, dynamic> defaults) {
    _defaults = {..._defaults, ...defaults};
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      _rc = fb.FirebaseRemoteConfig.instance;

      await _rc!.setConfigSettings(
        fb.RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: _config.remoteConfigMinFetchInterval,
        ),
      );

      if (_defaults.isNotEmpty) {
        await _rc!.setDefaults(_defaults);
      }

      await _rc!.fetchAndActivate();
      _updateSignals();

      // Listen for real-time config updates (requires Firebase Remote Config
      // real-time feature to be enabled in the Firebase console).
      _rc!.onConfigUpdated.listen(
        (_) async {
          try {
            await _rc!.activate();
            _updateSignals();
          } catch (e) {
            debugPrint('JustRemoteConfig: activate on update failed ($e)');
          }
        },
        onError: (Object e) {
          debugPrint('JustRemoteConfig: onConfigUpdated error ($e)');
        },
      );
    } catch (e) {
      debugPrint('JustRemoteConfig: initialize failed ($e)');
    }
  }

  void dispose() {
    _watchEntries.clear();
    _rc = null;
  }

  // ── Fetch & Activate ─────────────────────────────────────────────────────

  /// Manually fetches and activates the latest config.
  Future<void> fetchAndActivate({
    Duration minimumInterval = const Duration(hours: 12),
  }) async {
    final rc = _rc;
    if (rc == null) return;
    try {
      await rc.setConfigSettings(
        fb.RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: minimumInterval,
        ),
      );
      await rc.fetchAndActivate();
      _updateSignals();
    } catch (e) {
      debugPrint('JustRemoteConfig: fetchAndActivate failed ($e)');
    }
  }

  // ── Typed accessors ───────────────────────────────────────────────────────

  /// Returns the string value for [key], or [defaultValue] if absent.
  String getString(String key, {String defaultValue = ''}) {
    try {
      return _rc?.getString(key) ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  /// Returns the bool value for [key], or [defaultValue] if absent.
  bool getBool(String key, {bool defaultValue = false}) {
    try {
      return _rc?.getBool(key) ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  /// Returns the int value for [key], or [defaultValue] if absent.
  int getInt(String key, {int defaultValue = 0}) {
    try {
      return _rc?.getInt(key) ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  /// Returns the double value for [key], or [defaultValue] if absent.
  double getDouble(String key, {double defaultValue = 0.0}) {
    try {
      return _rc?.getDouble(key) ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  // ── Reactive watch ────────────────────────────────────────────────────────

  /// Returns a [Signal] that holds the current value for [key] and updates
  /// automatically whenever [fetchAndActivate] succeeds.
  ///
  /// [parse] converts the raw [fb.RemoteConfigValue] to your desired type [T].
  ///
  /// ```dart
  /// final enabled = remoteConfig.watch(
  ///   'new_ui',
  ///   false,
  ///   (v) => v.asBool(),
  /// );
  /// ```
  Signal<T> watch<T>(
    String key,
    T defaultValue,
    T Function(fb.RemoteConfigValue) parse,
  ) {
    if (_watchEntries.containsKey(key)) {
      return _watchEntries[key]!.signal as Signal<T>;
    }

    T current = defaultValue;
    try {
      final rc = _rc;
      if (rc != null) current = parse(rc.getValue(key));
    } catch (_) {}

    final signal = Signal<T>(current, debugLabel: 'remoteConfig.$key');
    _watchEntries[key] = _WatchEntry(
      signal: signal,
      refresh: () {
        try {
          final rc = _rc;
          if (rc == null) return;
          signal.value = parse(rc.getValue(key));
        } catch (_) {}
      },
    );

    return signal;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _updateSignals() {
    final rc = _rc;
    if (rc == null) return;
    try {
      final all = rc.getAll();
      final snapshot = all.map((k, v) => MapEntry(k, v.asString()));
      _configSignal.value = snapshot;

      for (final entry in _watchEntries.values) {
        entry.refresh();
      }
    } catch (e) {
      debugPrint('JustRemoteConfig: _updateSignals failed ($e)');
    }
  }
}

class _WatchEntry {
  const _WatchEntry({required this.signal, required this.refresh});

  final Signal<dynamic> signal;
  final VoidCallback refresh;
}
