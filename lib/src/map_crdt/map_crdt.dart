import 'dart:async';

import 'package:uuid/uuid.dart';

import 'map_crdt_base.dart';
import 'record.dart';

/// A CRDT backed by a simple in-memory hashmap.
/// Useful for testing, or for applications which only require small, ephemeral
/// datasets. It is incredibly inefficient.
class MapCrdt extends MapCrdtBase {
  final Map<String, Map<String, Record>> _recordMaps;
  final _changeControllers = <String, StreamController<WatchEvent>>{};

  @override
  Iterable<String> get collections => _recordMaps.keys;

  @override
  bool get isEmpty => _recordMaps.values.fold(true, (p, e) => p && e.isEmpty);

  @override
  bool get isNotEmpty => !isEmpty;

  /// Instantiate a MapCrdt object with empty [collections].
  ///
  /// Pass [nodeId] to use a custom node id, otherwise one will be generated.
  /// Make sure to use a reliable node id generator such as UUIDv4 in prod.
  MapCrdt(Iterable<String> collections, {String? nodeId})
    : _recordMaps = {for (final collection in collections) collection: {}},
      super(nodeId ?? Uuid().v4(), 0);

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
            _changeControllers[collection]?.add((key: id, value: record.data)),
      );
    }
  }

  @override
  Stream<WatchEvent> watch(String collection, {String? key}) {
    if (!collections.contains(collection)) {
      throw 'Unknown collection: $collection';
    }
    // Create a steam controller if one doesn't exist yet
    _changeControllers[collection] ??= StreamController<WatchEvent>.broadcast();
    // Return the stream
    return key == null
        ? _changeControllers[collection]!.stream
        : _changeControllers[collection]!.stream.where(
            (event) => event.key == key,
          );
  }
}
