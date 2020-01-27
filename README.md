Dart implementation of Conflict-free Replicated Data Types (CRDTs).

This implementation is heavily influenced by James Long's talk [CRTDs for Mortals](https://www.dotconferences.com/2019/12/james-long-crdts-for-mortals) and includes a Dart-native implementation of Hybrid Local Clocks (HLC) based the paper [Logical Physical Clocks and Consistent Snapshots in Globally Distributed Databases](https://cse.buffalo.edu/tech-reports/2014-04.pdf).

## Usage

The `Crdt` class works as a layer on top of a map. The simplest way to experiment is to initialise it an empty map:

```dart
import 'package:crdt/crdt.dart';

main() {
  var crdt = Crtd.fromMap({});
}
```

You'll probably want to can subclass the [Store](https://github.com/cachapa/crdt/blob/master/lib/src/store.dart) class if you want to implement any sort of persistence though.

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/cachapa/crdt/issues
