import 'package:crdt/crdt.dart';
import 'package:hive/hive.dart';

class HiveCrdt<K, V> extends Crdt<K, V> {
  @override
  final String nodeId;

  final Box<ModRecord> _box;

  HiveCrdt._internal(this._box, this.nodeId);

  static Future<HiveCrdt<K, V>> open<K, V>(String name, String nodeId,
      {String path}) async {
    var box = await Hive.openBox<ModRecord>(name, path: path);
    return HiveCrdt<K, V>._internal(box, nodeId);
  }

  @override
  bool containsKey(K key) => _box.containsKey(_encode(key));

  @override
  Record<V> getRecord(K key) => _box.get(_encode(key)).record;

  @override
  void putRecord(K key, Record<V> record) =>
      _box.put(_encode(key), ModRecord(record, canonicalTime));

  @override
  void putRecords(Map<K, Record<V>> recordMap) =>
      _box.putAll(recordMap.map((key, record) =>
          MapEntry(_encode(key), ModRecord(record, canonicalTime))));

  @override
  Map<K, Record<V>> recordMap() =>
      _box.toMap().map<K, Record<V>>((key, value) => MapEntry<K, Record<V>>(
          _decode(key), Record<V>(value.record.hlc, value.record.value)));

  /// Returns a map with all records modified between [from] and [to] (exclusive).
  /// If either [from] or [to] are null, the returned map contains all values
  /// starting from, or up to the HLC, respectively.
  /// See [jsonChangeset].
  Map<K, Record<V>> changeset({Hlc from, Hlc to}) =>
      (_box.toMap()..removeWhere((key, value) => value <= from || value >= to))
          .map<K, Record<V>>((key, value) => MapEntry(
              _decode(key), Record<V>(value.record.hlc, value.record.value)));

  /// Helper method for returning [changeset] as json.
  String jsonChangeset({Hlc from, Hlc to}) =>
      CrdtJson.encode(changeset(from: from, to: to));

  /// Gets all values between [startKey] and [endKey] (inclusive)
  List<V> between({K startKey, K endKey}) => _box
      .valuesBetween(startKey: startKey, endKey: endKey)
      .where((value) => !value.record.isDeleted)
      .map((value) => value.record.value)
      .toList()
      .cast<V>();

  Stream<MapEntry<K, V>> watch({K key}) => _box
      .watch(key: key)
      .map((event) => MapEntry<K, V>(event.key, event.value.record.value));

  Future<void> close() => _box.close();

  /// Permanently deletes the store from disk. Useful for testing.
  Future<void> deleteStore() => _box.deleteFromDisk();

  dynamic _encode(K key) => K == DateTime ? key.toString() : key;

  K _decode(dynamic key) => K == DateTime ? DateTime.parse(key) : key;
}

class ModRecord<T> {
  final Record<T> record;
  final Hlc modified;

  ModRecord(this.record, this.modified);

  bool operator <=(other) =>
      other == null ? false : other is Hlc && modified <= other;

  bool operator >=(other) =>
      other == null ? false : other is Hlc && modified >= other;
}
