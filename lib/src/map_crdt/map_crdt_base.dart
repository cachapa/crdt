import 'dart:async';
import 'dart:math';

import 'package:crdt/map_crdt.dart';
import 'package:meta/meta.dart';

import '../changeset.dart';
import '../crdt.dart';

typedef WatchEvent = ({String key, Map<String, Object?>? value});

/// Base class for a CRDT backed by a flat map.
/// See [MapCrdt] for a simple implementation. Look for [HiveCrdt] for an
/// implementation backed by the Hive DB.
///
/// Check out [SqlCrdt] and descendants for SQL-based solutions.
abstract class MapCrdtBase extends Crdt {
  late int _canonicalTime;
  @override
  int get canonicalTime => _canonicalTime;

  /// Whether this dataset is empty.
  bool get isEmpty;

  /// Whether this dataset has at least one record.
  bool get isNotEmpty;

  MapCrdtBase(super.nodeId, this._canonicalTime);

  @protected
  Record? getRecord(String collection, String key);

  @protected
  Map<String, Record> getRecords(String collection);

  @protected
  FutureOr<void> putRecords(Map<String, Map<String, Record>> dataset);

  /// Get a value from the local dataset.
  Map<String, Object?>? get(String collection, String key) {
    assert(collections.contains(collection));
    return getRecord(collection, key)?.data;
  }

  /// Get a table map from the local dataset.
  Map<String, Map<String, Object?>?> getMap(String collection) {
    assert(collections.contains(collection));
    return (getRecords(collection)
          ..removeWhere((_, record) => record.isDeleted))
        .map((key, record) => MapEntry(key, record.data));
  }

  /// Insert a record into this dataset.
  ///
  /// Use [putAll] if inserting multiple values to avoid incrementing the
  /// canonical time unnecessarily.
  FutureOr<void> put(
    String collection,
    String id,
    Map<String, Object?>? data,
  ) => putAll({
    collection: {id: data},
  });

  /// Delete a record from this dataset
  FutureOr<void> delete(String collection, String id) => putAll({
    collection: {id: null},
  });

  /// Set multiple records in this dataset.
  FutureOr<void> putAll(
    Map<String, Map<String, Map<String, Object?>?>> dataset,
  ) async {
    final unknownTables = dataset.keys.toSet().difference(collections.toSet());
    if (unknownTables.isNotEmpty) {
      throw 'Unknown table(s): ${unknownTables.join(', ')}';
    }

    // Generate records with incremented canonical time
    final hlc = canonicalHlc.increment();
    final records = dataset.map(
      (collection, records) => MapEntry(
        collection,
        records.map(
          (id, data) => MapEntry(id, Record(data, hlc, hlc.logicalTime)),
        ),
      ),
    )..removeWhere((_, records) => records.isEmpty);

    // Store records
    await putRecords(records);
    _canonicalTime = hlc.logicalTime;
    onDatasetChanged(records.keys, _canonicalTime);
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
    int? modifiedOn,
    int? modifiedAfter,
  }) {
    assert(
      onlyCollections == null ||
          onlyCollections.toSet().difference(collections.toSet()).isEmpty,
      'Unrecognized collections(s): ${onlyCollections.toSet().difference(collections.toSet()).join(', ')}.',
    );
    assert(onlyNodeId == null || exceptNodeId == null);
    assert(modifiedOn == null || modifiedAfter == null);

    // Get records for the specified collections
    final changeset = {
      for (final collection in onlyCollections ?? collections)
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

    return CrdtChangeset.fromMap(
      changeset.map(
        (collection, records) => MapEntry(
          collection,
          records.entries.map(
            (e) => {'id': e.key, 'hlc': e.value.hlc, 'data': e.value.data},
          ),
        ),
      ),
    );
  }

  @override
  int getLastModified({String? onlyNodeId, String? exceptNodeId}) {
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

    // Get highest time or 0
    return hlcs.fold(0, (p, e) => max(p, e));
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
    final highestTime = validateChangeset(changeset);

    final newRecords = <String, Map<String, Record>>{};
    for (final entry in changeset.entries) {
      final collection = entry.key;
      for (final record in entry.value) {
        final existing = getRecord(collection, record.id);
        if (existing == null || record.hlc > existing.hlc) {
          newRecords[collection] ??= {};
          newRecords[collection]![record.id] = Record(
            record.data,
            record.hlc,
            highestTime,
          );
        }
      }
    }
    // Filter empty changes
    newRecords.removeWhere((collection, records) => records.isEmpty);

    // Write new records
    await putRecords(newRecords);
    _canonicalTime = highestTime;
    onDatasetChanged(newRecords.keys, highestTime);
  }
}
