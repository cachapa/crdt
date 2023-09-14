Dart implementation of Conflict-free Replicated Data Types (CRDTs).

This project is heavily influenced by James Long's talk [CRTDs for Mortals](https://www.dotconferences.com/2019/12/james-long-crdts-for-mortals) and includes a Dart-native implementation of Hybrid Local Clocks (HLC) based on the paper [Logical Physical Clocks and Consistent Snapshots in Globally Distributed Databases](https://cse.buffalo.edu/tech-reports/2014-04.pdf) (pdf).

It has [minimal external dependencies](https://github.com/cachapa/crdt/blob/master/pubspec.yaml), so it should run anywhere where Dart runs, which is pretty much everywhere.

The `Crdt` class implements CRDT conflict resolution and serves as a storage-agnostic interface for specific implementations. Als included with this package is `MapCrdt`, an ephemeral implementation using Dart HashMaps.

Other implementations include (so far):
- [hive_crdt](https://github.com/cachapa/hive_crdt), a no-sql implementation using [Hive](https://pub.dev/packages/hive) as persistent storage.
- [sql_crdt](https://github.com/cachapa/sql_crdt), an abstract implementation for using relational databases as a data storage backend.
- [sqlite_crdt](https://github.com/cachapa/sqlite_crdt), an implementation using Sqlite for storage, useful for mobile or small projects.
- [postgres_crdt](https://github.com/cachapa/postgres_crdt), a `sql_crdt` that benefits from PostgreSQL's performance and scalability intended for backend applications.

See also [crdt_sync](https://github.com/cachapa/crdt_sync), a turnkey approach for real-time network synchronization of `Crdt` nodes.

## Usage

The simplest way to experiment with this package is to use the provided `MapCrdt` implementation:

```dart
import 'package:crdt/map_crdt.dart';

void main() {
  var crdt1 = MapCrdt(['table']);
  var crdt2 = MapCrdt(['table']);

  print('Inserting 2 records in crdt1…');
  crdt1.put('table', 'a', 1);
  crdt1.put('table', 'b', 1);

  print('crdt1: ${crdt1.getMap('table')}');

  print('\nInserting a conflicting record in crdt2…');
  crdt2.put('table', 'a', 2);

  print('crdt2: ${crdt2.getMap('table')}');

  print('\nMerging crdt2 into crdt1…');
  crdt1.merge(crdt2.getChangeset());

  print('crdt1: ${crdt1.getMap('table')}');
}
```

## Implementations

`crdt` is currently helping build local-first experiences for:

- [Libra](https://libra-app.eu) a weigh management app with 1M+ installs.
- [tudo](https://github.com/cachapa/tudo) an open-source simple to-do app + backend.

Are you using this package in your project? Let me know!

## Features and bugs

Please file feature requests and bugs at the [issue tracker](https://github.com/cachapa/crdt/issues).
