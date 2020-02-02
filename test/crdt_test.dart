import 'dart:convert';

import 'package:crdt/crdt.dart';
import 'package:test/test.dart';

void main() {
  group('Basic', () {
    Crdt crdt;

    setUp(() {
      crdt = Crdt.fromMap({});
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
      crdt = Crdt.fromMap({'x': Record(Hlc(), 1)});
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
    Crdt<int> crdt;
    var now = DateTime.now().microsecondsSinceEpoch;

    setUp(() {
      crdt = Crdt.fromMap({});
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
    Crdt<int> crdt;

    setUp(() {
      crdt = Crdt.fromMap({'x': Record<int>(Hlc(1579633503110), 1)});
    });

    test('To map', () async {
      expect(await crdt.getMap(), {'x': Record<int>(Hlc(1579633503110), 1)});
    });

    test('jsonEncode', () async {
      expect(jsonEncode(await crdt.getMap()),
          '{"x":{"hlc":1579633475584,"value":1}}');
    });

    test('jsonDecode', () async {
      var jsonMap = jsonDecode('{"x":{"hlc":1579633475584,"value":1}}');
      var decoded = Crdt<int>.fromJson(jsonMap);
      expect(await decoded.getMap(), await crdt.getMap());
    });
  });

  group('Custom class serialization', () {
    Crdt crdt;

    setUp(() {
      crdt = Crdt.fromMap(
          {'x': Record<TestClass>(Hlc(1579633503110), TestClass('test'))});
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
      var jsonMap =
          jsonDecode('{"x":{"hlc":1579633475584,"value":{"test":"test"}}}');
      var decoded = Crdt<TestClass>.fromJson(jsonMap, TestClass.fromJson);
      expect(await decoded.getMap(), await crdt.getMap());
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
