import 'package:crdt/map_crdt.dart';

void main() {
  var crdt1 = MapCrdt(['users']);
  var crdt2 = MapCrdt(['users']);

  print('Inserting 2 records in crdt1…');
  crdt1.put('users', '1', {'name': 'John Doe'});
  crdt1.put('users', '2', {'name': 'Jane Doe'});

  print('crdt1: ${crdt1.getMap('users')}');

  print('\nInserting a conflicting record in crdt2…');
  crdt2.put('users', '2', {'name': 'Santa Claus'});

  print('crdt2: ${crdt2.getMap('users')}');

  print('\nMerging crdt2 into crdt1…');
  crdt1.merge(crdt2.getChangeset());

  print('crdt1: ${crdt1.getMap('users')}');
}
