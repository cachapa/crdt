import 'package:crdt/crdt.dart';
import 'package:test/test.dart';

void main() {
  group('Basic', () {
    MapCrdt<String, int> crdt;

    setUp(() {
      crdt = MapCrdt('abc');
    });

    test('Put', () {
      crdt.put('x', 1);
      expect(crdt.get('x'), 1);
    });

    test('Put sequential', () {
      crdt.put('x', 1);
      crdt.put('x', 2);
      expect(crdt.get('x'), 2);
    });

    test('Put many', () {
      crdt.putAll({'x': 2, 'y': 3});
      expect(crdt.get('x'), 2);
      expect(crdt.get('y'), 3);
    });

    test('Delete value', () {
      crdt.put('x', 1);
      crdt.delete('x');
      expect(crdt.isDeleted('x'), isTrue);
      expect(crdt.get('x'), null);
    });
  });

  group('Seed', () {
    MapCrdt crdt;

    setUp(() {
      crdt = MapCrdt('abc', {'x': Record(Hlc.now('abc'), 1)});
    });

    test('Seed item', () {
      expect(crdt.get('x'), 1);
    });

    test('Seed and put', () {
      crdt.put('x', 2);
      expect(crdt.get('x'), 2);
    });
  });

  group('Merge', () {
    MapCrdt<String, int> crdt;
    final now = DateTime.now().microsecondsSinceEpoch;

    setUp(() {
      crdt = MapCrdt('abc');
    });

    test('Merge older', () {
      crdt.put('x', 2);
      crdt.merge({'x': Record(Hlc(now - 10000, 0, 'xyz'), 1)});
      expect(crdt.get('x'), 2);
    });

    test('Merge very old', () {
      crdt.put('x', 2);
      crdt.merge({'x': Record(Hlc(now - 1000000, 0, 'xyz'), 1)});
      expect(crdt.get('x'), 2);
    });

    test('Merge newer', () {
      crdt.put('x', 1);
      crdt.merge({'x': Record(Hlc(now + 1000000, 0, 'xyz'), 2)});
      expect(crdt.get('x'), 2);
    });

    test('Disambiguate using node id', () {
      crdt.merge({'x': Record(Hlc(now, 0, 'nodeA'), 1)});
      crdt.merge({'x': Record(Hlc(now, 0, 'nodeB'), 2)});
      expect(crdt.get('x'), 1);
    });

    test('Merge same', () {
      crdt.put('x', 2);
      final remoteTs = crdt.getRecord('x').hlc;
      crdt.merge({'x': Record(remoteTs, 1)});
      expect(crdt.get('x'), 2);
    });

    test('Merge older, newer counter', () {
      crdt.put('x', 2);
      crdt.merge({'x': Record(Hlc(now - 1000000, 2, 'xyz'), 1)});
      expect(crdt.get('x'), 2);
    });

    test('Merge same, newer counter', () {
      crdt.put('x', 1);
      final remoteTs = Hlc(crdt.getRecord('x').hlc.micros, 2, 'xyz');
      crdt.merge({'x': Record(remoteTs, 2)});
      expect(crdt.get('x'), 2);
    });

    test('Merge new item', () {
      final map = {'x': Record<int>(Hlc.now('xyz'), 2)};
      crdt.merge(map);
      expect(crdt.recordMap(), map);
    });

    test('Merge deleted item', () {
      crdt.put('x', 1);
      crdt.merge({'x': Record(Hlc(now + 1000000, 0, 'xyz'), null)});
      expect(crdt.isDeleted('x'), isTrue);
    });
  });

  group('Serialization', () {
    test('To map', () {
      final crdt = MapCrdt('abc', {
        'x': Record<int>(Hlc(1579633503110, 0, 'abc'), 1),
      });
      expect(crdt.recordMap(),
          {'x': Record<int>(Hlc(1579633503110, 0, 'abc'), 1)});
    });

    test('jsonEncodeStringKey', () {
      final crdt = MapCrdt<String, int>('abc', {
        'x': Record(Hlc(1579633503110, 0, 'abc'), 1),
      });
      expect(crdt.toJson(),
          '{"x":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":1}}');
    });

    test('jsonEncodeIntKey', () {
      final crdt = MapCrdt<int, int>('abc', {
        1: Record(Hlc(1579633503110, 0, 'abc'), 1),
      });
      expect(crdt.toJson(),
          '{"1":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":1}}');
    });

    test('jsonEncodeDateTimeKey', () {
      final crdt = MapCrdt<DateTime, int>('abc', {
        DateTime(1974, 04, 25, 00, 20): Record(Hlc(1579633503110, 0, 'abc'), 1),
      });
      expect(crdt.toJson(),
          '{"1974-04-25 00:20:00.000":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":1}}');
    });

    test('jsonEncodeCustomClassValue', () {
      final crdt = MapCrdt<String, TestClass>('abc', {
        'x': Record(Hlc(1579633503110, 0, 'abc'), TestClass('test')),
      });
      expect(crdt.toJson(),
          '{"x":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":{"test":"test"}}}');
    });

    test('jsonDecodeStringKey', () {
      final crdt = MapCrdt<String, int>('abc');
      final map = CrdtJson.decode<String, int>(
          '{"x":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":1}}');
      crdt.putRecords(map);
      expect(crdt.recordMap(),
          {'x': Record<int>(Hlc(1579633503110, 0, 'abc'), 1)});
    });

    test('jsonDecodeIntKey', () {
      final crdt = MapCrdt<int, int>('abc');
      final map = CrdtJson.decode<int, int>(
          '{"1":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":1}}',
          keyDecoder: (key) => int.parse(key));
      crdt.putRecords(map);
      expect(crdt.recordMap(), {1: Record(Hlc(1579633503110, 0, 'abc'), 1)});
    });

    test('jsonDecodeDateTimeKey', () {
      final crdt = MapCrdt<DateTime, int>('abc');
      final map = CrdtJson.decode<DateTime, int>(
          '{"1974-04-25 00:20:00.000":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":1}}',
          keyDecoder: (key) => DateTime.parse(key));
      crdt.putRecords(map);
      expect(crdt.recordMap(), {
        DateTime(1974, 04, 25, 00, 20): Record(Hlc(1579633503110, 0, 'abc'), 1)
      });
    });

    test('jsonDecodeCustomClassValue', () {
      final crdt = MapCrdt<String, TestClass>('abc');
      final map = CrdtJson.decode<String, TestClass>(
          '{"x":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":{"test":"test"}}}',
          valueDecoder: (value) => TestClass.fromJson(value));
      crdt.putRecords(map);
      expect(crdt.recordMap(),
          {'x': Record(Hlc(1579633503110, 0, 'abc'), TestClass('test'))});
    });
  });
}

class TestClass {
  final String test;

  TestClass(this.test);

  static TestClass fromJson(dynamic map) => TestClass(map['test']);

  Map<String, dynamic> toJson() => {'test': test};

  @override
  bool operator ==(other) => other is TestClass && test == other.test;

  @override
  String toString() => test;
}
