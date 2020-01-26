import 'package:crdt/crdt.dart';
import 'package:test/test.dart';

void main() {
  group('Basic', () {
    Crdt crdt;

    setUp(() {
      crdt = Crdt.fromMap({});
    });

    test('Put', () {
      crdt.put('x', 1);
      expect(crdt.get('x').data, 1);
    });

    test('Put sequential', () {
      crdt.put('x', 1);
      crdt.put('x', 2);
      expect(crdt.get('x').data, 2);
    });

    test('Delete value', () {
      crdt.put('x', 1);
      crdt.delete('x');
      expect(crdt.get('x').data, null);
    });
  });

  group('Seed', () {
    Crdt crdt;

    setUp(() {
      crdt = Crdt.fromMap({'x': Record(Timestamp(), 1)});
    });

    test('Seed item', () {
      expect(crdt.get('x').data, 1);
    });

    test('Seed and put', () {
      crdt.put('x', 2);
      expect(crdt.get('x').data, 2);
    });
  });

  group('Merge', () {
    Crdt crdt;
    var now = DateTime.now().millisecondsSinceEpoch;

    setUp(() {
      crdt = Crdt.fromMap({});
    });

    test('Merge older', () {
      crdt.put('x', 2);
      crdt.merge({'x': Record(Timestamp(now - 1000), 1)});
      expect(crdt.get('x').data, 2);
    });

    test('Merge very old', () {
      crdt.put('x', 2);
      crdt.merge({'x': Record(Timestamp(now - 1000000), 1)});
      expect(crdt.get('x').data, 2);
    });

    test('Merge newer', () {
      crdt.put('x', 1);
      crdt.merge({'x': Record(Timestamp(now + 1000), 2)});
      expect(crdt.get('x').data, 2);
    });

    test('Merge same', () {
      crdt.put('x', 2);
      var remoteTs = crdt.map['x'].timestamp;
      crdt.merge({'x': Record(remoteTs, 1)});
      expect(crdt.get('x').data, 2);
    });

    test('Merge older, newer counter', () {
      crdt.put('x', 2);
      crdt.merge({'x': Record(Timestamp(now - 1000, 2), 1)});
      expect(crdt.get('x').data, 2);
    });

    test('Merge same, newer counter', () {
      crdt.put('x', 1);
      var remoteTs = Timestamp(crdt.map['x'].timestamp.millis, 2);
      crdt.merge({'x': Record(remoteTs, 2)});
      expect(crdt.get('x').data, 2);
    });

    test('Merge new item', () {
      var map = {'x': Record(Timestamp(), 2)};
      crdt.merge(map);
      expect(crdt.map, map);
    });

    test('Merge deleted item', () {
      crdt.put('x', 1);
      crdt.merge({'x': Record(Timestamp(now + 1000), null)});
      expect(crdt.get('x').data, null);
    });
  });
}
