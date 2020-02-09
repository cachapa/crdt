import 'dart:math';

import 'package:crdt/src/hlc.dart';

import 'crdt.dart';

abstract class Store<K, V> {
  Hlc get latestLogicalTime;

  Future<Map<K, Record<V>>> getMap([int logicalTime = 0]);

  Future<Record<V>> get(K key);

  Future<void> put(K key, Record<V> value);

  Future<void> putAll(Map<K, Record<V>> values);
}

class MapStore<K, V> implements Store<K, V> {
  final Map<K, Record<V>> _map;

  @override
  Hlc get latestLogicalTime => Hlc(_map.isEmpty
      ? 0
      : _map.values.map((record) => record.hlc.logicalTime).reduce(max));

  MapStore([Map<K, Record<V>> map]) : _map = map ?? <K, Record<V>>{};

  @override
  Future<Map<K, Record<V>>> getMap([int logicalTime = 0]) async =>
      Map<K, Record<V>>.from(_map)
        ..removeWhere((_, record) => record.hlc.logicalTime <= logicalTime);

  @override
  Future<Record<V>> get(K key) async => _map[key];

  @override
  Future<void> put(K key, Record<V> value) async => _map[key] = value;

  @override
  Future<void> putAll(Map<K, Record<V>> values) async => _map.addAll(values);
}
