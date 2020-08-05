A CRDT backed by a Hive store.

## Usage

A simple usage example:

```dart
import 'package:hive_crdt/hive_crdt.dart';

main() async {
  var crdt = await HiveCrdt.open('test', nodeId);
  crdt.put('x', 1);
  crdt.get('x');  // 1
}
```
