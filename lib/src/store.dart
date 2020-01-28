import 'crdt.dart';

abstract class Store {
  Record operator [](String key);

  void operator []=(String key, Record value);

  Map<String, Record> get map;

  Iterable<Record> get values;
}

class MapStore implements Store {
  final Map<String, Record> _map;

  MapStore(this._map);

  @override
  Record operator [](String key) => _map[key];

  @override
  void operator []=(String key, Record value) => _map[key] = value;

  @override
  Map<String, Record> get map => _map;

  @override
  Iterable<Record> get values => _map.values;
}
