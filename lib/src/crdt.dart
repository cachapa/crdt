import 'dart:async';

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import 'hlc.dart';
import 'types.dart';

String generateNodeId() => Uuid().v4();

abstract mixin class Crdt {
  late Hlc _canonicalTime;

  /// Represents the latest logical time seen in the stored data.
  Hlc get canonicalTime => _canonicalTime;

  /// Updates the canonical time.
  /// Should *never* be called from outside implementations.
  @protected
  set canonicalTime(Hlc value) => _canonicalTime = value;

  final _tableChangesController =
      StreamController<({Hlc hlc, Iterable<String> tables})>.broadcast();

  /// Get this CRDT's node id
  String get nodeId => canonicalTime.nodeId;

  /// Emits a list of the tables affected by changes in the database and the
  /// timestamp at which they happened.
  /// Useful for guaranteeing atomic merges across multiple tables.
  Stream<({Hlc hlc, Iterable<String> tables})> get onTablesChanged =>
      _tableChangesController.stream;

  /// Returns the last modified timestamp, optionally filtering for or against a
  /// specific node id.
  /// Useful to get "modified since" timestamps for synchronization.
  /// Returns [Hlc.zero] if no timestamp is found.
  FutureOr<Hlc> getLastModified({String? onlyNodeId, String? exceptNodeId});

  /// Get a [Changeset] using the provided [changesetQueries].
  ///
  /// Set the filtering parameters to to generate subsets:
  /// [onlyTables] only records from the specified tables. Leave empty for all.
  /// [onlyNodeId] only records set by the specified node.
  /// [exceptNodeId] only records not set by the specified node.
  /// [modifiedOn] records whose modified at this exact [Hlc].
  /// [modifiedAfter] records modified after the specified [Hlc].
  FutureOr<CrdtChangeset> getChangeset({
    Iterable<String>? onlyTables,
    String? onlyNodeId,
    String? exceptNodeId,
    Hlc? modifiedOn,
    Hlc? modifiedAfter,
  });

  /// Checks if changeset is valid. This method is intended for implementations
  /// and shouldn't generally be called from outside.
  ///
  /// Returns the highest hlc in the changeset or the canonical time, if higher.
  @protected
  Hlc validateChangeset(CrdtChangeset changeset) {
    var hlc = canonicalTime;
    // Iterate through all the incoming timestamps to:
    // - Check for invalid entries (throws exception)
    // - Update local canonical time if needed
    changeset.forEach((table, records) {
      for (final record in records) {
        final recordHlc = switch (record['hlc']) {
          final Hlc hlc => hlc,
          final String hlc => Hlc.parse(hlc),
          _ => throw InvalidHlcError(
              'Invalid hlc: ${record['hlc']}', table, record),
        };
        try {
          hlc = hlc.merge(recordHlc);
        } catch (e) {
          throw MergeError(e, table, record);
        }
      }
    });
    return hlc;
  }

  /// Merge [changeset] with the local dataset.
  FutureOr<void> merge(CrdtChangeset changeset);

  /// Notifies listeners and updates the canonical time.
  @protected
  void onDatasetChanged(Iterable<String> affectedTables, Hlc hlc) {
    assert(hlc >= canonicalTime);

    // Bump canonical time if the new timestamp is higher
    if (hlc > canonicalTime) canonicalTime = hlc;

    _tableChangesController.add((hlc: hlc, tables: affectedTables));
  }
}

/// Thrown on merge errors when the hlc is invalid or not present.
class InvalidHlcError {
  final Object? hlc;
  final String table;
  final Map<String, Object?> record;

  InvalidHlcError(this.hlc, this.table, this.record);

  @override
  String toString() => 'Invalid hlc: $hlc.\n$table: $record';
}

/// Thrown on merge errors. Contains the failed payload to help with debugging
/// large datasets.
class MergeError<T> {
  final T error;
  final String table;
  final Map<String, Object?> record;

  MergeError(this.error, this.table, this.record);

  @override
  String toString() => '$error\n$table: $record';
}
