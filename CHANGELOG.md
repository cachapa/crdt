## 3.0.0-pre.2
- Allow using non-string node ids
- HLC constructor automatically detects microseconds and converts to milliseconds
- Fix missing counter overflow checks

## 3.0.0-pre.1
- Use milliseconds instead of microseconds for HLCs

## 3.0.0-pre.0
- Add `modified` field to `Record`
- Add optional parameter `modifiedSince` to 'recordMap'
- Rename MapCrdt to CrdtMap
- Move HiveCrdt project to its own repo: https://github.com/cachapa/crdt_hive

## 2.2.2
- Hlc: Add convenience `fromDate` constructor
- HiveCrdt: Fix NPE when getting a non-existing record

## 2.2.1
- Crdt: Fix encoder return type

## 2.2.0
- Crdt: Pass keys to map encoder and decoder, useful to disambiguate when parsing

## 2.1.1
- Crdt: Fix HLC timestamp generation for dart-web

## 2.1.0
- Hlc: Add `const` keywords to constructors wherever possible
- Crdt: Expose canonical time
- Crdt: Add convenience methods (isEmpty. length, etc.)
- Crdt: Add encoders and decoders to serialization helpers
- Crdt: Remove delta subsets using the record's HLC since it can lead to incomplete merges
- Crdt: Fix issue where canonical time wasn't being incremented on merge
- Crdt: Fix NPE when getting non-existent value
- HiveCrdt: Store record modified time
- HiveCrdt: Retrieve delta changesets based on modified times
- HiveCrdt: `between()` returns values instead of records
- HiveCrdt: `watch()` returns `MapEntry` instead of `BoxEvent`
- HiveCrdt: Fix DateTime key serialization

## 2.0.0
- Remove CrdtStore.
- Make Crdt abstract.
- Remove watches (they can be added in subclasses - see HiveCrdt).
- Add MapCrdt, a CRDT backed by a standard Map useful for testing or for volatile datasets.
- Add HiveCrdt as a submodule, A CRDT backed by a [Hive](https://pub.dev/packages/hive) store.

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
