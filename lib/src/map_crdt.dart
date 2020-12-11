import 'crdt.dart';
import 'record.dart';

/// A CRDT backed by a in-memory map.
/// Useful for testing, or for applications which only require temporary datasets.
class MapCrdt<K, V> extends Crdt<K, V> {
  final _map = <K, Record<V>>{};

  @override
  final String nodeId;

  MapCrdt(this.nodeId, [Map<K, Record<V>> seed = const {}]) {
    _map.addAll(seed);
  }

  @override
  bool containsKey(K key) => _map.containsKey(key);

  @override
  Record<V> getRecord(K key) => _map[key];

  @override
  void putRecord(K key, Record<V> value) => _map[key] = value;

  @override
  void putRecords(Map<K, Record<V>> recordMap) => _map.addAll(recordMap);

  @override
  Map<K, Record<V>> recordMap() => Map<K, Record<V>>.from(_map);
}
