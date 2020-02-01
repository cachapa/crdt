import 'crdt.dart';

abstract class Store<T> {
  Record<T> operator [](String key);

  void operator []=(String key, Record<T> value);

  Map<String, Record<T>> get map;

  Iterable<Record<T>> get values;
}

class MapStore<T> implements Store<T> {
  final Map<String, Record<T>> _map;

  MapStore(this._map);

  @override
  Record<T> operator [](String key) => _map[key];

  @override
  void operator []=(String key, Record<T> value) => _map[key] = value;

  @override
  Map<String, Record<T>> get map => _map;

  @override
  Iterable<Record<T>> get values => _map.values;
}
