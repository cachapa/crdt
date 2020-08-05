import 'package:hive_crdt/hive_crdt.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  var crdt = await HiveCrdt.open(Uuid().v4(), 'node_id');
  crdt.put('a', 1);
  print(crdt.get('a')); // 1
}
