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
  Future<List<V>> get values async => (await getMap())
      .values
      .where((record) => !record.isDeleted)
      .map((record) => record.value)
      .toList();

  Crdt([Store<K, V> store]) : _store = store ?? MapStore() {
    // Seed canonical time
    _canonicalTime = _store.latestLogicalTime;
  }

  Future<Map<K, Record<V>>> getMap([int logicalTime = 0]) =>
      _store.getMap(logicalTime);

  Future<Record<V>> get(K key) => _store.get(key);

  Future<void> put(K key, V value) async {
    _canonicalTime = Hlc.send(_canonicalTime);
    await _store.put(key, Record<V>(_canonicalTime, value));
  }

  Future<void> putAll(Map<K, V> records) async {
    _canonicalTime = Hlc.send(_canonicalTime);
    await _store.putAll(records.map<K, Record<V>>(
        (key, value) => MapEntry(key, Record(_canonicalTime, value))));
  }

  Future<void> delete(K key) async => put(key, null);

  Future<void> clear() async => _store.clear();

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
