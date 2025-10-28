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

class CrdtChangeset {
  final Map<String, List<CrdtRecord>> _collectionMap;

  /// Convenience method to get total number of records in a changeset
  int get recordCount =>
      _collectionMap.values.fold<int>(0, (prev, e) => prev + e.length);

  Iterable<MapEntry<String, List<CrdtRecord>>> get entries =>
      _collectionMap.entries;

  Iterable<String> get collections => _collectionMap.keys;

  List<CrdtRecord>? operator [](String collection) =>
      _collectionMap[collection];

  void setRecords(String collection, List<CrdtRecord> records) =>
      _collectionMap[collection] = records;

  CrdtChangeset.parse(Map<String, dynamic> message)
    : _collectionMap = message.map(
        (collection, records) => MapEntry(
          collection,
          (records as Iterable<Map<String, Object?>>)
              .map(CrdtRecord.parse)
              .toList(),
        ),
      );

  void forEach(
    void Function(String collection, List<CrdtRecord> records) action,
  ) => _collectionMap.forEach(action);

  @override
  String toString() => '${toJson()}';

  Map<String, Object?> toJson() => Map.unmodifiable(_collectionMap);
}

class CrdtRecord {
  final String id;
  final Hlc hlc;
  final Map<String, Object?>? data;

  bool get isDeleted => data == null;

  CrdtRecord(this.id, this.hlc, this.data);

  CrdtRecord.parse(Map<String, dynamic> map)
    : this(
        map['id'],
        map['hlc'] is String ? Hlc.parse(map['hlc']) : map['hlc'],
        map['data'],
      );

  @override
  String toString() => '${toJson()}';

  Map<String, Object?> toJson() => {'id': id, 'hlc': hlc, 'data': data};
}
