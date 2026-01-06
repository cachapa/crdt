import 'dart:collection';

import 'hlc.dart';

// Sample changeset
// {
//   'collection_name': [
//     {
//       'id': '1::2',          // Concatenated object ids using :: as separator
//       'hlc': '<hlc>',
//       'data': {              // Null if record was deleted
//         'user_id': 1,        // These two ids are concatenated above
//         'purchase_id': 2,
//         'created_at': '<date>',
//         'price': 123
//       }
//     }
//   ]
// };

class CrdtChangeset extends _MapBase<String, Iterable<CrdtRecord>> {
  /// Convenience method to get total number of records in a changeset
  int get recordCount => values.fold<int>(0, (prev, e) => prev + e.length);

  Iterable<String> get collections => keys;

  static CrdtChangeset fromMap(Map<String, dynamic> map) =>
      CrdtChangeset()..addAll(
        map.map(
          (collection, records) => MapEntry(
            collection,
            (records as Iterable).cast<Map<String, Object?>>().map(
              CrdtRecord.fromMap,
            ),
          ),
        )..removeWhere((_, records) => records.isEmpty),
      );

  // CrdtChangeset.parse(Map<String, dynamic> message)
  //   : _collectionMap = message.map(
  //       (collection, records) => MapEntry(
  //         collection,
  //         (records as Iterable).cast<Map<String, Object?>>().map(
  //           CrdtRecord.parse,
  //         ),
  //       ),
  //     )..removeWhere((_, records) => records.isEmpty);

  // void forEach(
  //   void Function(String collection, Iterable<CrdtRecord> records) action,
  // ) => _collectionMap.forEach(action);

  @override
  String toString() =>
      '{\n${entries.map((e) => ' ${e.key}:\n${e.value.map((v) => '  $v').join('\n')}').join('\n')}\n}';

  // Map<String, Object?> toJson() => jsonEncode(this)_collectionMap.map(
  //   (collection, records) =>
  //       MapEntry(collection, records.map((r) => r.toJson())),
  // );
}

class CrdtRecord extends _MapBase<String, Object?> {
  static const _hlcKey = 'crdt_hlc';
  static const _isDeletedKey = 'crdt_is_deleted';

  Hlc get hlc => this[_hlcKey] is String
      ? Hlc.parse(this[_hlcKey] as String)
      : this[_hlcKey] as Hlc;
  bool get isDeleted => this[_isDeletedKey]! as bool;

  static CrdtRecord fromMap(Map<String, dynamic> map) => CrdtRecord()
    ..addEntries(map.entries.where((e) => !e.key.startsWith('crdt_')))
    ..['crdt'] = {'hlc': map[_hlcKey], 'is_deleted': map[_isDeletedKey]};
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
