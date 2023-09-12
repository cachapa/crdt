import 'hlc.dart';

typedef CrdtRecord = Map<String, Object?>;
typedef CrdtTableChangeset = List<CrdtRecord>;
typedef CrdtChangeset = Map<String, CrdtTableChangeset>;

/// Utility function to simplify parsing untyped changesets.
/// It performs all necessary casts to satisfy Dart's type system, and parses
/// Hlc timestamps.
/// Useful when receiving datasets over the wire.
CrdtChangeset parseCrdtChangeset(Map<String, dynamic> message) =>
    // Cast payload to CrdtChangeset
    message.map((table, records) => MapEntry(
        table,
        (records as List)
            .cast<Map<String, dynamic>>()
            // Parse Hlc
            .map((e) => e.map((key, value) =>
                MapEntry(key, key == 'hlc' ? Hlc.parse(value) : value)))
            .toList()));

extension CrdtChangesetX on CrdtChangeset {
  /// Convenience method to get number of records in a changeset
  int get recordCount => values.fold<int>(0, (prev, e) => prev + e.length);
}
