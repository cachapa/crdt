import 'dart:convert';

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
      expect(crdt['x'].isDeleted, isTrue);
    });
  });

  group('Seed', () {
    Crdt crdt;

    setUp(() {
      crdt = Crdt.fromMap({'x': Record(Hlc(), 1)});
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
    Crdt<int> crdt;
    var now = DateTime.now().microsecondsSinceEpoch;

    setUp(() {
      crdt = Crdt.fromMap({});
    });

    test('Merge older', () {
      crdt['x'] = 2;
      crdt.merge({'x': Record(Hlc(now - 10000), 1)});
      expect(crdt['x'].value, 2);
    });

    test('Merge very old', () {
      crdt['x'] = 2;
      crdt.merge({'x': Record(Hlc(now - 1000000), 1)});
      expect(crdt['x'].value, 2);
    });

    test('Merge newer', () {
      crdt['x'] = 1;
      crdt.merge({'x': Record(Hlc(now + 1000000), 2)});
      expect(crdt['x'].value, 2);
    });

    test('Merge same', () {
      crdt['x'] = 2;
      var remoteTs = crdt.map['x'].hlc;
      crdt.merge({'x': Record(remoteTs, 1)});
      expect(crdt['x'].value, 2);
    });

    test('Merge older, newer counter', () {
      crdt['x'] = 2;
      crdt.merge({'x': Record(Hlc(now - 1000000, 2), 1)});
      expect(crdt['x'].value, 2);
    });

    test('Merge same, newer counter', () {
      crdt['x'] = 1;
      var remoteTs = Hlc(crdt.map['x'].hlc.micros, 2);
      crdt.merge({'x': Record(remoteTs, 2)});
      expect(crdt['x'].value, 2);
    });

    test('Merge new item', () {
      var map = {'x': Record<int>(Hlc(), 2)};
      crdt.merge(map);
      expect(crdt.map, map);
    });

    test('Merge deleted item', () {
      crdt['x'] = 1;
      crdt.merge({'x': Record(Hlc(now + 1000000), null)});
      expect(crdt['x'].isDeleted, isTrue);
    });
  });

  group('Serialization', () {
    Crdt<int> crdt;

    setUp(() {
      crdt = Crdt.fromMap({'x': Record<int>(Hlc(1579633503110), 1)});
    });

    test('To map', () {
      expect(crdt.map, {'x': Record<int>(Hlc(1579633503110), 1)});
    });

    test('jsonEncode', () {
      expect(jsonEncode(crdt), '{"x":{"hlc":1579633475584,"value":1}}');
    });

    test('jsonDecode', () {
      var jsonMap = jsonDecode('{"x":{"hlc":1579633475584,"value":1}}');
      var decoded = Crdt<int>.fromJson(jsonMap);
      expect(decoded.map, crdt.map);
    });
  });

  group('Custom class serialization', () {
    Crdt crdt;

    setUp(() {
      crdt = Crdt.fromMap(
          {'x': Record<TestClass>(Hlc(1579633503110), TestClass('test'))});
    });

    test('To map', () {
      expect(crdt.map,
          {'x': Record<TestClass>(Hlc(1579633503110), TestClass('test'))});
    });

    test('jsonEncode', () {
      expect(jsonEncode(crdt.map),
          '{"x":{"hlc":1579633475584,"value":{"test":"test"}}}');
    });

    test('jsonDecode', () {
      var jsonMap =
          jsonDecode('{"x":{"hlc":1579633475584,"value":{"test":"test"}}}');
      var decoded = Crdt<TestClass>.fromJson(jsonMap, TestClass.fromJson);
      expect(decoded.map, crdt.map);
    });
  });
}

class TestClass {
  final String test;

  TestClass(this.test);

  static TestClass fromJson(Map<String, dynamic> map) => TestClass(map['test']);

  Map<String, dynamic> toJson() => {'test': test};

  @override
  bool operator ==(other) => other is TestClass && test == other.test;

  @override
  String toString() => test;
}
