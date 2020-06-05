import 'dart:convert';

import 'package:crdt/crdt.dart';
import 'package:test/test.dart';

void main() {
  group('Basic', () {
    Crdt<String, int> crdt;

    setUp(() {
      crdt = Crdt('abc');
    });

    test('Put', () async {
      await crdt.put('x', 1);
      var value = crdt.get('x');
      expect(value, 1);
    });

    test('Put sequential', () async {
      await crdt.put('x', 1);
      await crdt.put('x', 2);
      var value = crdt.get('x');
      expect(value, 2);
    });

    test('Put many', () async {
      await crdt.putAll({'x': 2, 'y': 3});
      expect(crdt.get('x'), 2);
      expect(crdt.get('y'), 3);
    });

    test('Delete value', () async {
      await crdt.put('x', 1);
      await crdt.delete('x');
      expect(crdt.isDeleted('x'), isTrue);
    });
  });

  group('Seed', () {
    Crdt crdt;

    setUp(() {
      crdt = Crdt('abc', MapStore({'x': Record(Hlc.now('abc'), 1)}));
    });

    test('Seed item', () {
      var value = crdt.get('x');
      expect(value, 1);
    });

    test('Seed and put', () async {
      await crdt.put('x', 2);
      var value = crdt.get('x');
      expect(value, 2);
    });
  });

  group('Merge', () {
    Crdt<String, int> crdt;
    var now = DateTime.now().microsecondsSinceEpoch;

    setUp(() {
      crdt = Crdt('abc');
    });

    test('Merge older', () async {
      await crdt.put('x', 2);
      await crdt.merge({'x': Record(Hlc(now - 10000, 0, 'abc'), 1)});
      var value = crdt.get('x');
      expect(value, 2);
    });

    test('Merge very old', () async {
      await crdt.put('x', 2);
      await crdt.merge({'x': Record(Hlc(now - 1000000, 0, 'abc'), 1)});
      var value = crdt.get('x');
      expect(value, 2);
    });

    test('Merge newer', () async {
      await crdt.put('x', 1);
      await crdt.merge({'x': Record(Hlc(now + 1000000, 0, 'xyz'), 2)});
      var value = crdt.get('x');
      expect(value, 2);
    });

    test('Merge same', () async {
      await crdt.put('x', 2);
      var remoteTs = crdt.getRecord('x').hlc;
      await crdt.merge({'x': Record(remoteTs, 1)});
      var value = crdt.get('x');
      expect(value, 2);
    });

    test('Merge older, newer counter', () async {
      await crdt.put('x', 2);
      await crdt.merge({'x': Record(Hlc(now - 1000000, 2, 'abc'), 1)});
      var value = crdt.get('x');
      expect(value, 2);
    });

    test('Merge same, newer counter', () async {
      await crdt.put('x', 1);
      var remoteTs = Hlc(crdt.getRecord('x').hlc.micros, 2, 'xyz');
      await crdt.merge({'x': Record(remoteTs, 2)});
      var value = crdt.get('x');
      expect(value, 2);
    });

    test('Merge new item', () async {
      var map = {'x': Record<int>(Hlc.now('abc'), 2)};
      await crdt.merge(map);
      expect(crdt.getMap(), map);
    });

    test('Merge deleted item', () async {
      await crdt.put('x', 1);
      await crdt.merge({'x': Record(Hlc(now + 1000000, 0, 'xyz'), null)});
      expect(crdt.isDeleted('x'), isTrue);
    });
  });

  group('Serialization', () {
    Crdt<String, int> crdt;

    setUp(() {
      crdt = Crdt(
          'abc', MapStore({'x': Record<int>(Hlc(1579633503110, 0, 'abc'), 1)}));
    });

    test('To map', () {
      expect(
          crdt.getMap(), {'x': Record<int>(Hlc(1579633503110, 0, 'abc'), 1)});
    });

    test('jsonEncodeStringKey', () {
      expect(jsonEncode(crdt.getMap()),
          '{"x":{"hlc":"1970-01-19T06:47:13.476Z-0000-abc","value":1}}');
    });

    test('jsonEncodeIntKey', () {
      expect(
          crdtMap2Json(
              {1: Record(Hlc.fromLogicalTime(1579633475584, 'abc'), 1)}),
          '{"1":{"hlc":"1970-01-19T06:47:13.476Z-0000-abc","value":1}}');
    });

    test('jsonDecodeStringKey', () {
      var map = json2CrdtMap<String, int>(
          '{"x":{"hlc":"1970-01-19T06:47:13.476Z-0000-abc","value":1}}');
      expect(map, crdt.getMap());
    });

    test('jsonDecodeIntKey', () {
      var map = json2CrdtMap<int, int>(
          '{"1":{"hlc":"1970-01-19T06:47:13.476Z-0000-abc","value":1}}',
          keyDecoder: (key) => int.parse(key));
      expect(map, {1: Record(Hlc.fromLogicalTime(1579633475584, 'abc'), 1)});
    });
  });

  group('Custom class serialization', () {
    Crdt<String, TestClass> crdt;

    setUp(() {
      crdt = Crdt(
          'abc',
          MapStore({
            'x': Record<TestClass>(
                Hlc(1579633503110, 0, 'abc'), TestClass('test'))
          }));
    });

    test('To map', () {
      expect(crdt.getMap(), {
        'x': Record<TestClass>(Hlc(1579633503110, 0, 'abc'), TestClass('test'))
      });
    });

    test('jsonEncode', () {
      expect(jsonEncode(crdt.getMap()),
          '{"x":{"hlc":"1970-01-19T06:47:13.476Z-0000-abc","value":{"test":"test"}}}');
    });

    test('jsonDecode', () {
      var decoded = json2CrdtMap<String, TestClass>(
          '{"x":{"hlc":"1970-01-19T06:47:13.476Z-0000-abc","value":{"test":"test"}}}',
          valueDecoder: TestClass.fromJson);
      expect(decoded, crdt.getMap());
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
