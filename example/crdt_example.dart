import 'package:crdt/crdt.dart';

void main() {
  var crdt = CrdtMap('node_id', MapStore({}));
  crdt['a'] = 1;
  print(crdt['a']); // 1
}
