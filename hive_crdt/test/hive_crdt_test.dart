import 'package:hive/hive.dart';
import 'package:hive_crdt/hive_adapters.dart';
import 'package:hive_crdt/hive_crdt.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

final nodeId = Uuid().v4();

void main() {
  Hive.init('.');
  Hive.registerAdapter(HlcAdapter(42, nodeId));
  Hive.registerAdapter(RecordAdapter(43));

  group('Basic tests', () {
    HiveCrdt<String, int> crdt;

    setUp(() async {
      crdt = await HiveCrdt.open('test', nodeId, path: 'test_store');
    });

    test('Write value', () {
      crdt.put('x', 1);
      expect(crdt.get('x'), 1);
    });

    test('Update value', () {
      crdt.put('x', 1);
      crdt.put('x', 2);
      expect(crdt.get('x'), 2);
    });

    test('Delete value', () {
      crdt.put('x', 1);
      crdt.delete('x');
      expect(crdt.isDeleted('x'), isTrue);
    });

    tearDown(() async {
      await crdt.deleteStore();
    });
  });

  group('Serialization', () {
    test('Reload box', () async {
      var crdt = await HiveCrdt.open('test', nodeId, path: 'test_store');
      crdt.put('x', 1);
      await crdt.close();

      crdt = await HiveCrdt.open('test', nodeId, path: 'test_store');
      expect(crdt.get('x'), 1);
      await crdt.deleteStore();
    });
  });

  group('Queries', () {
    HiveCrdt<int, int> crdt;

    setUp(() async {
      crdt = await HiveCrdt.open('test', nodeId, path: 'test_store');
      crdt.putAll(Map.fromIterable(List.generate(20, (index) => index)));
    });

    test('From key', () {
      final values = crdt.between(start: 15);
      expect(values, [15, 16, 17, 18, 19]);
    });

    test('Between keys', () {
      final values = crdt.between(start: 5, end: 10);
      expect(values, [5, 6, 7, 8, 9, 10]);
    });

    test('Up to key', () {
      final values = crdt.between(end: 5);
      expect(values, [0, 1, 2, 3, 4, 5]);
    });

    tearDown(() async {
      await crdt.deleteStore();
    });
  });

  group('DateTime key', () {
    HiveCrdt<DateTime, int> crdt;

    setUp(() async {
      crdt = await HiveCrdt.open('test', nodeId, path: 'test_store');
    });

    test('Datetime key', () {
      crdt.put(DateTime(1974, 04, 25, 00, 20), 42);
      expect(crdt.get(DateTime(1974, 04, 25, 00, 20)), 42);
    });

    test('Read datetime from store', () async {
      crdt.put(DateTime(1974, 04, 25, 00, 20), 42);

      crdt = await HiveCrdt.open('test', nodeId, path: 'test_store');
      expect(crdt.get(DateTime(1974, 04, 25, 00, 20)), 42);
    });

    tearDown(() async {
      await crdt.deleteStore();
    });
  });

  group('Watches', () {
    HiveCrdt<String, int> crdt;

    setUp(() async {
      crdt = await HiveCrdt.open('test', nodeId, path: 'test_store');
    });

    test('Watch all changes', () async {
      final streamTest = expectLater(
          crdt.watch(),
          emitsInAnyOrder([
            (BoxEvent event) => event.key == 'x' && event.value.value == 1,
            (BoxEvent event) => event.key == 'y' && event.value.value == 2,
          ]));
      crdt.put('x', 1);
      crdt.put('y', 2);
      await streamTest;
    });

    test('Watch key', () async {
      final streamTest = expectLater(
          crdt.watch(key: 'y'),
          emits(
            (BoxEvent event) => event.key == 'y' && event.value.value == 2,
          ));
      crdt.put('x', 1);
      crdt.put('y', 2);
      await streamTest;
    });

    tearDown(() async {
      await crdt.deleteStore();
    });
  });
}
