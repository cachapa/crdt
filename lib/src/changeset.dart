import 'dart:collection';

import 'hlc.dart';

/// Represents a snapshot of the records in a CRDT.
/// Useful for merging datasets in other CRDTs, essential for syncing.
///
/// Sample changeset
/// {
///   'collection_name': [
///     {
///       'id': '1::2',          // Concatenated object ids using :: as separator
///       'hlc': '<hlc>',
///       'data': {              // Null if record was deleted
///         'user_id': 1,        // These two ids are concatenated above
///         'purchase_id': 2,
///         'created_at': '<date>',
///         'price': 123
///       }
///     }
///   ]
/// };
class CrdtChangeset extends _MapBase<String, Iterable<CrdtRecord>> {
  /// Total number of records across all collections in this changeset
  int get recordCount => values.fold<int>(0, (prev, e) => prev + e.length);

  /// Collections contained in this changeset
  Iterable<String> get collections => keys;

  /// Create a Changeset from a map.
  /// Useful when transferring changesets across nodes as JSON payloads.
  static CrdtChangeset fromMap(Map<String, dynamic> map) =>
      CrdtChangeset()..addAll(
        map.map(
          (collection, records) => MapEntry(
            collection,
            (records as Iterable)
                .cast<Map<String, Object?>>()
                .map(CrdtRecord.fromMap)
                .toList(),
          ),
        )..removeWhere((_, records) => records.isEmpty),
      );

  /// Convenience method for debugging
  void prettyPrint() => forEach((key, value) {
    print(key);
    for (var e in value) {
      print('  $e');
    }
  });
}

/// Representation of a CRDT row.
///
/// [id] is always a string and may be concatenated with other ids with a
/// separator (usually "::") to represent data structures that require multiple
/// keys, e.g. SQL tables.
/// [hlc] represents this record's logical time for comparison.
/// [data] represents the record's payload. The record is considered to have
/// been deleted if this field is null.
class CrdtRecord {
  final String id;
  final Hlc hlc;
  final Map<String, Object?>? data;

  /// Whether this record has been deleted.
  bool get isDeleted => data == null;

  CrdtRecord(this.id, this.hlc, this.data);

  /// Convenience method to generate the record from a Map.
  /// See [CrdtChangeset.fromMap].
  CrdtRecord.fromMap(Map<String, Object?> map)
    : this(
        map['id'] as String,
        map['hlc'] is Hlc ? map['hlc'] as Hlc : Hlc.parse(map['hlc'] as String),
        map['data'] as Map<String, Object?>?,
      );

  /// Convenience method for transparent json encoding.
  Map<String, Object?> toJson() => {
    'id': id,
    'hlc': hlc.toJson(),
    'data': data,
  };

  @override
  String toString() => '${toJson()}';

  @override
  bool operator ==(Object other) =>
      other is CrdtRecord &&
      id == other.id &&
      hlc == other.hlc &&
      data == other.data;

  @override
  int get hashCode => Object.hash(id, hlc, data);
}

class _MapBase<K, V> extends MapBase<K, V> {
  final _map = <K, V>{};

  @override
  V? operator [](Object? key) => _map[key];

  @override
  void operator []=(K key, V value) => _map[key] = value;

  @override
  void clear() => _map.clear();

  @override
  Iterable<K> get keys => _map.keys;

  @override
  V? remove(Object? key) => _map.remove(key);
}
