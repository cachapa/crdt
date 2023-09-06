typedef CrdtRecord = Map<String, Object?>;
typedef CrdtTableChangeset = List<CrdtRecord>;
typedef CrdtChangeset = Map<String, CrdtTableChangeset>;

extension CrdtChangesetX on CrdtChangeset {
  /// Convenience method to get number of records in a changeset
  int get recordCount => values.fold<int>(0, (prev, e) => prev + e.length);
}
