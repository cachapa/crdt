import 'dart:math';

import 'package:crdt/map_crdt.dart';

/// Weak node id generator. Use a UUID generator for production instead.
String randomId() => '${Random().nextInt(2 ^ 32)}';

void main() {
  var crdt1 = MapCrdt(randomId(), ['table']);
  var crdt2 = MapCrdt(randomId(), ['table']);

  print('Inserting 2 records in crdt1…');
  crdt1.put('table', 'a', {'v': 1});
  crdt1.put('table', 'b', {'v': 1});

  print('crdt1: ${crdt1.getMap('table')}');

  print('\nInserting a conflicting record in crdt2…');
  crdt2.put('table', 'a', {'v': 2});

  print('crdt2: ${crdt2.getMap('table')}');

  print('\nMerging crdt2 into crdt1…');
  crdt1.merge(crdt2.getChangeset());

  print('crdt1: ${crdt1.getMap('table')}');
}
