## 2.0.0

- Removed CrdtStore.
- Made Crdt abstract.
- Removed watches (they can be added in subclasses - see HiveCrdt).
- Added MapCrdt, a CRDT backed by a standard Map useful for testing or for volatile datasets.

## 1.2.2

- Fix incrementing the HLC when merging newer records.
- Fix counter not being able to reach maximum (0xFFFF)

## 1.2.1

- Remove unnecessary Future in `Crdt.values` getter.

## 1.2.0

- Breaking: `Crdt.get()` now returns the value (or `null`) rather than the record. Use `Crdt.getRecord()` for the previous behaviour.
- API Change: Getter methods on both `Crdt` and `Store` are now synchronous.
- API Change: `Crdt.Clear()` now accepts `purgeRecords` to determine if records should be purged or marked as deleted.
- Add `Crdt.watch()` and `Store.watch()` to monitor the CRDT for changes.
- Add `Crdt.isDeleted()` to check if a record has been deleted.

## 1.1.1

- Add values getter which retrieves all values as list, excluding deleted records

## 1.1.0

- HLCs implement Comparable
- Support typed key and values
- Refactor CRDT and Store to replace index operators with getters and setters
- Add clear() method
- Add JSON de/serialisation helper methods

## 1.0.0

- Initial version
