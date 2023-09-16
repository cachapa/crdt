import 'dart:async';

import 'package:meta/meta.dart';

import '../crdt.dart';
import '../hlc.dart';
import '../types.dart';
import 'record.dart';

typedef WatchEvent = ({String key, dynamic value, bool isDeleted});

/// A CRDT backed by a simple in-memory hashmap.
/// Useful for testing, or for applications which only require small, ephemeral
/// datasets. It is incredibly inefficient.
abstract class MapCrdtBase extends Crdt {
  /// Names of all tables contained in this dataset.
  final Set<String> tables;

  /// Whether this dataset is empty.
  bool get isEmpty;

  /// Whether this dataset has at least one record.
  bool get isNotEmpty;

  MapCrdtBase(Iterable<String> tables) : tables = tables.toSet() {
    final nodeId = isEmpty
        ? generateNodeId()
        : tables
            .map(getRecords)
            .firstWhere((e) => e.isNotEmpty)
            .values
            .first
            .modified
            .nodeId;
    // Seed canonical time with a node id, needed for [getLastModified]
    canonicalTime = Hlc.zero(nodeId);
    canonicalTime = getLastModified();
  }

  @protected
  Record? getRecord(String table, String key);

  @protected
  Map<String, Record> getRecords(String table);

  @protected
  FutureOr<void> putRecords(Map<String, Map<String, Record>> dataset);

  /// Get a value from the local dataset.
  dynamic get(String table, String key) {
    if (!tables.contains(table)) throw 'Unknown table: $table';
    final value = getRecord(table, key);
    return value == null || value.isDeleted ? null : value.value;
  }

  /// Get a table map from the local dataset.
  Map<String, dynamic> getMap(String table) {
    if (!tables.contains(table)) throw 'Unknown table: $table';
    return (getRecords(table)..removeWhere((_, record) => record.isDeleted))
        .map((key, record) => MapEntry(key, record.value));
  }

  /// Insert a single value into this dataset.
  ///
  /// Use [putAll] if inserting multiple values to avoid incrementing the
  /// canonical time unnecessarily.
  // TODO Find a way to make this return [void] for sync implementations
  Future<void> put(String table, String key, dynamic value,
          [bool isDeleted = false]) =>
      putAll({
        table: {key: value}
      }, isDeleted);

  /// Insert multiple values into this dataset.
  // TODO Find a way to make this return [void] for sync implementations
  Future<void> putAll(Map<String, Map<String, dynamic>> dataset,
      [bool isDeleted = false]) async {
    // Ensure all incoming tables exist in local dataset
    final badTables = dataset.keys.toSet().difference(tables);
    if (badTables.isNotEmpty) {
      throw 'Unknown table(s): ${badTables.join(', ')}';
    }

    // Ignore empty records
    dataset.removeWhere((_, records) => records.isEmpty);

    // Generate records with incremented canonical time
    final hlc = canonicalTime.increment();
    final records = dataset.map((table, values) => MapEntry(
        table,
        values.map((key, value) =>
            MapEntry(key, Record(value, isDeleted, hlc, hlc)))));

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
    Iterable<String>? onlyTables,
    String? onlyNodeId,
    String? exceptNodeId,
    Hlc? modifiedOn,
    Hlc? modifiedAfter,
  }) {
    assert(onlyNodeId == null || exceptNodeId == null);
    assert(modifiedOn == null || modifiedAfter == null);

    // Modified times use the local node id
    modifiedOn = modifiedOn?.apply(nodeId: nodeId);
    modifiedAfter = modifiedAfter?.apply(nodeId: nodeId);

    // Ensure all incoming tables exist in local dataset
    onlyTables ??= tables;
    final badTables = onlyTables.toSet().difference(tables);
    if (badTables.isNotEmpty) {
      throw 'Unknown table(s): ${badTables.join(', ')}';
    }

    // Get records for the specified tables
    final changeset = {
      for (final table in onlyTables) table: getRecords(table)
    };

    // Apply remaining filters
    for (final records in changeset.values) {
      records.removeWhere((_, value) =>
          (onlyNodeId != null && value.hlc.nodeId != onlyNodeId) ||
          (exceptNodeId != null && value.hlc.nodeId == exceptNodeId) ||
          (modifiedOn != null && value.modified != modifiedOn) ||
          (modifiedAfter != null && value.modified <= modifiedAfter));
    }

    // Remove empty table changesets
    changeset.removeWhere((_, records) => records.isEmpty);

    return changeset.map((table, records) => MapEntry(
        table,
        records
            .map((key, record) => MapEntry(key, {
                  'key': key,
                  ...record.toJson(),
                }))
            .values
            .toList()));
  }

  @override
  Hlc getLastModified({String? onlyNodeId, String? exceptNodeId}) {
    assert(onlyNodeId == null || exceptNodeId == null);

    final hlc = tables
        .map((e) => getRecords(e).entries.map((e) => e.value))
        // Flatten records into single iterable
        .fold(<Record>[], (p, e) => p..addAll(e))
        // Apply filters
        .where((e) =>
            (onlyNodeId == null && exceptNodeId == null) ||
            (onlyNodeId != null && e.hlc.nodeId == onlyNodeId) ||
            (exceptNodeId != null && e.hlc.nodeId != exceptNodeId))
        // Get only modified times
        .map((e) => e.modified)
        // Get highest time
        .fold(Hlc.zero(nodeId), (p, e) => p > e ? p : e);

    return hlc;
  }

  // TODO Find a way to make this return [void] for sync implementations
  @override
  Future<void> merge(CrdtChangeset changeset) async {
    if (changeset.recordCount == 0) return;

    // Ensure all incoming tables exist in local dataset
    final badTables = changeset.keys.toSet().difference(tables);
    if (badTables.isNotEmpty) {
      throw 'Unknown table(s): ${badTables.join(', ')}';
    }

    // Ignore empty records
    changeset.removeWhere((_, records) => records.isEmpty);

    // Validate changeset and get new canonical time
    final hlc = validateChangeset(changeset);

    final newRecords = <String, Map<String, Record>>{};
    for (final entry in changeset.entries) {
      final table = entry.key;
      for (final record in entry.value) {
        final existing = getRecord(table, record['key'] as String);
        if (existing == null || record['hlc'] as Hlc > existing.hlc) {
          newRecords[table] ??= {};
          newRecords[table]![record['key'] as String] = Record(
            record['value'],
            record['is_deleted'] as bool,
            record['hlc'] as Hlc,
            hlc,
          );
        }
      }
    }

    // Write new records
    await putRecords(newRecords);
    onDatasetChanged(changeset.keys, hlc);
  }
}
