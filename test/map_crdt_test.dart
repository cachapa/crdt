import 'dart:async';

import 'package:crdt/crdt.dart';
import 'package:crdt/map_crdt.dart';
import 'package:test/test.dart';

Future<void> get _delay => Future.delayed(Duration(milliseconds: 1));

typedef TestCrdt = MapCrdt;

Future<TestCrdt> createCrdt(String collection, String table1,
        [String? table2]) async =>
    MapCrdt([table1, table2].nonNulls);

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
      // expect(Uuid.isValidUUID(fromString: crdt.nodeId), true);
    });

    test('Empty', () {
      expect(crdt.canonicalTime, Hlc.zero(crdt.nodeId));
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
      await crdt.put('table', 'x', 1);
      expect(crdt.isEmpty, false);
      expect(crdt.getChangeset().recordCount, 1);
      expect(crdt.get('table', 'x'), 1);
    });

    test('Null', () async {
      await crdt.put('table', 'x', null);
      expect(crdt.getChangeset().recordCount, 1);
      expect(crdt.get('table', 'x'), null);
    });

    test('Update', () async {
      await crdt.put('table', 'x', 1);
      await crdt.put('table', 'x', 2);
      expect(crdt.getChangeset().recordCount, 1);
      expect(crdt.get('table', 'x'), 2);
    });

    test('Multiple', () async {
      await crdt.putAll({
        'table': {'x': 1, 'y': 2}
      });
      expect(crdt.getChangeset().recordCount, 2);
      expect(crdt.getMap('table'), {'x': 1, 'y': 2});
    });

    test('Enforce table existence', () {
      expect(() async => await crdt.put('not_test', 'x', 1),
          throwsA('Unknown table(s): not_test'));
    });
  });

  group('Delete', () {
    setUp(() async {
      crdt = await createCrdt('crdt', 'table');
      await crdt.put('table', 'x', 1);
    });

    tearDown(() async {
      await deleteCrdt(crdt);
    });

    test('Set deleted', () async {
      await crdt.put('table', 'x', 1, true);
      expect(crdt.isEmpty, false);
      expect(crdt.getChangeset().recordCount, 1);
      expect(crdt.getMap('table').length, 0);
      expect(crdt.get('table', 'x'), null);
    });

    test('Undelete', () async {
      await crdt.put('table', 'x', 1, true);
      await crdt.put('table', 'x', 1, false);
      expect(crdt.isEmpty, false);
      expect(crdt.getChangeset().recordCount, 1);
      expect(crdt.getMap('table').length, 1);
      expect(crdt.get('table', 'x'), 1);
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
      await crdt1.put('table', 'x', 2);
      await crdt.merge(crdt1.getChangeset());
      expect(crdt.get('table', 'x'), 2);
    });

    test('Empty changeset', () async {
      await crdt1.put('table', 'x', 2);
      await crdt.merge(crdt1.getChangeset());
      expect(crdt.get('table', 'x'), 2);
    });

    test('Older', () async {
      await crdt1.put('table', 'x', 2);
      await _delay;
      await crdt.put('table', 'x', 1);
      await crdt.merge(crdt1.getChangeset());
      expect(crdt.get('table', 'x'), 1);
    });

    test('Newer', () async {
      await crdt.put('table', 'x', 1);
      await _delay;
      await crdt1.put('table', 'x', 2);
      await crdt.merge(crdt1.getChangeset());
      expect(crdt.get('table', 'x'), 2);
    });

    test('Lower node id', () async {
      await crdt.put('table', 'x', 1);
      final changeset = crdt.getChangeset();
      changeset['table']!.first.addAll({
        'hlc': (changeset['table']!.first['hlc'] as Hlc)
            .apply(nodeId: '00000000-0000-0000-0000-000000000000'),
        'value': 2,
      });
      await crdt.merge(changeset);
      expect(crdt.get('table', 'x'), 1);
    });

    test('Higher node id', () async {
      await crdt.put('table', 'x', 1);
      final changeset = crdt.getChangeset();
      changeset['table']!.first.addAll({
        'hlc': (changeset['table']!.first['hlc'] as Hlc)
            .apply(nodeId: 'ffffffff-ffff-ffff-ffff-ffffffffffff'),
        'value': 2,
      });
      await crdt.merge(changeset);
      expect(crdt.get('table', 'x'), 2);
    });

    test('Enforce table existence', () async {
      final other = await createCrdt('other', 'not_table');
      await other.put('not_table', 'x', 1);
      expect(() => crdt.merge(other.getChangeset()),
          throwsA('Unknown table(s): not_table'));
      await deleteCrdt(other);
    });

    test('Update canonical time after merge', () async {
      await crdt1.put('table', 'x', 2);
      await crdt.merge(crdt1.getChangeset());
      expect(
          crdt.canonicalTime, crdt1.canonicalTime.apply(nodeId: crdt.nodeId));
    });
  });

  group('Changesets', () {
    late TestCrdt crdt1;
    late TestCrdt crdt2;

    setUp(() async {
      crdt = await createCrdt('crdt', 'table');
      crdt1 = await createCrdt('crdt1', 'table');
      crdt2 = await createCrdt('crdt2', 'table');

      await crdt.put('table', 'x', 1);
      await _delay;
      await crdt1.put('table', 'y', 1);
      await _delay;
      await crdt2.put('table', 'z', 1);

      await crdt.merge(crdt1.getChangeset());
      await crdt.merge(crdt2.getChangeset());
    });

    tearDown(() async {
      await deleteCrdt(crdt);
      await deleteCrdt(crdt1);
      await deleteCrdt(crdt2);
    });

    test('Tables', () async {
      final crdt3 = await createCrdt('table', 'another_table');
      await crdt3.put('another_table', 'a', 1);
      final changeset = crdt3.getChangeset(onlyTables: ['another_table']);
      expect(changeset.keys, ['another_table']);
      await deleteCrdt(crdt3);
    });

    test('After HLC', () {
      print(crdt1.canonicalTime);
      expect(crdt.getChangeset(modifiedAfter: crdt1.canonicalTime),
          crdt2.getChangeset());
    });

    test('Empty changeset', () {
      print(crdt2.canonicalTime);
      expect(crdt.getChangeset(modifiedAfter: crdt2.canonicalTime), {});
    });

    test('At HLC', () {
      final changeset = crdt.getChangeset(modifiedOn: crdt1.canonicalTime);
      expect(changeset, crdt1.getChangeset());
    });

    test('Only node id', () {
      final changeset = crdt.getChangeset(onlyNodeId: crdt1.nodeId);
      expect(changeset, crdt1.getChangeset());
    });

    test('Except node id', () {
      final originalChangeset = crdt1.getChangeset();
      crdt1.merge(crdt2.getChangeset());
      final changeset = crdt1.getChangeset(exceptNodeId: crdt2.nodeId);
      expect(changeset, originalChangeset);
    });
  });

  group('Last modified', () {
    late TestCrdt crdt1;
    late TestCrdt crdt2;

    setUp(() async {
      crdt = await createCrdt('crdt', 'table');
      crdt1 = await createCrdt('crdt1', 'table');
      crdt2 = await createCrdt('crdt2', 'table');

      await crdt.put('table', 'x', 1);
      await _delay;
      await crdt1.put('table', 'y', 1);
      await _delay;
      await crdt2.put('table', 'z', 1);

      await crdt.merge(crdt1.getChangeset());
      await crdt.merge(crdt2.getChangeset());
    });

    tearDown(() async {
      await deleteCrdt(crdt);
      await deleteCrdt(crdt1);
      await deleteCrdt(crdt2);
    });

    test('Everything', () {
      expect(crdt.getLastModified(),
          crdt2.canonicalTime.apply(nodeId: crdt.nodeId));
    });

    test('Only node id', () {
      expect(crdt.getLastModified(onlyNodeId: crdt1.nodeId),
          crdt1.canonicalTime.apply(nodeId: crdt.nodeId));
    });

    test('Except node id', () async {
      // Move canonical time forward in crdt
      await _delay;
      await crdt.put('table', 'a', 1);
      expect(crdt.getLastModified(exceptNodeId: crdt.nodeId),
          crdt2.canonicalTime.apply(nodeId: crdt.nodeId));
    });

    test('Assert exclusive parameters', () {
      expect(
          () => crdt.getLastModified(
              onlyNodeId: crdt.nodeId, exceptNodeId: crdt.nodeId),
          throwsA(isA<AssertionError>()));
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
          crdt.onTablesChanged.map((e) => e.tables), emits(['table_1']));
      crdt.put('table_1', 'x', 1);
    });

    test('Multiple changes to same table', () {
      expectLater(
          crdt.onTablesChanged.map((e) => e.tables), emits(['table_1']));
      crdt.putAll({
        'table_1': {
          'x': 1,
          'y': 2,
        }
      });
    });

    test('Multiple tables', () {
      expectLater(crdt.onTablesChanged.map((e) => e.tables),
          emits(['table_1', 'table_2']));
      crdt.putAll({
        'table_1': {'x': 1},
        'table_2': {'y': 2},
      });
    });

    test('Do not notify empty changes', () {
      expectLater(
          crdt.onTablesChanged.map((e) => e.tables), emits(['table_1']));
      crdt.putAll({
        'table_1': {'x': 1},
        'table_2': {},
      });
    });

    test('Merge', () async {
      final crdt1 = await createCrdt('crdt1', 'table_1', 'table_2');
      await crdt1.put('table_1', 'x', 1);
      // ignore: unawaited_futures
      expectLater(
          crdt.onTablesChanged.map((e) => e.tables), emits(['table_1']));
      await crdt.merge(crdt1.getChangeset());
      await deleteCrdt(crdt1);
    });
  });

  group('Watch', () {
    setUp(() async => crdt = await createCrdt('crdt', 'table'));

    tearDown(() => deleteCrdt(crdt));

    test('Single change', () async {
      // ignore: unawaited_futures
      expectLater(
          crdt.watch('table'), emits((key: 'x', value: 1, isDeleted: false)));
      await crdt.put('table', 'x', 1);
    });

    test('Deleted', () async {
      // ignore: unawaited_futures
      expectLater(
          crdt.watch('table'), emits((key: 'x', value: 1, isDeleted: true)));
      await crdt.put('table', 'x', 1, true);
    });

    test('Enforce table existence', () {
      expect(
        () => crdt.watch('not_table'),
        throwsA('Unknown table: not_table'),
      );
    });
  });
}
