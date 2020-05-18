import 'dart:convert';

import 'hlc.dart';
import 'store.dart';

typedef KeyDecoder<K> = K Function(String key);
typedef ValueDecoder<V> = V Function(dynamic value);

class Crdt<K, V> {
  final Store<K, V> _store;

  /// Represents the latest logical time seen in the stored data
  Hlc _canonicalTime;

  /// Get values as list, excluding deleted items
  List<V> get values => getMap()
      .values
      .where((record) => !record.isDeleted)
      .map((record) => record.value)
      .toList();

  Crdt([Store<K, V> store]) : _store = store ?? MapStore() {
    // Seed canonical time
    _canonicalTime = _store.latestLogicalTime;
  }

  bool isDeleted(K key) => _store.get(key)?.isDeleted;

  Map<K, Record<V>> getMap([int logicalTime = 0]) => _store.getMap(logicalTime);

  V get(K key) => _store.get(key)?.value;

  Record<V> getRecord(K key) => _store.get(key);

  Future<void> put(K key, V value) async {
    _canonicalTime = Hlc.send(_canonicalTime);
    await _store.put(key, Record<V>(_canonicalTime, value));
  }

  Future<void> putAll(Map<K, V> records) async {
    if (records.isEmpty) return;

    _canonicalTime = Hlc.send(_canonicalTime);
    await _store.putAll(records.map<K, Record<V>>(
        (key, value) => MapEntry(key, Record(_canonicalTime, value))));
  }

  Future<void> delete(K key) => put(key, null);

  /// Clears all records in the CRDT
  /// Setting [purgeRecords] true purges the entire database, otherwise records
  /// are marked as deleted allowing the changes to propagate to all clients.
  Future<void> clear({bool purgeRecords = false}) async {
    if (purgeRecords) {
      await _store.clear();
    } else {
      await putAll(_store.getMap().map((key, value) => MapEntry(key, null)));
    }
  }

  Future<void> merge(Map<K, Record<V>> remoteRecords) async {
    var localMap = await _store.getMap();
    var updatedRecords = <K, Record<V>>{};

    remoteRecords.forEach((key, remoteRecord) {
      var localRecord = localMap[key];

      if (localRecord == null) {
        // Insert if there's no local copy
        updatedRecords[key] = Record<V>(remoteRecord.hlc, remoteRecord.value);
      } else if (localRecord.hlc < remoteRecord.hlc) {
        // Update if local copy is older
        _canonicalTime = Hlc.recv(_canonicalTime, remoteRecord.hlc);
        updatedRecords[key] = Record<V>(_canonicalTime, remoteRecord.value);
      }
    });

    await _store.putAll(updatedRecords);
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
