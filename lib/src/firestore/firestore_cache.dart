import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:just_database/just_database.dart';

import 'firestore_document.dart';

/// Local just_database cache for Firestore documents.
///
/// Read strategy: memory map → just_database → Firestore (network).
/// On network failure, stale cached data is returned without throwing.
class FirestoreCache {
  FirestoreCache({required this.dbName, required this.defaultTtl});

  final String dbName;
  final Duration defaultTtl;

  static const String _kTable = 'jf_firestore_cache';

  JustDatabase? _db;

  // Hot in-memory layer to avoid repeated DB reads for the same path.
  final Map<String, JustDocument> _memCache = {};

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      _db = await DatabaseManager.open(dbName, persist: true);
      await _db!.execute('''
        CREATE TABLE IF NOT EXISTS $_kTable (
          path     TEXT PRIMARY KEY NOT NULL,
          data     TEXT NOT NULL,
          fetched_at INTEGER NOT NULL,
          ttl      INTEGER NOT NULL,
          collection TEXT
        )
      ''');
    } catch (e) {
      debugPrint('FirestoreCache: database unavailable ($e)');
    }
  }

  void dispose() {
    _memCache.clear();
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns a cached [JustDocument] for [path], or `null` if:
  /// - the cache has no entry for this path, or
  /// - [requireFresh] is `true` and the cached entry has expired.
  Future<JustDocument?> get(String path, {bool requireFresh = true}) async {
    // 1. Memory layer
    final mem = _memCache[path];
    if (mem != null) {
      if (!requireFresh || _isFresh(mem)) return mem;
    }

    // 2. Database layer
    final db = _db;
    if (db == null) return null;

    try {
      final escapedPath = _esc(path);
      final result = await db.execute(
        'SELECT data, fetched_at, ttl FROM $_kTable WHERE path = $escapedPath',
      );
      if (result.rows.isEmpty) return null;

      final row = result.rows.first;
      final dataJson = row['data'] as String?;
      if (dataJson == null) return null;

      final fetchedAt = DateTime.fromMillisecondsSinceEpoch(
        (row['fetched_at'] as num).toInt(),
      );
      final ttlMs = (row['ttl'] as num).toInt();

      final doc = JustDocument(
        path: path,
        data: (jsonDecode(dataJson) as Map<String, dynamic>),
        fetchedAt: fetchedAt,
        fromCache: true,
      );

      if (requireFresh) {
        final age = DateTime.now().difference(fetchedAt).inMilliseconds;
        if (age > ttlMs) return null;
      }

      _memCache[path] = doc;
      return doc;
    } catch (e) {
      debugPrint('FirestoreCache: read failed for $path ($e)');
      return null;
    }
  }

  /// Returns a potentially stale document regardless of TTL expiry.
  /// Used as fallback when the network is unavailable.
  Future<JustDocument?> getStale(String path) => get(path, requireFresh: false);

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> put(JustDocument doc, {Duration? ttl}) async {
    final effectiveTtl = ttl ?? defaultTtl;
    _memCache[doc.path] = doc;

    final db = _db;
    if (db == null) return;

    try {
      final escapedPath = _esc(doc.path);
      final dataJson = _esc(jsonEncode(doc.data));
      final fetchedAt = doc.fetchedAt.millisecondsSinceEpoch;
      final ttlMs = effectiveTtl.inMilliseconds;
      final collection = _esc(_collectionOf(doc.path));

      final upd = await db.execute(
        'UPDATE $_kTable SET data = $dataJson, fetched_at = $fetchedAt, '
        'ttl = $ttlMs, collection = $collection WHERE path = $escapedPath',
      );
      if (upd.affectedRows == 0) {
        await db.execute(
          'INSERT INTO $_kTable (path, data, fetched_at, ttl, collection) '
          'VALUES ($escapedPath, $dataJson, $fetchedAt, $ttlMs, $collection)',
        );
      }
    } catch (e) {
      debugPrint('FirestoreCache: write failed for ${doc.path} ($e)');
    }
  }

  Future<void> invalidate(String path) async {
    _memCache.remove(path);
    final db = _db;
    if (db == null) return;
    try {
      await db.execute(
        'DELETE FROM $_kTable WHERE path = ${_esc(path)}',
      );
    } catch (e) {
      debugPrint('FirestoreCache: invalidate failed for $path ($e)');
    }
  }

  Future<void> invalidateCollection(String collectionPath) async {
    _memCache.removeWhere((k, _) => k.startsWith('$collectionPath/'));
    final db = _db;
    if (db == null) return;
    try {
      await db.execute(
        'DELETE FROM $_kTable WHERE collection = ${_esc(collectionPath)}',
      );
    } catch (e) {
      debugPrint(
        'FirestoreCache: collection invalidate failed for $collectionPath ($e)',
      );
    }
  }

  Future<void> clear() async {
    _memCache.clear();
    final db = _db;
    if (db == null) return;
    try {
      await db.execute('DELETE FROM $_kTable');
    } catch (e) {
      debugPrint('FirestoreCache: clear failed ($e)');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isFresh(JustDocument doc) {
    final age = DateTime.now().difference(doc.fetchedAt);
    return age < defaultTtl;
  }

  /// Extracts the collection path from a document path.
  /// e.g. `'users/uid123'` → `'users'`
  String _collectionOf(String path) {
    final slash = path.lastIndexOf('/');
    return slash >= 0 ? path.substring(0, slash) : path;
  }

  static String _esc(String value) => "'${value.replaceAll("'", "''")}'";
}
