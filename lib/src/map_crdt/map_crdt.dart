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
  Iterable<String> get collections => _recordMaps.keys;

  @override
  bool get isEmpty => _recordMaps.values.fold(true, (p, e) => p && e.isEmpty);

  @override
  bool get isNotEmpty => !isEmpty;

  /// Instantiate a MapCrdt object with empty [collections].
  MapCrdt(Iterable<String> collections)
    : _recordMaps = {for (final collection in collections) collection: {}},
      _changeControllers = {
        for (final collection in collections)
          collection: StreamController.broadcast(),
      },
      assert(collections.isNotEmpty),
      assert(collections.length == collections.toSet().length);

  @override
  Record? getRecord(String collection, String key) =>
      _recordMaps[collection]![key];

  @override
  Map<String, Record> getRecords(String collection) =>
      Map.of(_recordMaps[collection]!);

  @override
  void putRecords(Map<String, Map<String, Record>> dataset) {
    for (final entry in dataset.entries) {
      final collection = entry.key;
      final records = entry.value;
      // Store records in memory
      _recordMaps[collection]!.addAll(records);
      // Emit change events for each record
      records.forEach(
        (id, record) =>
            _changeControllers[collection]!.add((key: id, value: record.data)),
      );
    }
  }

  @override
  Stream<WatchEvent> watch(String collection, {String? key}) {
    if (!collections.contains(collection)) {
      throw 'Unknown collection: $collection';
    }
    return key == null
        ? _changeControllers[collection]!.stream
        : _changeControllers[collection]!.stream.where(
            (event) => event.key == key,
          );
  }
}
