import 'dart:async';

import 'crdt.dart';
import 'hlc.dart';
import 'record.dart';

/// A CRDT backed by a in-memory map.
/// Useful for testing, or for applications which only require temporary datasets.
class MapCrdt<K, V> extends Crdt<K, V> {
  final _map = <K, Record<V>>{};
  final _controller = StreamController<MapEntry<K, V?>>.broadcast();

  @override
  final dynamic nodeId;

  MapCrdt(this.nodeId, [Map<K, Record<V>> seed = const {}]) {
    _map.addAll(seed);
  }

  @override
  bool containsKey(K key) => _map.containsKey(key);

  @override
  Record<V>? getRecord(K key) => _map[key];

  @override
  void putRecord(K key, Record<V> value) {
    _map[key] = value;
    _controller.add(MapEntry(key, value.value));
  }

  @override
  void putRecords(Map<K, Record<V>> recordMap) {
    _map.addAll(recordMap);
    recordMap
        .map((key, value) => MapEntry(key, value.value))
        .entries
        .forEach(_controller.add);
  }

  @override
  Map<K, Record<V>> recordMap({Hlc? modifiedSince}) =>
      Map<K, Record<V>>.from(_map)
        ..removeWhere((_, record) =>
            record.modified.logicalTime < (modifiedSince?.logicalTime ?? 0));

  @override
  Stream<MapEntry<K, V?>> watch({K? key}) =>
      _controller.stream.where((event) => key == null || key == event.key);
}
