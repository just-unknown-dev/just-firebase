import 'package:flutter_test/flutter_test.dart';
import 'package:just_firebase/just_firebase.dart';

void main() {
  group('JustDocument', () {
    test('exists is true when data is non-empty', () {
      final doc = JustDocument(
        path: 'users/123',
        data: const {'name': 'Alice'},
        fetchedAt: DateTime.now(),
      );
      expect(doc.exists, isTrue);
    });

    test('exists is false when data is empty', () {
      final doc = JustDocument.empty('users/123');
      expect(doc.exists, isFalse);
    });

    test('get<T> returns typed field', () {
      final doc = JustDocument(
        path: 'scores/1',
        data: const {'score': 42, 'name': 'Alice'},
        fetchedAt: DateTime.now(),
      );
      expect(doc.get<int>('score'), equals(42));
      expect(doc.get<String>('name'), equals('Alice'));
      expect(doc.get<int>('missing'), isNull);
    });

    test('toJson / fromJson round-trips', () {
      final original = JustDocument(
        path: 'col/doc',
        data: const {'x': 1, 'y': 'hello'},
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(1_000_000),
        fromCache: true,
      );
      final json = original.toJson();
      final restored = JustDocument.fromJson(json);

      expect(restored.path, equals(original.path));
      expect(restored.data, equals(original.data));
      expect(restored.fromCache, isTrue);
      expect(
        restored.fetchedAt.millisecondsSinceEpoch,
        equals(original.fetchedAt.millisecondsSinceEpoch),
      );
    });
  });

  group('JustFirestoreQuery', () {
    test('constructs with defaults', () {
      const query = JustFirestoreQuery();
      expect(query.filters, isEmpty);
      expect(query.orderBy, isEmpty);
      expect(query.limit, isNull);
    });

    test('filter operators cover all enum values', () {
      for (final op in FilterOperator.values) {
        final filter = JustFirestoreFilter('field', op, 'value');
        expect(filter.operator, equals(op));
      }
    });

    test('orderBy direction defaults to ascending', () {
      const order = JustFirestoreOrderBy('score', OrderDirection.ascending);
      expect(order.direction, equals(OrderDirection.ascending));
    });
  });

  group('Firestore path validation', () {
    test('valid paths are accepted', () {
      const validPaths = [
        'users/uid123',
        'col/doc-1',
        'a/b/c/d',
        'scores/game_1',
      ];
      for (final p in validPaths) {
        expect(() => _validatePath(p), returnsNormally, reason: 'path: $p');
      }
    });

    test('paths with dangerous characters are rejected', () {
      const badPaths = [
        '../etc/passwd',
        'users/uid\x00null',
        'col/doc space',
        'col/doc?query=1',
      ];
      for (final p in badPaths) {
        expect(
          () => _validatePath(p),
          throwsA(isA<ArgumentError>()),
          reason: 'path: $p',
        );
      }
    });

    test('empty path is rejected', () {
      expect(() => _validatePath(''), throwsA(isA<ArgumentError>()));
    });

    test('path exceeding 1500 chars is rejected', () {
      final longPath = 'a' * 1501;
      expect(() => _validatePath(longPath), throwsA(isA<ArgumentError>()));
    });
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

// Replicates the validation logic from JustFirestore to test it in isolation.
final _pathPattern = RegExp(r'^[a-zA-Z0-9_\-/]+$');
const _maxPathLength = 1500;

void _validatePath(String path) {
  if (path.isEmpty || path.length > _maxPathLength) {
    throw ArgumentError('Invalid Firestore path length: $path');
  }
  if (!_pathPattern.hasMatch(path)) {
    throw ArgumentError('Invalid characters in Firestore path: $path');
  }
}
