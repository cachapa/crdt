import 'dart:math';

import 'package:crdt/src/hlc.dart';

import 'crdt.dart';

abstract class Store<T> {
  Hlc get latestLogicalTime;

  Future<Map<String, Record<T>>> getMap([int logicalTime = 0]);

  Future<Record<T>> get(String key);

  Future<void> put(String key, Record<T> value);

  Future<void> putAll(Map<String, Record<T>> values);
}

class MapStore<T> implements Store<T> {
  final Map<String, Record<T>> _map;

  @override
  Hlc get latestLogicalTime => Hlc(_map.isEmpty
      ? 0
      : _map.values.map((record) => record.hlc.logicalTime).reduce(max));

  MapStore(this._map);

  @override
  Future<Map<String, Record<T>>> getMap([int logicalTime = 0]) async =>
      Map<String, Record<T>>.from(_map)
        ..removeWhere((_, record) => record.hlc.logicalTime <= logicalTime);

  @override
  Future<Record<T>> get(String key) async => _map[key];

  @override
  Future<void> put(String key, Record<T> value) async => _map[key] = value;

  @override
  Future<void> putAll(Map<String, Record<T>> values) async =>
      _map.addAll(values);
}
