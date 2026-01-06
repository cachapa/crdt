import 'dart:async';
import 'dart:math';

import 'package:crdt/crdt.dart';
import 'package:crdt/map_crdt.dart';
import 'package:test/test.dart';

/// Weak node id generator. Use a UUID generator for production instead.
String randomId() => Random().nextInt(2 ^ 32).toString();

Future<void> get _delay => Future.delayed(Duration(milliseconds: 1));

typedef TestCrdt = MapCrdt;

FutureOr<TestCrdt> createCrdt(
  String collection,
  String table1, [
  String? table2,
]) => MapCrdt(randomId(), [table1, table2].nonNulls);

Future<void> deleteCrdt(TestCrdt crdt) async {}

void main() {
  late TestCrdt crdt;

  group('Empty', () {
    setUp(() async {
      crdt = await createCrdt('crdt', 'table');
    });

    tearDown(() async {
      await deleteCrdt(crdt);
    });

    test('Node ID', () {
      print(crdt.isEmpty);
      expect(crdt.nodeId, isNotEmpty);
    });

    test('Empty', () {
      expect(crdt.canonicalTime, 0);
      expect(crdt.isEmpty, true);
    });
  });

  group('Insert', () {
    setUp(() async {
      crdt = await createCrdt('crdt', 'table');
    });

    tearDown(() async {
      await deleteCrdt(crdt);
    });

    test('Single', () async {
      await crdt.put('table', 'x', {'v': 1});
      expect(crdt.isEmpty, false);
      expect(crdt.getChangeset().recordCount, 1);
      expect(crdt.get('table', 'x'), {'v': 1});
    });

    test('Null', () async {
      await crdt.put('table', 'x', null);
      expect(crdt.getChangeset().recordCount, 1);
      expect(crdt.get('table', 'x'), null);
    });

    test('Update', () async {
      await crdt.put('table', 'x', {'v': 1});
      await crdt.put('table', 'x', {'v': 2});
      expect(crdt.getChangeset().recordCount, 1);
      expect(crdt.get('table', 'x'), {'v': 2});
    });

    test('Multiple', () async {
      await crdt.putAll({
        'table': {
          'x': {'v': 1},
          'y': {'v': 2},
        },
      });
      expect(crdt.getChangeset().recordCount, 2);
      expect(crdt.getMap('table'), {
        'x': {'v': 1},
        'y': {'v': 2},
      });
    });

    test('Enforce table existence', () {
      expect(
        () async => await crdt.put('not_test', 'x', {'v': 1}),
        throwsA('Unknown table(s): not_test'),
      );
    });
  });

  group('Delete', () {
    setUp(() async {
      crdt = await createCrdt('crdt', 'table');
      await crdt.put('table', 'x', {'v': 1});
    });

    tearDown(() async {
      await deleteCrdt(crdt);
    });

    test('Set deleted', () async {
      await crdt.put('table', 'x', {'v': 1});
      expect(crdt.isEmpty, false);
      expect(crdt.getChangeset().recordCount, 1);
      await crdt.delete('table', 'x');
      expect(crdt.getMap('table').length, 0);
      expect(crdt.get('table', 'x'), null);
    });
  });

  group('Merge', () {
    late TestCrdt crdt1;

    setUp(() async {
      crdt = await createCrdt('crdt', 'table');
      crdt1 = await createCrdt('crdt', 'table');
    });

    tearDown(() async {
      await deleteCrdt(crdt);
      await deleteCrdt(crdt1);
    });

    test('Into empty', () async {
      await crdt1.put('table', 'x', {'v': 2});
      await crdt.merge(crdt1.getChangeset());
      expect(crdt.get('table', 'x'), {'v': 2});
    });

    test('Empty changeset', () async {
      await crdt1.put('table', 'x', {'v': 2});
      await crdt.merge(crdt1.getChangeset());
      expect(crdt.get('table', 'x'), {'v': 2});
    });

    test('Older', () async {
      await crdt1.put('table', 'x', {'v': 2});
      await _delay;
      await crdt.put('table', 'x', {'v': 1});
      await crdt.merge(crdt1.getChangeset());
      expect(crdt.get('table', 'x'), {'v': 1});
    });

    test('Newer', () async {
      await crdt.put('table', 'x', {'v': 1});
      await _delay;
      await crdt1.put('table', 'x', {'v': 2});
      await crdt.merge(crdt1.getChangeset());
      expect(crdt.get('table', 'x'), {'v': 2});
    });

    test('Lower node id', () async {
      await crdt.put('table', 'x', {'v': 1});
      await crdt.merge(
        CrdtChangeset.parse({
          'table': [
            {
              'id': 'x',
              'hlc': crdt.canonicalHlc.apply(nodeId: '0000000'),
              'data': {'v': 2},
            },
          ],
        }),
      );
      expect(crdt.get('table', 'x'), {'v': 1});
    });

    test('Higher node id', () async {
      await crdt.put('table', 'x', {'v': 1});
      await crdt.merge(
        CrdtChangeset.parse({
          'table': [
            {
              'id': 'x',
              'hlc': crdt.canonicalHlc.apply(nodeId: 'FFFFFFFF'),
              'data': {'v': 2},
            },
          ],
        }),
      );
      expect(crdt.get('table', 'x'), {'v': 2});
    });

    test('Enforce table existence', () async {
      final other = await createCrdt('other', 'not_table');
      await other.put('not_table', 'x', {'v': 2});
      expect(
        () => crdt.merge(other.getChangeset()),
        throwsA('Unknown table(s): not_table'),
      );
      await deleteCrdt(other);
    });

    test('Update canonical time after merge', () async {
      await crdt1.put('table', 'x', {'v': 2});
      await crdt.merge(crdt1.getChangeset());
      expect(crdt.canonicalTime, crdt1.canonicalTime);
    });
  });

  group('Changesets', () {
    late Hlc crdtInitialHlc;
    late TestCrdt crdt1;
    late TestCrdt crdt2;

    setUp(() async {
      crdt = await createCrdt('crdt', 'table');
      crdt1 = await createCrdt('crdt1', 'table');
      crdt2 = await createCrdt('crdt2', 'table');

      await crdt.put('table', 'x', {'v': 1});
      await _delay;
      await crdt1.put('table', 'y', {'v': 2});
      await _delay;
      await crdt2.put('table', 'z', {'v': 3});

      crdtInitialHlc = crdt.canonicalHlc;
      await crdt.merge(crdt1.getChangeset());
      await crdt.merge(crdt2.getChangeset());
    });

    tearDown(() async {
      await deleteCrdt(crdt);
      await deleteCrdt(crdt1);
      await deleteCrdt(crdt2);
    });

    test('Records properly merged', () async {
      expect(
        crdt.getChangeset().toString(),
        {
          'table': (
            {
              'id': 'x',
              'hlc': crdtInitialHlc,
              'data': {'v': 1},
            },
            {
              'id': 'y',
              'hlc': crdt1.canonicalHlc,
              'data': {'v': 2},
            },
            {
              'id': 'z',
              'hlc': crdt2.canonicalHlc,
              'data': {'v': 3},
            },
          ),
        }.toString(),
      );
    });

    test('Filter entire collections', () async {
      final crdt3 = await createCrdt('table', 'another_table');
      await crdt3.put('another_table', 'a', {'v': 1});
      final changeset = crdt3.getChangeset(
        collectionFilter: {'another_table': null},
      );
      expect(changeset.collections, ['another_table']);
      await deleteCrdt(crdt3);
    });

    test('After HLC', () {
      expect(
        crdt.getChangeset(modifiedAfter: crdt1.canonicalTime).toString(),
        crdt2.getChangeset().toString(),
      );
    });

    test('Empty changeset', () {
      expect(
        crdt.getChangeset(modifiedAfter: crdt2.canonicalTime).recordCount,
        isZero,
      );
    });

    test('At HLC', () {
      final changeset = crdt.getChangeset(modifiedOn: crdt1.canonicalTime);
      expect(changeset.toString(), crdt1.getChangeset().toString());
    });

    test('Only node id', () {
      final changeset = crdt.getChangeset(onlyNodeId: crdt1.nodeId);
      expect(changeset.toString(), crdt1.getChangeset().toString());
    });

    test('Except node id', () {
      final originalChangeset = crdt1.getChangeset();
      crdt1.merge(crdt2.getChangeset());
      final changeset = crdt1.getChangeset(exceptNodeId: crdt2.nodeId);
      expect(changeset.toString(), originalChangeset.toString());
    });
  });

  group('Last modified', () {
    late TestCrdt crdt1;
    late TestCrdt crdt2;

    setUp(() async {
      crdt = await createCrdt('crdt', 'table');
      crdt1 = await createCrdt('crdt1', 'table');
      crdt2 = await createCrdt('crdt2', 'table');

      await crdt.put('table', 'x', {'v': 1});
      await _delay;
      await crdt1.put('table', 'y', {'v': 1});
      await _delay;
      await crdt2.put('table', 'z', {'v': 1});

      await crdt.merge(crdt1.getChangeset());
      await crdt.merge(crdt2.getChangeset());
    });

    tearDown(() async {
      await deleteCrdt(crdt);
      await deleteCrdt(crdt1);
      await deleteCrdt(crdt2);
    });

    test('Everything', () {
      expect(crdt.getLastModified(), crdt2.canonicalTime);
    });

    test('Only node id', () {
      expect(
        crdt.getLastModified(onlyNodeId: crdt1.nodeId),
        crdt1.canonicalTime,
      );
    });

    test('Except node id', () async {
      // Move canonical time forward in crdt
      await _delay;
      await crdt.put('table', 'a', {'v': 1});
      expect(
        crdt.getLastModified(exceptNodeId: crdt.nodeId),
        crdt2.canonicalTime,
      );
    });

    test('Assert exclusive parameters', () {
      expect(
        () => crdt.getLastModified(
          onlyNodeId: crdt.nodeId,
          exceptNodeId: crdt.nodeId,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Tables changed stream', () {
    setUp(() async {
      crdt = await createCrdt('crdt', 'table_1', 'table_2');
    });

    tearDown(() async {
      await deleteCrdt(crdt);
    });

    test('Single change', () {
      expectLater(
        crdt.onTablesChanged.map((e) => e.tables),
        emits(['table_1']),
      );
      crdt.put('table_1', 'x', {'v': 1});
    });

    test('Multiple changes to same table', () {
      expectLater(
        crdt.onTablesChanged.map((e) => e.tables),
        emits(['table_1']),
      );
      crdt.putAll({
        'table_1': {
          'x': {'v': 1},
          'y': {'v': 1},
        },
      });
    });

    test('Multiple tables', () {
      expectLater(
        crdt.onTablesChanged.map((e) => e.tables),
        emits(['table_1', 'table_2']),
      );
      crdt.putAll({
        'table_1': {
          'x': {'v': 1},
        },
        'table_2': {
          'y': {'v': 2},
        },
      });
    });

    test('Do not notify empty changes', () {
      expectLater(
        crdt.onTablesChanged.map((e) => e.tables),
        emits(['table_1']),
      );
      crdt.putAll({
        'table_1': {
          'x': {'v': 1},
        },
        'table_2': {},
      });
    });

    test('Merge', () async {
      final crdt1 = await createCrdt('crdt1', 'table_1', 'table_2');
      await crdt1.put('table_1', 'x', {'v': 1});
      // ignore: unawaited_futures
      expectLater(
        crdt.onTablesChanged.map((e) => e.tables),
        emits(['table_1']),
      );
      await crdt.merge(crdt1.getChangeset());
      await deleteCrdt(crdt1);
    });
  });

  group('Watch', () {
    setUp(() async => crdt = await createCrdt('crdt', 'table'));

    tearDown(() => deleteCrdt(crdt));

    test('Single change', () async {
      final expectation = expectLater(
        crdt.watch('table'),
        emits(
          isA<({String key, Map<String, Object?>? value})>()
              .having((e) => e.key, 'key', 'x')
              .having((e) => e.value, 'value', {'v': 1}),
        ),
      );
      await crdt.put('table', 'x', {'v': 1});
      await expectation;
    });

    test('Deleted', () async {
      unawaited(
        expectLater(crdt.watch('table'), emits((key: 'x', value: null))),
      );
      await crdt.delete('table', 'x');
    });

    test('Enforce table existence', () {
      expect(
        () => crdt.watch('not_table'),
        throwsA('Unknown collection: not_table'),
      );
    });
  });
}
