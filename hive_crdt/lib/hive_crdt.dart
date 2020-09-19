import 'package:crdt/crdt.dart';
import 'package:hive/hive.dart';

class HiveCrdt<K, V> extends Crdt<K, V> {
  @override
  final String nodeId;

  final Box<Record> _box;

  HiveCrdt._internal(this._box, this.nodeId);

  static Future<HiveCrdt<K, V>> open<K, V>(String name, String nodeId,
      {String path}) async {
    var box = await Hive.openBox<Record>(name, path: path);
    return HiveCrdt<K, V>._internal(box, nodeId);
  }

  @override
  bool containsKey(K key) => _box.containsKey(_encode(key));

  @override
  Record<V> getRecord(K key) => _box.get(_encode(key));

  @override
  void putRecord(K key, Record<V> record) => _box.put(_encode(key), record);

  @override
  void putRecords(Map<K, Record<V>> recordMap) =>
      _box.putAll(recordMap.map((key, value) => MapEntry(_encode(key), value)));

  @override
  Map<K, Record<V>> recordMap() => _box.toMap().map<K, Record<V>>(
      (key, value) => MapEntry(_decode(key), Record(value.hlc, value.value)));

  List<V> between({K start, K end}) => _box
      .valuesBetween(startKey: start, endKey: end)
      .where((record) => !record.isDeleted)
      .map((record) => record.value)
      .toList()
      .cast<V>();

  Stream<BoxEvent> watch({K key}) => _box.watch(key: key);

  Future<void> close() => _box.close();

  /// Permanently deletes the store from disk. Useful for testing.
  Future<void> deleteStore() => _box.deleteFromDisk();

  dynamic _encode(K key) => K == DateTime ? key.toString() : key;

  K _decode(dynamic key) => K == DateTime ? DateTime.parse(key) : key;
}
