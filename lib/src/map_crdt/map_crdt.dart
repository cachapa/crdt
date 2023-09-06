import 'map_crdt_base.dart';
import 'record.dart';

/// A CRDT backed by a simple in-memory hashmap.
/// Useful for testing, or for applications which only require small, ephemeral
/// datasets. It is incredibly inefficient.
class MapCrdt extends MapCrdtBase {
  final Map<String, Map<String, Record>> _recordMaps;

  @override
  bool get isEmpty => _recordMaps.values.fold(true, (p, e) => p && e.isEmpty);

  @override
  bool get isNotEmpty => !isEmpty;

  /// Instantiate a MapCrdt object with empty [tables].
  MapCrdt(Iterable<String> tables)
      : _recordMaps = {for (final table in tables.toSet()) table: {}},
        assert(tables.isNotEmpty),
        super(tables);

  @override
  Record? getRecord(String table, String key) => _recordMaps[table]![key];

  @override
  Map<String, Record> getRecords(String table) => Map.of(_recordMaps[table]!);

  @override
  void putRecords(Map<String, Map<String, Record>> dataset) =>
      dataset.forEach((table, records) => _recordMaps[table]!.addAll(records));
}
