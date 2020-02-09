import 'dart:convert';

import 'package:crdt/crdt.dart';
import 'package:test/test.dart';

void main() {
  group('Basic', () {
    Crdt<String, int> crdt;

    setUp(() {
      crdt = Crdt();
    });

    test('Put', () async {
      await crdt.put('x', 1);
      var record = await crdt.get('x');
      expect(record.value, 1);
    });

    test('Put sequential', () async {
      await crdt.put('x', 1);
      await crdt.put('x', 2);
      var record = await crdt.get('x');
      expect(record.value, 2);
    });

    test('Put many', () async {
      await crdt.putAll({'x': 2, 'y': 3});
      expect((await crdt.get('x')).value, 2);
      expect((await crdt.get('y')).value, 3);
    });

    test('Delete value', () async {
      await crdt.put('x', 1);
      await crdt.delete('x');
      var record = await crdt.get('x');
      expect(record.isDeleted, isTrue);
    });
  });

  group('Seed', () {
    Crdt crdt;

    setUp(() {
      crdt = Crdt(MapStore({'x': Record(Hlc(), 1)}));
    });

    test('Seed item', () async {
      var record = await crdt.get('x');
      expect(record.value, 1);
    });

    test('Seed and put', () async {
      await crdt.put('x', 2);
      var record = await crdt.get('x');
      expect(record.value, 2);
    });
  });

  group('Merge', () {
    Crdt<String, int> crdt;
    var now = DateTime.now().microsecondsSinceEpoch;

    setUp(() {
      crdt = Crdt();
    });

    test('Merge older', () async {
      await crdt.put('x', 2);
      await crdt.merge({'x': Record(Hlc(now - 10000), 1)});
      var record = await crdt.get('x');
      expect(record.value, 2);
    });

    test('Merge very old', () async {
      await crdt.put('x', 2);
      await crdt.merge({'x': Record(Hlc(now - 1000000), 1)});
      var record = await crdt.get('x');
      expect(record.value, 2);
    });

    test('Merge newer', () async {
      await crdt.put('x', 1);
      await crdt.merge({'x': Record(Hlc(now + 1000000), 2)});
      var record = await crdt.get('x');
      expect(record.value, 2);
    });

    test('Merge same', () async {
      await crdt.put('x', 2);
      var remoteTs = (await crdt.get('x')).hlc;
      await crdt.merge({'x': Record(remoteTs, 1)});
      var record = await crdt.get('x');
      expect(record.value, 2);
    });

    test('Merge older, newer counter', () async {
      await crdt.put('x', 2);
      await crdt.merge({'x': Record(Hlc(now - 1000000, 2), 1)});
      var record = await crdt.get('x');
      expect(record.value, 2);
    });

    test('Merge same, newer counter', () async {
      await crdt.put('x', 1);
      var remoteTs = Hlc((await crdt.get('x')).hlc.micros, 2);
      await crdt.merge({'x': Record(remoteTs, 2)});
      var record = await crdt.get('x');
      expect(record.value, 2);
    });

    test('Merge new item', () async {
      var map = {'x': Record<int>(Hlc(), 2)};
      await crdt.merge(map);
      expect(await crdt.getMap(), map);
    });

    test('Merge deleted item', () async {
      await crdt.put('x', 1);
      await crdt.merge({'x': Record(Hlc(now + 1000000), null)});
      var record = await crdt.get('x');
      expect(record.isDeleted, isTrue);
    });
  });

  group('Serialization', () {
    Crdt<String, int> crdt;

    setUp(() {
      crdt = Crdt(MapStore({'x': Record<int>(Hlc(1579633503110), 1)}));
    });

    test('To map', () async {
      expect(await crdt.getMap(), {'x': Record<int>(Hlc(1579633503110), 1)});
    });

    test('jsonEncodeStringKey', () async {
      expect(jsonEncode(await crdt.getMap()),
          '{"x":{"hlc":1579633475584,"value":1}}');
    });

    test('jsonEncodeIntKey', () async {
      expect(crdtMap2Json({1: Record(Hlc.fromLogicalTime(1579633475584), 1)}),
          '{"1":{"hlc":1579633475584,"value":1}}');
    });

    test('jsonDecodeStringKey', () async {
      var map =
          json2CrdtMap<String, int>('{"x":{"hlc":1579633475584,"value":1}}');
      expect(map, await crdt.getMap());
    });

    test('jsonDecodeIntKey', () async {
      var map = json2CrdtMap<int, int>('{"1":{"hlc":1579633475584,"value":1}}',
          keyDecoder: (key) => int.parse(key));
      expect(map, {1: Record(Hlc.fromLogicalTime(1579633475584), 1)});
    });
  });

  group('Custom class serialization', () {
    Crdt<String, TestClass> crdt;

    setUp(() {
      crdt = Crdt(MapStore(
          {'x': Record<TestClass>(Hlc(1579633503110), TestClass('test'))}));
    });

    test('To map', () async {
      expect(await crdt.getMap(),
          {'x': Record<TestClass>(Hlc(1579633503110), TestClass('test'))});
    });

    test('jsonEncode', () async {
      expect(jsonEncode(await crdt.getMap()),
          '{"x":{"hlc":1579633475584,"value":{"test":"test"}}}');
    });

    test('jsonDecode', () async {
      var decoded = json2CrdtMap<String, TestClass>(
          '{"x":{"hlc":1579633475584,"value":{"test":"test"}}}',
          valueDecoder: TestClass.fromJson);
      expect(await decoded, await crdt.getMap());
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
