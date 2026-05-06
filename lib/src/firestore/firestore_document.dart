import 'package:cloud_firestore/cloud_firestore.dart' as fb;

/// An immutable snapshot of a Firestore document.
class JustDocument {
  const JustDocument({
    required this.path,
    required this.data,
    required this.fetchedAt,
    this.fromCache = false,
  });

  /// Fully qualified Firestore path, e.g. `'users/uid123'`.
  final String path;

  /// Document field data. Empty map if the document does not exist.
  final Map<String, dynamic> data;

  /// When this snapshot was retrieved (local clock).
  final DateTime fetchedAt;

  /// Whether the data came from the local cache rather than the server.
  final bool fromCache;

  /// `true` when the document exists in Firestore (non-empty data).
  bool get exists => data.isNotEmpty;

  /// Convenience accessor — returns a typed field or [defaultValue].
  T? get<T>(String field) {
    final value = data[field];
    if (value is T) return value;
    return null;
  }

  factory JustDocument.fromFirebase(fb.DocumentSnapshot snap) {
    return JustDocument(
      path: snap.reference.path,
      data: (snap.data() as Map<String, dynamic>?) ?? {},
      fetchedAt: DateTime.now(),
      fromCache: snap.metadata.isFromCache,
    );
  }

  factory JustDocument.empty(String path) => JustDocument(
    path: path,
    data: const {},
    fetchedAt: DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'path': path,
    'data': data,
    'fetchedAt': fetchedAt.millisecondsSinceEpoch,
    'fromCache': fromCache,
  };

  factory JustDocument.fromJson(Map<String, dynamic> json) {
    return JustDocument(
      path: json['path'] as String,
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(json['fetchedAt'] as int),
      fromCache: json['fromCache'] as bool? ?? false,
    );
  }

  @override
  String toString() => 'JustDocument($path, exists: $exists)';
}
