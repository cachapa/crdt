import 'dart:async';

import 'package:meta/meta.dart' show protected;

import 'changeset.dart';
import 'hlc.dart';

abstract class Crdt {
  /// Get this CRDT's node id
  final String nodeId;

  /// The collections monitored by this CRDT.
  Iterable<String> get collections;

  /// Represents the latest logical timestamp seen in the stored data.
  /// See [Hlc.toTimestamp].
  int get canonicalTime;

  /// Helper method to generate an HLC from [canonicalTime].
  Hlc get canonicalHlc => Hlc.fromLogicalTime(canonicalTime, nodeId);

  final _tableChangesController =
      StreamController<({int timestamp, Iterable<String> tables})>.broadcast();

  /// Emits a list of the tables affected by changes in the database and the
  /// timestamp at which they happened.
  /// Useful for guaranteeing atomic merges across multiple tables.
  Stream<({int timestamp, Iterable<String> tables})> get onTablesChanged =>
      _tableChangesController.stream;

  Crdt(this.nodeId);

  /// Returns the last modified timestamp, optionally filtering for or against a
  /// specific node id.
  /// Useful to get "modified since" timestamps for synchronization.
  /// Returns 0 if no timestamp is found.
  FutureOr<int> getLastModified({String? onlyNodeId, String? exceptNodeId});

  /// Get a [Changeset] using the provided [changesetQueries].
  ///
  /// Set [collectionFilter] to [null] disable filtering.
  /// Set map values to [null] to filter only by collection name.
  ///
  /// [onlyNodeId] only records set by the specified node.
  /// Useful for clients to send local changes only.
  ///
  /// [exceptNodeId] all records not set by the specified node.
  /// Useful for servers to avoid sending clients their own changes.
  ///
  /// [modifiedOn] records modified at this exact [Hlc] timestamp.
  /// Used for sending atomic real-time updates on data changes.
  ///
  /// [modifiedAfter] records modified after the specified [Hlc] timestamp.
  /// Useful for syncing delta updates.
  FutureOr<CrdtChangeset> getChangeset({
    String? onlyNodeId,
    String? exceptNodeId,
    int? modifiedOn,
    int? modifiedAfter,
  });

  /// Checks if changeset is valid. This method is intended for implementations
  /// and shouldn't generally be called from outside.
  ///
  /// Returns the highest logical time in the changeset or the canonical time,
  /// if higher.
  @protected
  int validateChangeset(CrdtChangeset changeset) {
    var hlc = canonicalHlc;
    // Iterate through all the incoming timestamps to:
    // - Check for invalid entries (throws exception)
    // - Update local canonical time if needed
    changeset.forEach((collection, records) {
      for (final record in records) {
        try {
          hlc = hlc.merge(record.hlc);
        } catch (e) {
          throw MergeError(e, collection, record);
        }
      }
    });
    return hlc.logicalTime;
  }

  /// Merge [changeset] with the local dataset.
  FutureOr<void> merge(CrdtChangeset changeset);

  /// Notifies listeners
  @protected
  void onDatasetChanged(Iterable<String> affectedTables, int timestamp) {
    assert(timestamp >= canonicalTime);

    // Don't notify if there are no changes
    if (affectedTables.isEmpty) return;

    _tableChangesController.add((timestamp: timestamp, tables: affectedTables));
  }
}

/// Thrown on merge errors. Contains the failed payload to help with debugging
/// large datasets.
class MergeError<T> {
  final T error;
  final String table;
  final CrdtRecord record;

  MergeError(this.error, this.table, this.record);

  @override
  String toString() => '$error\n$table: $record';
}
