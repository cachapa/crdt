import 'package:crdt/crdt.dart';

void main() {
  var crdt = Crdt('node_id', MapStore({}));
  crdt.put('a', 1);
  print(crdt.get('a')); // 1
}
