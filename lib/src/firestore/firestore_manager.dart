import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:just_signals/just_signals.dart';

import '../core/firebase_config.dart';
import '../core/firebase_error.dart';
import 'firestore_cache.dart';
import 'firestore_document.dart';
import 'firestore_query.dart';

/// Manages Cloud Firestore reads and writes with an offline-first local cache.
///
/// All reads follow the strategy: memory cache → just_database → Firestore.
/// On network failure, stale cached data is served silently.
///
/// Obtain via [FirebaseManager().firestore] after initialization.
class JustFirestore {
  JustFirestore({required JustFirebaseConfig config}) : _config = config;

  final JustFirebaseConfig _config;
  final fb.FirebaseFirestore _fb = fb.FirebaseFirestore.instance;
  late final FirestoreCache _cache;

  // Active stream subscriptions keyed by document path, for dedup.
  final Map<String, StreamController<JustDocument?>> _docControllers = {};

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _cache = FirestoreCache(
      dbName: _config.firestoreCacheDbName,
      defaultTtl: _config.firestoreCacheTtl,
    );
    await _cache.initialize();
  }

  void dispose() {
    for (final c in _docControllers.values) {
      c.close();
    }
    _docControllers.clear();
    _cache.dispose();
  }

  // ── Document reads ────────────────────────────────────────────────────────

  /// Reads a single document from the cache or Firestore.
  ///
  /// Returns `null` when the document does not exist and there is no cached
  /// version. Set [forceRefresh] to bypass the local cache.
  Future<JustDocument?> getDocument(
    String path, {
    bool forceRefresh = false,
  }) async {
    _validatePath(path);

    if (!forceRefresh) {
      final cached = await _cache.get(path);
      if (cached != null) return cached;
    }

    try {
      final snap = await _fb.doc(path).get();
      if (!snap.exists) return null;
      final doc = JustDocument.fromFirebase(snap);
      unawaited(_cache.put(doc));
      return doc;
    } on fb.FirebaseException catch (e) {
      debugPrint('JustFirestore: getDocument failed ($e)');
      // Fall back to stale cache on network error.
      return _cache.getStale(path);
    } catch (e) {
      debugPrint('JustFirestore: getDocument unexpected error ($e)');
      return _cache.getStale(path);
    }
  }

  /// Returns a [Stream] that emits a new [JustDocument] snapshot each time
  /// the document changes in Firestore.
  ///
  /// Emits the cached version immediately while waiting for the first network
  /// snapshot. Each network snapshot is written to the cache.
  Stream<JustDocument?> watchDocument(String path) {
    _validatePath(path);

    if (_docControllers.containsKey(path)) {
      return _docControllers[path]!.stream;
    }

    final controller = StreamController<JustDocument?>.broadcast(
      onCancel: () => _docControllers.remove(path),
    );
    _docControllers[path] = controller;

    // Emit cached snapshot immediately.
    _cache.get(path).then((cached) {
      if (!controller.isClosed && cached != null) {
        controller.add(cached);
      }
    });

    // Subscribe to live updates.
    _fb.doc(path).snapshots().listen(
      (snap) {
        if (controller.isClosed) return;
        if (!snap.exists) {
          controller.add(null);
          return;
        }
        final doc = JustDocument.fromFirebase(snap);
        unawaited(_cache.put(doc));
        controller.add(doc);
      },
      onError: (Object e) {
        debugPrint('JustFirestore: watchDocument error for $path ($e)');
      },
    );

    return controller.stream;
  }

  /// Returns a [Signal] that stays in sync with a Firestore document.
  ///
  /// [fromMap] converts the raw field map to your model type [T].
  Signal<T?> documentSignal<T>(
    String path,
    T Function(Map<String, dynamic>) fromMap,
  ) {
    _validatePath(path);
    final signal = Signal<T?>(null, debugLabel: 'firestore.$path');
    watchDocument(path).listen((doc) {
      signal.value = doc != null ? fromMap(doc.data) : null;
    });
    return signal;
  }

  // ── Collection reads ──────────────────────────────────────────────────────

  /// Reads all documents in a collection that match the optional [query].
  Future<List<JustDocument>> getCollection(
    String path, {
    JustFirestoreQuery? query,
  }) async {
    _validatePath(path);
    try {
      final ref = _fb.collection(path);
      final fbQuery =
          query != null ? query.apply(ref) : ref;
      final snapshot = await fbQuery.get();
      final docs = snapshot.docs
          .map(JustDocument.fromFirebase)
          .toList();
      for (final doc in docs) {
        unawaited(_cache.put(doc));
      }
      return docs;
    } on fb.FirebaseException catch (e) {
      debugPrint('JustFirestore: getCollection failed ($e)');
      return [];
    } catch (e) {
      debugPrint('JustFirestore: getCollection unexpected error ($e)');
      return [];
    }
  }

  /// Returns a [Stream] of collection snapshots that re-emits on any change.
  Stream<List<JustDocument>> watchCollection(
    String path, {
    JustFirestoreQuery? query,
  }) {
    _validatePath(path);
    final ref = _fb.collection(path);
    final fbQuery =
        query != null ? query.apply(ref) : ref;

    return fbQuery.snapshots().map((snap) {
      final docs = snap.docs.map(JustDocument.fromFirebase).toList();
      for (final doc in docs) {
        unawaited(_cache.put(doc));
      }
      return docs;
    }).handleError((Object e) {
      debugPrint('JustFirestore: watchCollection error for $path ($e)');
    });
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Creates or overwrites a document at [path].
  ///
  /// Set [merge] to `true` to merge [data] into the existing document instead
  /// of overwriting it.
  Future<FirestoreError?> setDocument(
    String path,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    _validatePath(path);
    try {
      if (merge) {
        await _fb.doc(path).set(data, fb.SetOptions(merge: true));
      } else {
        await _fb.doc(path).set(data);
      }
      unawaited(_cache.invalidate(path));
      return null;
    } on fb.FirebaseException catch (e) {
      return FirestoreError.fromFirebase(e);
    } catch (e) {
      debugPrint('JustFirestore: setDocument unexpected error ($e)');
      return const FirestoreError(message: 'Failed to save data.');
    }
  }

  /// Updates specific fields in an existing document.
  Future<FirestoreError?> updateDocument(
    String path,
    Map<String, dynamic> data,
  ) async {
    _validatePath(path);
    try {
      await _fb.doc(path).update(data);
      unawaited(_cache.invalidate(path));
      return null;
    } on fb.FirebaseException catch (e) {
      return FirestoreError.fromFirebase(e);
    } catch (e) {
      debugPrint('JustFirestore: updateDocument unexpected error ($e)');
      return const FirestoreError(message: 'Failed to update data.');
    }
  }

  /// Deletes a document. Silently succeeds if the document does not exist.
  Future<FirestoreError?> deleteDocument(String path) async {
    _validatePath(path);
    try {
      await _fb.doc(path).delete();
      unawaited(_cache.invalidate(path));
      return null;
    } on fb.FirebaseException catch (e) {
      return FirestoreError.fromFirebase(e);
    } catch (e) {
      debugPrint('JustFirestore: deleteDocument unexpected error ($e)');
      return const FirestoreError(message: 'Failed to delete data.');
    }
  }

  /// Returns a [JustFirestoreBatch] for grouped atomic writes.
  JustFirestoreBatch batch() => JustFirestoreBatch(_fb.batch(), _cache);

  // ── Validation ────────────────────────────────────────────────────────────

  static final _pathPattern = RegExp(r'^[a-zA-Z0-9_\-/]+$');
  static const int _maxPathLength = 1500;

  void _validatePath(String path) {
    if (path.isEmpty || path.length > _maxPathLength) {
      throw ArgumentError('Invalid Firestore path length: $path');
    }
    if (!_pathPattern.hasMatch(path)) {
      throw ArgumentError('Invalid characters in Firestore path: $path');
    }
  }
}

// ── Batch writes ─────────────────────────────────────────────────────────────

/// Groups multiple document writes into a single atomic operation.
///
/// ```dart
/// final batch = firestore.batch();
/// batch.set('counters/total', {'value': 0});
/// batch.update('users/uid', {'lastSeen': FieldValue.serverTimestamp()});
/// await batch.commit();
/// ```
class JustFirestoreBatch {
  JustFirestoreBatch(this._batch, this._cache);

  final fb.WriteBatch _batch;
  final FirestoreCache _cache;
  final List<String> _touchedPaths = [];

  void set(String path, Map<String, dynamic> data, {bool merge = false}) {
    if (merge) {
      _batch.set(
        fb.FirebaseFirestore.instance.doc(path),
        data,
        fb.SetOptions(merge: true),
      );
    } else {
      _batch.set(fb.FirebaseFirestore.instance.doc(path), data);
    }
    _touchedPaths.add(path);
  }

  void update(String path, Map<String, dynamic> data) {
    _batch.update(fb.FirebaseFirestore.instance.doc(path), data);
    _touchedPaths.add(path);
  }

  void delete(String path) {
    _batch.delete(fb.FirebaseFirestore.instance.doc(path));
    _touchedPaths.add(path);
  }

  Future<FirestoreError?> commit() async {
    try {
      await _batch.commit();
      for (final p in _touchedPaths) {
        unawaited(_cache.invalidate(p));
      }
      return null;
    } on fb.FirebaseException catch (e) {
      return FirestoreError.fromFirebase(e);
    } catch (e) {
      return const FirestoreError(message: 'Batch write failed.');
    }
  }
}
