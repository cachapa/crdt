import 'dart:math';

import 'crdt_json.dart';
import 'hlc.dart';
import 'record.dart';

abstract class Crdt<K, V> {
  /// Represents the latest logical time seen in the stored data
  Hlc _canonicalTime;

  String get nodeId;

  Map<K, V> get map =>
      (recordMap()..removeWhere((_, record) => record.isDeleted))
          .map((key, record) => MapEntry(key, record.value));

  List<K> get keys => map.keys;

  List<V> get values => map.values;

  Crdt() {
    _canonicalTime = computeCanonicalTime();
  }

  /// Gets a stored value. Returns [null] if value doesn't exist.
  V get(K key) => getRecord(key).value;

  /// Inserts or updates a value in the CRDT and increments the canonical time.
  void put(K key, V value) {
    final time = Hlc.send(_canonicalTime);
    if (time == _canonicalTime) return;

    _canonicalTime = time;
    final record = Record<V>(_canonicalTime, value);
    putRecord(key, record);
  }

  /// Inserts or updates all values in the CRDT and increments the canonical time accordingly.
  void putAll(Map<K, V> values) =>
      values.forEach((key, value) => put(key, value));

  /// Marks the record as deleted.
  /// Note: this doesn't actually delete the record since the deletion needs to be propagated when merging with other CRDTs.
  void delete(K key) => put(key, null);

  bool isDeleted(K key) => getRecord(key)?.isDeleted;

  /// Merges two CRDTs and updates record and canonical clocks accordingly.
  /// See also [mergeJson()].
  void merge(Map<K, Record<V>> remoteRecords) {
    final localRecords = recordMap();
    final updatedRecords = <K, Record<V>>{};

    remoteRecords.forEach((key, remoteRecord) {
      final localRecord = localRecords[key];

      // Keep record if there's no local copy, or if local is older
      if (localRecord == null || localRecord.hlc < remoteRecord.hlc) {
        _canonicalTime = Hlc.recv(_canonicalTime, remoteRecord.hlc);
        updatedRecords[key] = remoteRecord;
      }
    });

    putRecords(updatedRecords);
  }

  /// Outputs the contents of this CRDT in Json format.
  /// Specify [logicalTime] to encode only the records on or after the timestamp.
  /// Make sure non-native value types implement toJson().
  String toJson([int logicalTime = 0]) =>
      CrdtJson.encode(recordMap(logicalTime));

  /// Merges two CRDTs and updates record and canonical clocks accordingly.
  /// Use [keyDecoder] to convert non-string keys.
  /// Use [valueDecoder] to convert non-native value types.
  /// See also [merge()].
  void mergeJson(String json,
      {KeyDecoder<K> keyDecoder, ValueDecoder<V> valueDecoder}) {
    final map = CrdtJson.decode<K, V>(json,
        keyDecoder: keyDecoder, valueDecoder: valueDecoder);
    merge(map);
  }

  /// Iterates through the CRDT to find the highest HLC
  /// Used to seed the Canonical Time
  /// Should be overridden if the implementation can be more efficient
  Hlc computeCanonicalTime() {
    final map = recordMap();
    return Hlc.fromLogicalTime(
        map.isEmpty
            ? 0
            : map.values.map((record) => record.hlc.logicalTime).reduce(max),
        nodeId);
  }

  @override
  String toString() => recordMap().toString();

  //=== Abstract methods ===//

  /// Gets record containing value and HLC.
  Record<V> getRecord(K key);

  /// Stores record without updating the HLC. Meant for subclassing and shouldn't be used directly by clients.
  /// Use [put()] instead.
  void putRecord(K key, Record<V> value);

  /// Stores records without updating the HLC. Meant for subclassing and shouldn't be used directly by clients.
  /// Use [putAll()] instead.
  void putRecords(Map<K, Record<V>> recordMap);

  /// Retrieves CRDT map including HLCs. Useful for merging with other CRDTs.
  /// Specify [logicalTime] to encode only the records on or after the timestamp.
  /// See also [toJson()].
  Map<K, Record<V>> recordMap([int logicalTime = 0]);
}
