import 'package:crdt/crdt.dart';
import 'package:test/test.dart';

void main() {
  group('Basic', () {
    Crdt crdt;

    setUp(() {
      crdt = Crdt.fromMap({});
    });

    test('Put', () {
      crdt['x'] = 1;
      expect(crdt['x'].value, 1);
    });

    test('Put sequential', () {
      crdt['x'] = 1;
      crdt['x'] = 2;
      expect(crdt['x'].value, 2);
    });

    test('Delete value', () {
      crdt['x'] = 1;
      crdt.delete('x');
      expect(crdt['x'].value, null);
    });
  });

  group('Seed', () {
    Crdt crdt;

    setUp(() {
      crdt = Crdt.fromMap({'x': Record(Timestamp(), 1)});
    });

    test('Seed item', () {
      expect(crdt['x'].value, 1);
    });

    test('Seed and put', () {
      crdt['x'] = 2;
      expect(crdt['x'].value, 2);
    });
  });

  group('Merge', () {
    Crdt crdt;
    var now = DateTime.now().millisecondsSinceEpoch;

    setUp(() {
      crdt = Crdt.fromMap({});
    });

    test('Merge older', () {
      crdt['x'] = 2;
      crdt.merge({'x': Record(Timestamp(now - 1000), 1)});
      expect(crdt['x'].value, 2);
    });

    test('Merge very old', () {
      crdt['x'] = 2;
      crdt.merge({'x': Record(Timestamp(now - 1000000), 1)});
      expect(crdt['x'].value, 2);
    });

    test('Merge newer', () {
      crdt['x'] = 1;
      crdt.merge({'x': Record(Timestamp(now + 1000), 2)});
      expect(crdt['x'].value, 2);
    });

    test('Merge same', () {
      crdt['x'] = 2;
      var remoteTs = crdt.map['x'].timestamp;
      crdt.merge({'x': Record(remoteTs, 1)});
      expect(crdt['x'].value, 2);
    });

    test('Merge older, newer counter', () {
      crdt['x'] = 2;
      crdt.merge({'x': Record(Timestamp(now - 1000, 2), 1)});
      expect(crdt['x'].value, 2);
    });

    test('Merge same, newer counter', () {
      crdt['x'] = 1;
      var remoteTs = Timestamp(crdt.map['x'].timestamp.millis, 2);
      crdt.merge({'x': Record(remoteTs, 2)});
      expect(crdt['x'].value, 2);
    });

    test('Merge new item', () {
      var map = {'x': Record(Timestamp(), 2)};
      crdt.merge(map);
      expect(crdt.map, map);
    });

    test('Merge deleted item', () {
      crdt['x'] = 1;
      crdt.merge({'x': Record(Timestamp(now + 1000), null)});
      expect(crdt['x'].value, null);
    });
  });
}
