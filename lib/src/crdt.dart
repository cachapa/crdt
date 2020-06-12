import 'dart:collection';
import 'dart:convert';

import 'hlc.dart';
import 'store.dart';

typedef KeyDecoder<K> = K Function(String key);
typedef ValueDecoder<V> = V Function(dynamic value);

class CrdtMap<K, V> extends MapBase<K, V> {
  final String nodeId;
  final Store<K, V> _store;

  /// Represents the latest logical time seen in the stored data
  Hlc _canonicalTime;

  @override
  Iterable<K> get keys => getMap().keys;

  /// Get values as list, excluding deleted items
  @override
  List<V> get values => getMap()
      .values
      .where((record) => !record.isDeleted)
      .map((record) => record.value)
      .toList();

  CrdtMap(this.nodeId, [Store<K, V> store]) : _store = store ?? MapStore() {
    // Seed canonical time
    _canonicalTime =
        _store.latestLogicalTime?.apply(nodeId: nodeId) ?? Hlc.zero(nodeId);
  }

  bool isDeleted(K key) => _store.get(key)?.isDeleted;

  Map<K, Record<V>> getMap([int logicalTime = 0]) => _store.getMap(logicalTime);

  @override
  V operator [](Object key) => _store.get(key)?.value;

  Record<V> getRecord(K key) => _store.get(key);

  @override
  void operator []=(K key, V value) {
    _canonicalTime = Hlc.send(_canonicalTime);
    _store.put(key, Record<V>(_canonicalTime, value));
  }

  @override
  void addAll(Map<K, V> records) {
    if (records.isEmpty) return;

    _canonicalTime = Hlc.send(_canonicalTime);
    _store.putAll(records.map<K, Record<V>>(
        (key, value) => MapEntry(key, Record(_canonicalTime, value))));
  }

  @override
  V remove(Object key) => this[key] = null;

  /// Clears all records in the CRDT
  /// Setting [purgeRecords] true purges the entire database, otherwise records
  /// are marked as deleted allowing the changes to propagate to all clients.
  @override
  Future<void> clear({bool purgeRecords = false}) {
    if (purgeRecords) {
      _store.clear();
    } else {
      addAll(_store.getMap().map((key, value) => MapEntry(key, null)));
    }
  }

  void merge(Map<K, Record<V>> remoteRecords) {
    final localMap = _store.getMap();
    final updatedRecords = <K, Record<V>>{};

    remoteRecords.forEach((key, remoteRecord) {
      final localRecord = localMap[key];

      // Keep record if there's no local copy, or if local is older
      if (localRecord == null || localRecord.hlc < remoteRecord.hlc) {
        _canonicalTime = Hlc.recv(_canonicalTime, remoteRecord.hlc);
        updatedRecords[key] = remoteRecord;
      }
    });

    _store.putAll(updatedRecords);
  }

  Stream<void> watch() => _store.watch();

  @override
  String toString() => _store.toString();
}

class Record<V> {
  final Hlc hlc;
  final V value;

  bool get isDeleted => value == null;

  Record(this.hlc, this.value);

  Record.fromJson(Map<String, dynamic> map, [ValueDecoder<V> decoder])
      : hlc = Hlc.parse(map['hlc']),
        value = decoder == null || map['value'] == null
            ? map['value']
            : decoder(map['value']);

  Map<String, dynamic> toJson() => {'hlc': hlc.toJson(), 'value': value};

  @override
  bool operator ==(other) =>
      other is Record<V> && hlc == other.hlc && value == other.value;

  @override
  String toString() => toJson().toString();
}

String crdtMap2Json(Map map) => jsonEncode(
    map.map((key, value) => MapEntry(key.toString(), value.toJson())));

Map<K, Record<V>> json2CrdtMap<K, V>(String json,
        {KeyDecoder<K> keyDecoder, ValueDecoder<V> valueDecoder}) =>
    (jsonDecode(json) as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        keyDecoder == null ? key : keyDecoder(key),
        Record.fromJson(value, valueDecoder),
      ),
    );
