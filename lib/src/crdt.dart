import 'dart:math';

import 'crdt_json.dart';
import 'hlc.dart';
import 'record.dart';

abstract class Crdt<K, V> {
  /// Represents the latest logical time seen in the stored data
  late Hlc _canonicalTime;

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
          .map((key, record) => MapEntry(key, record.value!));

  List<K> get keys => map.keys.toList();

  List<V> get values => map.values.toList();

  Crdt() {
    refreshCanonicalTime();
  }

  /// Gets a stored value. Returns [null] if value doesn't exist.
  V? get(K key) => getRecord(key)?.value;

  /// Inserts or updates a value in the CRDT and increments the canonical time.
  void put(K key, V? value) {
    _canonicalTime = Hlc.send(_canonicalTime);
    final record = Record<V>(_canonicalTime, value, _canonicalTime);
    putRecord(key, record);
  }

  /// Inserts or updates all values in the CRDT and increments the canonical time accordingly.
  void putAll(Map<K, V?> values) {
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

  /// Checks if a record is marked as deleted
  /// Returns null if record does not exist
  bool? isDeleted(K key) => getRecord(key)?.isDeleted;

  /// Marks all records as deleted.
  /// Note: by default this doesn't actually delete the records since the deletion needs to be propagated when merging with other CRDTs.
  /// Set [purge] to true to clear the records. Useful for testing or to reset a store.
  void clear({bool purge = false}) {
    if (purge) {
      this.purge();
    } else {
      putAll(map.map((key, _) => MapEntry(key, null)));
    }
  }

  /// Merges two CRDTs and updates record and canonical clocks accordingly.
  /// See also [mergeJson()].
  void merge(Map<K, Record<V>> remoteRecords) {
    final localRecords = recordMap();

    final updatedRecords = (remoteRecords
          ..removeWhere((key, value) {
            _canonicalTime = Hlc.recv(_canonicalTime, value.hlc);
            return localRecords[key] != null &&
                localRecords[key]!.hlc >= value.hlc;
          }))
        .map((key, value) =>
            MapEntry(key, Record<V>(value.hlc, value.value, _canonicalTime)));

    // Store updated records
    putRecords(updatedRecords);

    // Increment canonical time
    _canonicalTime = Hlc.send(_canonicalTime);
  }

  /// Merges two CRDTs and updates record and canonical clocks accordingly.
  /// Use [keyDecoder] to convert non-string keys.
  /// Use [valueDecoder] to convert non-native value types.
  /// See also [merge()].
  void mergeJson(String json,
      {KeyDecoder<K>? keyDecoder, ValueDecoder<V>? valueDecoder}) {
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
          {Hlc? modifiedSince,
          KeyEncoder<K>? keyEncoder,
          ValueEncoder<K, V>? valueEncoder}) =>
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
  Record<V>? getRecord(K key);

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
  Map<K, Record<V>> recordMap({Hlc? modifiedSince});

  /// Watch for changes to this CRDT.
  /// Use [key] to monitor a specific key.
  Stream<MapEntry<K, V?>> watch({K key});

  /// Clear all records. Records will be removed rather than being marked as deleted.
  /// Useful for testing or to reset a store.
  /// See also [clear].
  void purge();
}
