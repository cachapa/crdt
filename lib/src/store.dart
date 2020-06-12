import 'dart:async';

import 'package:crdt/src/hlc.dart';

import 'crdt.dart';

abstract class Store<K, V> {
  String get nodeId;

  Hlc get latestLogicalTime;

  Map<K, Record<V>> getMap([int logicalTime = 0]);

  Record<V> get(K key);

  void put(K key, Record<V> value);

  void putAll(Map<K, Record<V>> values);

  void clear();

  Stream<void> watch();
}

class MapStore<K, V> implements Store<K, V> {
  @override
  final String nodeId;
  final Map<K, Record<V>> _map;
  final _controller = StreamController<void>();

  @override
  Hlc get latestLogicalTime => _map.isEmpty
      ? null
      : _map.values.map((record) => record.hlc).reduce((a, b) => a > b ? a : b);

  MapStore(this.nodeId, [Map<K, Record<V>> map])
      : _map = map ?? <K, Record<V>>{};

  @override
  Map<K, Record<V>> getMap([int logicalTime = 0]) =>
      Map<K, Record<V>>.from(_map)
        ..removeWhere((_, record) => record.hlc.logicalTime <= logicalTime);

  @override
  Record<V> get(K key) => _map[key];

  @override
  void put(K key, Record<V> value) async {
    _map[key] = value;
    _controller.add(null);
  }

  @override
  void putAll(Map<K, Record<V>> values) async {
    _map.addAll(values);
    _controller.add(null);
  }

  @override
  void clear() async => _map.clear();

  @override
  Stream<void> watch() => _controller.stream;
}
