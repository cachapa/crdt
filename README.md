Dart implementation of Conflict-free Replicated Data Types (CRDTs).

This project is heavily influenced by James Long's talk [CRTDs for Mortals](https://www.dotconferences.com/2019/12/james-long-crdts-for-mortals) and includes a Dart-native implementation of Hybrid Local Clocks (HLC) based on the paper [Logical Physical Clocks and Consistent Snapshots in Globally Distributed Databases](https://cse.buffalo.edu/tech-reports/2014-04.pdf).

It has [zero external dependencies](https://github.com/cachapa/crdt/blob/master/pubspec.yaml), so it should run everywhere where Dart runs.

## Usage

The `Crdt` class works as a layer on top of a map. The simplest way to experiment is to initialise it an empty map:

```dart
import 'package:crdt/crdt.dart';

void main() {
  var crdt = MapCrdt('node_id');

  // Insert a record
  crdt.put('a', 1);
  // Read the record
  print('Record: ${crdt.get('a')}');

  // Export the CRDT as Json
  final json = crdt.toJson();
  // Send to remote node
  final remoteJson = sendToRemote(json);
  // Merge remote CRDT with local
  crdt.mergeJson(remoteJson);
  // Verify updated record
  print('Record after merging: ${crdt.get('a')}');
}

// Mock sending the CRDT to a remote node and getting an updated one back
String sendToRemote(String json) {
  final hlc = Hlc.now('another_nodeId');
  return '{"a":{"hlc":"$hlc","value":2}}';
}
```

You'll probably want to implement some sort of persistent storage by subclassing the `Crdt` class. An example using [Hive](https://pub.dev/packages/hive) is provided in [hive_crdt](https://github.com/cachapa/hive_crdt).

## Example

A simple example is provided with this project, otherwise for a real-world application check the `tudo` to-do app: [client](https://github.com/cachapa/tudo_client) & [server](https://github.com/cachapa/tudo_server).

## Features and bugs

Please file feature requests and bugs at the [issue tracker](https://github.com/cachapa/crdt/issues).
