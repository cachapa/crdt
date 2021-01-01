import 'dart:io';

import 'package:crdt/crdt.dart';
import 'package:test/test.dart';

void main() {
  final hlcNow = Hlc.now('abc');

  group('Basic', () {
    CrdtMap<String, int> crdt;

    setUp(() {
      crdt = CrdtMap('abc');
    });

    test('Node ID', () {
      expect(crdt.nodeId, 'abc');
    });

    test('Empty', () {
      expect(crdt.isEmpty, isTrue);
      expect(crdt.length, 0);
      expect(crdt.map, {});
      expect(crdt.keys, []);
      expect(crdt.values, []);
    });

    test('One record', () {
      crdt.put('x', 1);

      expect(crdt.isEmpty, isFalse);
      expect(crdt.length, 1);
      expect(crdt.map, {'x': 1});
      expect(crdt.keys, ['x']);
      expect(crdt.values, [1]);
    });

    test('Empty after deleted record', () {
      crdt.put('x', 1);
      crdt.delete('x');

      expect(crdt.isEmpty, isTrue);
      expect(crdt.length, 0);
      expect(crdt.map, {});
      expect(crdt.keys, []);
      expect(crdt.values, []);
    });

    test('Put', () {
      crdt.put('x', 1);
      expect(crdt.get('x'), 1);
    });

    test('Update existing', () {
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
      crdt.put('y', 2);
      crdt.delete('x');
      expect(crdt.isDeleted('x'), isTrue);
      expect(crdt.isDeleted('y'), isFalse);
      expect(crdt.get('x'), null);
      expect(crdt.get('y'), 2);
    });

    test('Clear', () {
      crdt.put('x', 1);
      crdt.put('y', 2);
      crdt.clear();
      expect(crdt.isDeleted('x'), isTrue);
      expect(crdt.isDeleted('y'), isTrue);
      expect(crdt.get('x'), null);
      expect(crdt.get('y'), null);
    });
  });

  group('Seed', () {
    CrdtMap crdt;

    setUp(() {
      crdt = CrdtMap('abc', {'x': Record(hlcNow, 1, hlcNow)});
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
    CrdtMap<String, int> crdt;
    final now = DateTime.now().microsecondsSinceEpoch;

    setUp(() {
      crdt = CrdtMap('abc');
    });

    test('Merge older', () {
      crdt.put('x', 2);
      crdt.merge({'x': Record(Hlc(now - 10000, 0, 'xyz'), 1, hlcNow)});
      expect(crdt.get('x'), 2);
    });

    test('Merge very old', () {
      crdt.put('x', 2);
      crdt.merge({'x': Record(Hlc(now - 1000000, 0, 'xyz'), 1, hlcNow)});
      expect(crdt.get('x'), 2);
    });

    test('Merge newer', () {
      crdt.put('x', 1);
      crdt.merge({'x': Record(Hlc(now + 1000000, 0, 'xyz'), 2, hlcNow)});
      expect(crdt.get('x'), 2);
    });

    test('Disambiguate using node id', () {
      crdt.merge({'x': Record(Hlc(now, 0, 'nodeA'), 1, hlcNow)});
      crdt.merge({'x': Record(Hlc(now, 0, 'nodeB'), 2, hlcNow)});
      expect(crdt.get('x'), 1);
    });

    test('Merge same', () {
      crdt.put('x', 2);
      final remoteTs = crdt.getRecord('x').hlc;
      crdt.merge({'x': Record(remoteTs, 1, hlcNow)});
      expect(crdt.get('x'), 2);
    });

    test('Merge older, newer counter', () {
      crdt.put('x', 2);
      crdt.merge({'x': Record(Hlc(now - 1000000, 2, 'xyz'), 1, hlcNow)});
      expect(crdt.get('x'), 2);
    });

    test('Merge same, newer counter', () {
      crdt.put('x', 1);
      final remoteTs = Hlc(crdt.getRecord('x').hlc.micros, 2, 'xyz');
      crdt.merge({'x': Record(remoteTs, 2, hlcNow)});
      expect(crdt.get('x'), 2);
    });

    test('Merge new item', () {
      final map = {'x': Record<int>(Hlc.now('xyz'), 2, hlcNow)};
      crdt.merge(map);
      expect(crdt.recordMap(), map);
    });

    test('Merge deleted item', () {
      crdt.put('x', 1);
      crdt.merge({'x': Record(Hlc(now + 1000000, 0, 'xyz'), null, hlcNow)});
      expect(crdt.isDeleted('x'), isTrue);
    });

    test('Update HLC on merge', () {
      crdt.put('x', 1);
      crdt.merge({'y': Record(Hlc(now - 1000000, 0, 'xyz'), 2, hlcNow)});
      expect(crdt.values, [1, 2]);
    });
  });

  group('Serialization', () {
    test('To map', () {
      final crdt = CrdtMap('abc', {
        'x': Record<int>(Hlc(1579633503110, 0, 'abc'), 1, hlcNow),
      });
      expect(crdt.recordMap(),
          {'x': Record<int>(Hlc(1579633503110, 0, 'abc'), 1, hlcNow)});
    });

    test('jsonEncodeStringKey', () {
      final crdt = CrdtMap<String, int>('abc', {
        'x': Record(Hlc(1579633503110, 0, 'abc'), 1, hlcNow),
      });
      expect(crdt.toJson(),
          '{"x":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":1}}');
    });

    test('jsonEncodeIntKey', () {
      final crdt = CrdtMap<int, int>('abc', {
        1: Record(Hlc(1579633503110, 0, 'abc'), 1, hlcNow),
      });
      expect(crdt.toJson(),
          '{"1":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":1}}');
    });

    test('jsonEncodeDateTimeKey', () {
      final crdt = CrdtMap<DateTime, int>('abc', {
        DateTime(1974, 04, 25, 00, 20):
            Record(Hlc(1579633503110, 0, 'abc'), 1, hlcNow),
      });
      expect(crdt.toJson(),
          '{"1974-04-25 00:20:00.000":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":1}}');
    });

    test('jsonEncodeCustomClassValue', () {
      final crdt = CrdtMap<String, TestClass>('abc', {
        'x': Record(Hlc(1579633503110, 0, 'abc'), TestClass('test'), hlcNow),
      });
      expect(crdt.toJson(),
          '{"x":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":{"test":"test"}}}');
    });

    test('jsonDecodeStringKey', () {
      final crdt = CrdtMap<String, int>('abc');
      final map = CrdtJson.decode<String, int>(
          '{"x":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":1}}',
          hlcNow);
      crdt.putRecords(map);
      expect(crdt.recordMap(),
          {'x': Record<int>(Hlc(1579633503110, 0, 'abc'), 1, hlcNow)});
    });

    test('jsonDecodeIntKey', () {
      final crdt = CrdtMap<int, int>('abc');
      final map = CrdtJson.decode<int, int>(
          '{"1":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":1}}',
          hlcNow,
          keyDecoder: (key) => int.parse(key));
      crdt.putRecords(map);
      expect(crdt.recordMap(),
          {1: Record(Hlc(1579633503110, 0, 'abc'), 1, hlcNow)});
    });

    test('jsonDecodeDateTimeKey', () {
      final crdt = CrdtMap<DateTime, int>('abc');
      final map = CrdtJson.decode<DateTime, int>(
          '{"1974-04-25 00:20:00.000":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":1}}',
          hlcNow,
          keyDecoder: (key) => DateTime.parse(key));
      crdt.putRecords(map);
      expect(crdt.recordMap(), {
        DateTime(1974, 04, 25, 00, 20):
            Record(Hlc(1579633503110, 0, 'abc'), 1, hlcNow)
      });
    });

    test('jsonDecodeCustomClassValue', () {
      final crdt = CrdtMap<String, TestClass>('abc');
      final map = CrdtJson.decode<String, TestClass>(
          '{"x":{"hlc":"1970-01-19T06:47:13.475584Z-0000-abc","value":{"test":"test"}}}',
          hlcNow,
          valueDecoder: (key, value) => TestClass.fromJson(value));
      crdt.putRecords(map);
      expect(crdt.recordMap(), {
        'x': Record(Hlc(1579633503110, 0, 'abc'), TestClass('test'), hlcNow)
      });
    });
  });

  group('Delta subsets', () {
    CrdtMap crdt;
    final hlc1 = Hlc(1579633503110, 0, 'abc');
    final hlc2 = Hlc(1589633503110, 0, 'abc');
    final hlc3 = Hlc(1599633503110, 0, 'abc');

    setUp(() {
      crdt = CrdtMap('abc', {
        'x': Record(hlc1, 1, hlc1),
        'y': Record(hlc2, 2, hlc2),
      });
    });

    test('null modifiedSince', () {
      final map = crdt.recordMap();
      expect(map.length, 2);
    });

    test('modifiedSince hlc1', () {
      final map = crdt.recordMap(modifiedSince: hlc1);
      expect(map.length, 2);
    });

    test('modifiedSince hlc2', () {
      final map = crdt.recordMap(modifiedSince: hlc2);
      expect(map.length, 1);
    });

    test('modifiedSince hlc3', () {
      final map = crdt.recordMap(modifiedSince: hlc3);
      expect(map.length, 0);
    });
  });

  group('Delta sync', () {
    CrdtMap crdtA;
    CrdtMap crdtB;
    CrdtMap crdtC;

    setUp(() {
      crdtA = CrdtMap('a');
      crdtB = CrdtMap('b');
      crdtC = CrdtMap('c');

      crdtA.put('x', 1);
      sleep(Duration(milliseconds: 100));
      crdtB.put('x', 2);
    });

    test('Merge in order', () {
      _sync(crdtA, crdtC);
      _sync(crdtB, crdtC);

      expect(crdtA.get('x'), 1); // node A still contains the old value
      expect(crdtB.get('x'), 2);
      expect(crdtC.get('x'), 2);
    });

    test('Merge in reverse order', () {
      _sync(crdtB, crdtC);
      _sync(crdtA, crdtC);
      _sync(crdtB, crdtC);

      expect(crdtA.get('x'), 2);
      expect(crdtB.get('x'), 2);
      expect(crdtC.get('x'), 2);
    });
  });
}

void _sync(Crdt local, Crdt remote) {
  final time = local.canonicalTime;
  final l = local.recordMap();
  remote.merge(l);
  final r = remote.recordMap(modifiedSince: time);
  local.merge(r);
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
