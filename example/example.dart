import 'package:crdt/map_crdt.dart';

void main() {
  var crdt1 = MapCrdt(['table']);
  var crdt2 = MapCrdt(['table']);

  print('Inserting 2 records in crdt1…');
  crdt1.put('table', 'a', 1);
  crdt1.put('table', 'b', 1);

  print('crdt1: ${crdt1.getMap('table')}');

  print('\nInserting a conflicting record in crdt2…');
  crdt2.put('table', 'a', 2);

  print('crdt2: ${crdt2.getMap('table')}');

  print('\nMerging crdt2 into crdt1…');
  crdt1.merge(crdt2.getChangeset());

  print('crdt1: ${crdt1.getMap('table')}');
}
