import 'package:crdt/crdt.dart';

void main() {
  var crdt = MapCrdt('node_id');
  crdt.put('a', 1);
  print(crdt.get('a')); // 1
}
