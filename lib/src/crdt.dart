import 'dart:math';

import 'crdt_json.dart';
import 'hlc.dart';
import 'record.dart';

abstract class Crdt<K, V> {
  /// Represents the latest logical time seen in the stored data
  Hlc _canonicalTime;

  Hlc get canonicalTime => _canonicalTime;

  dynamic get nodeId;

  /// Returns [true] if CRDT has any non-deleted records.
  bool get isEmpty => map.isEmpty;

  /// Get size of dataset excluding deleted records.
  int get length => map.length;

  /// Returns a simple key-value map without HLCs or deleted records.
  /// See [recordMap].
  Map<K, V> get map =>
      (recordMap()..removeWhere((_, record) => record.isDeleted))
          .map((key, record) => MapEntry(key, record.value));

  List<K> get keys => map.keys.toList();

  List<V> get values => map.values.toList();

  Crdt() {
    refreshCanonicalTime();
  }

  /// Gets a stored value. Returns [null] if value doesn't exist.
  V get(K key) => getRecord(key)?.value;

  /// Inserts or updates a value in the CRDT and increments the canonical time.
  void put(K key, V value) {
    _canonicalTime = Hlc.send(_canonicalTime);
    final record = Record<V>(_canonicalTime, value, _canonicalTime);
    putRecord(key, record);
  }

  /// Inserts or updates all values in the CRDT and increments the canonical time accordingly.
  void putAll(Map<K, V> values) {
    // Avoid touching the canonical time if no data is inserted
    if (values.isEmpty) return;

    _canonicalTime = Hlc.send(_canonicalTime);
    final records = values.map<K, Record<V>>((key, value) =>
        MapEntry(key, Record(_canonicalTime, value, _canonicalTime)));
    putRecords(records);
  }

  /// Marks the record as deleted.
  /// Note: this doesn't actually delete the record since the deletion needs to be propagated when merging with other CRDTs.
  void delete(K key) => put(key, null);

  bool isDeleted(K key) => getRecord(key)?.isDeleted;

  /// Marks all records as deleted.
  /// Note: this doesn't actually delete the records since the deletion needs to be propagated when merging with other CRDTs.
  void clear() => putAll(map.map((key, _) => MapEntry(key, null)));

  /// Merges two CRDTs and updates record and canonical clocks accordingly.
  /// See also [mergeJson()].
  void merge(Map<K, Record<V>> remoteRecords) {
    final localRecords = recordMap();
    final updatedRecords = <K, Record<V>>{};

    remoteRecords.forEach((key, remoteRecord) {
      _canonicalTime = Hlc.recv(_canonicalTime, remoteRecord.hlc);

      // Keep record if there's no local copy, or if remote is newer
      final localRecord = localRecords[key];
      if (localRecord == null || localRecord.hlc < remoteRecord.hlc) {
        updatedRecords[key] = remoteRecord;
      }
    });

    putRecords(updatedRecords);
  }

  /// Merges two CRDTs and updates record and canonical clocks accordingly.
  /// Use [keyDecoder] to convert non-string keys.
  /// Use [valueDecoder] to convert non-native value types.
  /// See also [merge()].
  void mergeJson(String json,
      {KeyDecoder<K> keyDecoder, ValueDecoder<V> valueDecoder}) {
    final map = CrdtJson.decode<K, V>(
      json,
      _canonicalTime,
      keyDecoder: keyDecoder,
      valueDecoder: valueDecoder,
    );
    merge(map);
  }

  /// Iterates through the CRDT to find the highest HLC timestamp.
  /// Used to seed the Canonical Time.
  /// Should be overridden if the implementation can do it more efficiently.
  void refreshCanonicalTime() {
    final map = recordMap();
    _canonicalTime = Hlc.fromLogicalTime(
        map.isEmpty
            ? 0
            : map.values.map((record) => record.hlc.logicalTime).reduce(max),
        nodeId);
  }

  /// Outputs the contents of this CRDT in Json format.
  /// Use [modifiedSince] to encode only the most recently modified records.
  /// Use [keyEncoder] to convert non-string keys.
  /// Use [valueEncoder] to convert non-native value types.
  String toJson(
          {Hlc modifiedSince,
          KeyEncoder<K> keyEncoder,
          ValueEncoder<K, V> valueEncoder}) =>
      CrdtJson.encode(
        recordMap(modifiedSince: modifiedSince),
        keyEncoder: keyEncoder,
        valueEncoder: valueEncoder,
      );

  @override
  String toString() => recordMap().toString();

  //=== Abstract methods ===//

  bool containsKey(K key);

  /// Gets record containing value and HLC.
  Record<V> getRecord(K key);

  /// Stores record without updating the HLC.
  /// Meant for subclassing, clients should use [put()] instead.
  /// Make sure to call [refreshCanonicalTime()] if using this method directly.
  void putRecord(K key, Record<V> value);

  /// Stores records without updating the HLC.
  /// Meant for subclassing, clients should use [putAll()] instead.
  /// Make sure to call [refreshCanonicalTime()] if using this method directly.
  void putRecords(Map<K, Record<V>> recordMap);

  /// Retrieves CRDT map including HLCs. Useful for merging with other CRDTs.
  /// Use [modifiedSince] to get only the most recently modified records.
  /// See also [toJson()].
  Map<K, Record<V>> recordMap({Hlc modifiedSince});

  /// Watch for changes to this CRDT.
  /// Use [key] to monitor a specific key.
  Stream<MapEntry<K, V>> watch({K key});
}
