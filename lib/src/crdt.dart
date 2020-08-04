import 'dart:math';

import 'package:meta/meta.dart';

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

  V get(K key) => getRecord(key).value;

  void put(K key, V value) {
    final time = Hlc.send(_canonicalTime);
    if (time == _canonicalTime) return;

    _canonicalTime = time;
    final record = Record<V>(_canonicalTime, value);
    putRecord(key, record);
  }

  void putAll(Map<K, V> values) =>
      values.forEach((key, value) => put(key, value));

  void delete(K key) => put(key, null);

  bool isDeleted(K key) => getRecord(key)?.isDeleted;

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

  String toJson([int logicalTime = 0]) =>
      CrdtJson.encode(recordMap(logicalTime));

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

  @protected
  Record<V> getRecord(K key);

  @protected
  void putRecord(K key, Record<V> value);

  @protected
  void putRecords(Map<K, Record<V>> recordMap);

  @protected
  Map<K, Record<V>> recordMap([int logicalTime = 0]);
}
