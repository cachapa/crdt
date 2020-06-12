import 'package:crdt/crdt.dart';

void main() {
  var crdt = CrdtMap(MapStore('node_id'));
  crdt['a'] = 1;
  print(crdt['a']); // 1
}
