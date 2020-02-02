import 'package:crdt/crdt.dart';

void main() {
  var crdt = Crdt.fromMap({}); // Equivalent to Crdt(MapStore({}));
  crdt.put('a', 1);
  print(crdt.get('a')); // 1
}
