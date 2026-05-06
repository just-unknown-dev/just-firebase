import 'package:cloud_firestore/cloud_firestore.dart' as fb;

/// Filter operator for [JustFirestoreFilter].
enum FilterOperator {
  isEqualTo,
  isNotEqualTo,
  isLessThan,
  isLessThanOrEqualTo,
  isGreaterThan,
  isGreaterThanOrEqualTo,
  arrayContains,
  isNull,
  isNotNull,
}

/// A single filter condition for a Firestore query.
class JustFirestoreFilter {
  const JustFirestoreFilter(this.field, this.operator, [this.value]);

  final String field;
  final FilterOperator operator;
  final Object? value;
}

/// Order direction for [JustFirestoreOrderBy].
enum OrderDirection { ascending, descending }

/// Sort specification for a Firestore query.
class JustFirestoreOrderBy {
  const JustFirestoreOrderBy(
    this.field,
    OrderDirection descending, {
    this.direction = OrderDirection.ascending,
  });

  final String field;
  final OrderDirection direction;
}

/// Type-safe query builder for Firestore collection reads.
///
/// ```dart
/// final query = JustFirestoreQuery(
///   filters: [JustFirestoreFilter('score', FilterOperator.isGreaterThan, 100)],
///   orderBy: [JustFirestoreOrderBy('score', direction: OrderDirection.descending)],
///   limit: 10,
/// );
/// final docs = await firestore.getCollection('scores', query: query);
/// ```
class JustFirestoreQuery {
  const JustFirestoreQuery({
    this.filters = const [],
    this.orderBy = const [],
    this.limit,
    this.startAfterDocument,
  });

  final List<JustFirestoreFilter> filters;
  final List<JustFirestoreOrderBy> orderBy;
  final int? limit;

  /// Opaque cursor for pagination — pass the last [JustDocument.data] map from
  /// the previous page.
  final Map<String, dynamic>? startAfterDocument;

  /// Applies this query to a Firestore [fb.CollectionReference].
  fb.Query<Map<String, dynamic>> apply(
    fb.CollectionReference<Map<String, dynamic>> ref,
  ) {
    fb.Query<Map<String, dynamic>> q = ref;

    for (final f in filters) {
      q = _applyFilter(q, f);
    }
    for (final o in orderBy) {
      q = q.orderBy(
        o.field,
        descending: o.direction == OrderDirection.descending,
      );
    }
    if (limit != null) q = q.limit(limit!);

    return q;
  }

  fb.Query<Map<String, dynamic>> _applyFilter(
    fb.Query<Map<String, dynamic>> q,
    JustFirestoreFilter f,
  ) {
    return switch (f.operator) {
      FilterOperator.isEqualTo => q.where(f.field, isEqualTo: f.value),
      FilterOperator.isNotEqualTo => q.where(f.field, isNotEqualTo: f.value),
      FilterOperator.isLessThan => q.where(f.field, isLessThan: f.value),
      FilterOperator.isLessThanOrEqualTo => q.where(
        f.field,
        isLessThanOrEqualTo: f.value,
      ),
      FilterOperator.isGreaterThan => q.where(f.field, isGreaterThan: f.value),
      FilterOperator.isGreaterThanOrEqualTo => q.where(
        f.field,
        isGreaterThanOrEqualTo: f.value,
      ),
      FilterOperator.arrayContains => q.where(f.field, arrayContains: f.value),
      FilterOperator.isNull => q.where(f.field, isNull: true),
      FilterOperator.isNotNull => q.where(f.field, isNull: false),
    };
  }
}
