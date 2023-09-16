## 5.1.2

- Add `isDeleted` flag to watched change events

## 5.1.1

- Remove timezone drift from `Hlc.toString`

## 5.1.0

- Fix `Hlc` in Dart web
- Breaking: replaced `millis` time representation with `DateTime` object
- Breaking: removed `logicalTime` operators from `Hlc` since they failed silently in 32-bit environments
- Add `watch` method to `MapCrdtBase`

## 5.0.2

- Add convenience function to parse over-the-wire changesets

## 5.0.1

- Fix dependency compatibility with the Flutter SDK

## 5.0.0

This version introduces a major refactor which results in multiple breaking changes. This was done with the intention to make this package the basis for a family of CRDT libraries.

Another motivation was to make this package compatible with [crdt_sync](https://github.com/cachapa/crdt_sync), thereby abstracting the communication protocol and network management for real-time remote synchronization.

Changes:
- Simplified API
- Removed insert and get operations to make package more storage-agnostic
- Made most methods optionally async
- Reimplemented CrdtMap as a zero-dependency implementation

## 4.0.3

- Update to Dart 3

## 4.0.2

- Add purge() method to reset the data store

## 4.0.1

- Fix edge case when merging remote records

## 4.0.0

- Migrate to Dart null safety

## 3.0.0

- Use milliseconds instead of microseconds for HLCs
- Allow using non-string node ids
- Allow watching for changes
- Add `modified` field to `Record`
- Add optional parameter `modifiedSince` to 'recordMap' to generate delta sets
- Make basic tests available to subclasses
- Move HiveCrdt project to its own repo: https://github.com/cachapa/hive_crdt

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
