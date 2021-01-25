import 'package:crdt/crdt.dart';
import 'package:test/test.dart';

void main() {
  crdtTests('abc', syncSetup: () => CrdtMap<String, int>('abc'));
}

void crdtTests<T extends Crdt<String, int>>(String nodeId,
    {T Function() syncSetup,
    Future<T> Function() asyncSetup,
    void Function(T crdt) syncTearDown,
    Future<void> Function(T crdt) asyncTearDown}) {
  group('Basic', () {
    Crdt<String, int> crdt;

    setUp(() async {
      crdt = syncSetup != null ? syncSetup() : await asyncSetup();
    });

    test('Node ID', () {
      expect(crdt.nodeId, nodeId);
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

    tearDown(() async {
      if (syncTearDown != null) syncTearDown(crdt);
      if (asyncTearDown != null) await asyncTearDown(crdt);
    });
  });

  group('Watch', () {
    Crdt crdt;

    setUp(() async {
      crdt = syncSetup != null ? syncSetup() : await asyncSetup();
    });

    test('All changes', () async {
      final streamTest = expectLater(
          crdt.watch(),
          emitsInAnyOrder([
            (MapEntry<String, int> event) =>
                event.key == 'x' && event.value == 1,
            (MapEntry<String, int> event) =>
                event.key == 'y' && event.value == 2,
          ]));
      crdt.put('x', 1);
      crdt.put('y', 2);
      await streamTest;
    });

    test('Key', () async {
      final streamTest = expectLater(
          crdt.watch(key: 'y'),
          emits(
            (event) => event.key == 'y' && event.value == 2,
          ));
      crdt.put('x', 1);
      crdt.put('y', 2);
      await streamTest;
    });

    tearDown(() async {
      if (syncTearDown != null) syncTearDown(crdt);
      if (asyncTearDown != null) await asyncTearDown(crdt);
    });
  });
}
