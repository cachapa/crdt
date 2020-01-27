import 'package:crdt/crdt.dart';

void main() {
  var crdt = Crdt.fromMap({}); // Equivalent to Crdt(MapStore({}));
  crdt['a'] = 1;
  print(crdt['a']); // 1
}
