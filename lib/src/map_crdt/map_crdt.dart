import 'dart:async';

import 'map_crdt_base.dart';
import 'record.dart';

/// A CRDT backed by a simple in-memory hashmap.
/// Useful for testing, or for applications which only require small, ephemeral
/// datasets. It is incredibly inefficient.
class MapCrdt extends MapCrdtBase {
  final Map<String, Map<String, Record>> _recordMaps;
  final Map<String, StreamController<({String key, dynamic value})>>
      _changeControllers;

  @override
  bool get isEmpty => _recordMaps.values.fold(true, (p, e) => p && e.isEmpty);

  @override
  bool get isNotEmpty => !isEmpty;

  /// Instantiate a MapCrdt object with empty [tables].
  MapCrdt(Iterable<String> tables)
      : _recordMaps = {for (final table in tables.toSet()) table: {}},
        _changeControllers = {
          for (final table in tables.toSet())
            table: StreamController.broadcast()
        },
        assert(tables.isNotEmpty),
        super(tables);

  @override
  Record? getRecord(String table, String key) => _recordMaps[table]![key];

  @override
  Map<String, Record> getRecords(String table) => Map.of(_recordMaps[table]!);

  @override
  void putRecords(Map<String, Map<String, Record>> dataset) {
    dataset.forEach((table, records) {
      _recordMaps[table]!.addAll(records);
      records.forEach((key, value) =>
          _changeControllers[table]!.add((key: key, value: value.value)));
    });
  }

  @override
  Stream<({String key, dynamic value})> watch(String table, {String? key}) {
    if (!tables.contains(table)) throw 'Unknown table: $table';
    return key == null
        ? _changeControllers[table]!.stream
        : _changeControllers[table]!.stream.where((event) => event.key == key);
  }
}
