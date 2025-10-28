import 'dart:async';

import 'package:crdt/map_crdt.dart';
import 'package:meta/meta.dart';

import '../changeset.dart';
import '../crdt.dart';
import '../hlc.dart';

typedef WatchEvent = ({String key, dynamic value});

/// Base class for a CRDT backed by a flat map.
/// See [MapCrdt] for a simple implementation. Look for [HiveCrdt] for an
/// implementation backed by the Hive DB.
///
/// Check out [SqlCrdt] and descendants for SQL-based solutions.
abstract class MapCrdtBase extends Crdt {
  // The collections monitored by this CRDT.
  Iterable<String> get collections;

  /// Whether this dataset is empty.
  bool get isEmpty;

  /// Whether this dataset has at least one record.
  bool get isNotEmpty;

  MapCrdtBase() {
    canonicalTime = getLastModified() ?? Hlc.zero(generateNodeId());
  }

  @protected
  Record? getRecord(String collection, String key);

  @protected
  Map<String, Record> getRecords(String collection);

  @protected
  FutureOr<void> putRecords(Map<String, Map<String, Record>> dataset);

  /// Get a value from the local dataset.
  Object? get(String collection, String key) {
    assert(collections.contains(collection));
    final value = getRecord(collection, key)?.data;
    return value;
  }

  /// Get a table map from the local dataset.
  Map<String, Object?> getMap(String collection) {
    assert(collections.contains(collection));
    return (getRecords(collection)
          ..removeWhere((_, record) => record.isDeleted))
        .map((key, record) => MapEntry(key, record.data));
  }

  /// Insert a record into this dataset.
  ///
  /// Use [putAll] if inserting multiple values to avoid incrementing the
  /// canonical time unnecessarily.
  FutureOr<void> put(String collection, String id, Object? data) => putAll({
    collection: {id: data},
  });

  /// Delete a record from this dataset
  FutureOr<void> delete(String collection, String id) => putAll({
    collection: {id: null},
  });

  /// Set multiple records in this dataset.
  FutureOr<void> putAll(Map<String, Map<String, Object?>> dataset) async {
    final unknownTables = dataset.keys.toSet().difference(collections.toSet());
    if (unknownTables.isNotEmpty) {
      throw 'Unknown table(s): ${unknownTables.join(', ')}';
    }

    // Generate records with incremented canonical time
    final hlc = canonicalTime.increment();
    final records = dataset.map(
      (collection, records) => MapEntry(
        collection,
        records.map((id, data) => MapEntry(id, Record(data, hlc, hlc))),
      ),
    )..removeWhere((_, records) => records.isEmpty);

    // Store records
    await putRecords(records);
    onDatasetChanged(records.keys, hlc);
  }

  /// Returns a stream of changes.
  /// Use the optional [key] parameter to filter events or leave it empty to get
  /// all changes.
  Stream<WatchEvent> watch(String table, {String? key});

  @override
  CrdtChangeset getChangeset({
    Iterable<String>? onlyCollections,
    String? onlyNodeId,
    String? exceptNodeId,
    Hlc? modifiedOn,
    Hlc? modifiedAfter,
  }) {
    assert(onlyNodeId == null || exceptNodeId == null);
    assert(modifiedOn == null || modifiedAfter == null);

    onlyCollections ??= collections;
    assert(onlyCollections.toSet().difference(collections.toSet()).isEmpty);

    // Modified times use the local node id
    modifiedOn = modifiedOn?.apply(nodeId: nodeId);
    modifiedAfter = modifiedAfter?.apply(nodeId: nodeId);

    // Get records for the specified collections
    final changeset = {
      for (final collection in onlyCollections)
        collection: getRecords(collection),
    };

    // Apply remaining filters
    for (final records in changeset.values) {
      records.removeWhere(
        (_, value) =>
            (onlyNodeId != null && value.hlc.nodeId != onlyNodeId) ||
            (exceptNodeId != null && value.hlc.nodeId == exceptNodeId) ||
            (modifiedOn != null && value.modified != modifiedOn) ||
            (modifiedAfter != null && value.modified <= modifiedAfter),
      );
    }

    // Remove empty collection changesets
    changeset.removeWhere((_, records) => records.isEmpty);

    return CrdtChangeset.parse(
      changeset.map(
        (collection, records) => MapEntry(
          collection,
          records.entries.map(
            (e) => {
              'id': e.key,
              'hlc': e.value.hlc,
              'data': {e.key: e.value.data},
            },
          ),
        ),
      ),
    );
  }

  @override
  Hlc? getLastModified({String? onlyNodeId, String? exceptNodeId}) {
    assert(onlyNodeId == null || exceptNodeId == null);

    final hlcs = collections
        .map((e) => getRecords(e).entries.map((e) => e.value))
        // Flatten records into single iterable
        .fold(<Record>[], (p, e) => p..addAll(e))
        // Apply filters
        .where(
          (e) =>
              (onlyNodeId == null && exceptNodeId == null) ||
              (onlyNodeId != null && e.hlc.nodeId == onlyNodeId) ||
              (exceptNodeId != null && e.hlc.nodeId != exceptNodeId),
        )
        // Get only modified times
        .map((e) => e.modified);

    // Get highest time or null
    return hlcs.isEmpty ? null : hlcs.reduce((a, b) => a > b ? a : b);
  }

  @override
  FutureOr<void> merge(CrdtChangeset changeset) async {
    final unknownTables = changeset.collections.toSet().difference(
      collections.toSet(),
    );
    if (unknownTables.isNotEmpty) {
      throw 'Unknown table(s): ${unknownTables.join(', ')}';
    }

    if (changeset.recordCount == 0) return;

    // Validate changeset and get new canonical time
    final hlc = validateChangeset(changeset);

    final newRecords = <String, Map<String, Record>>{};
    for (final entry in changeset.entries) {
      final collection = entry.key;
      for (final record in entry.value) {
        final existing = getRecord(collection, record.id);
        if (existing == null || record.hlc > existing.hlc) {
          newRecords[collection] ??= {};
          newRecords[collection]![record.id] = Record(
            record.data?[record.id],
            record.hlc,
            hlc,
          );
        }
      }
    }
    // Filter empty changes
    newRecords.removeWhere((collection, records) => records.isEmpty);

    // Write new records
    await putRecords(newRecords);
    onDatasetChanged(newRecords.keys, hlc);
  }
}
