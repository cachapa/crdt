import 'package:crdt/crdt.dart';
import 'package:crdt/src/hive_store.dart';
import 'package:test/test.dart';

Future<void> main() async {
  var store = await HiveStore.create('.', 'test_store.hive');

  setUp(() async {
     await store.clear();
  });

  test('Put', () {
    var now = DateTime.now().millisecondsSinceEpoch;
    store['x'] = Record(Timestamp('a', now), 1);
    expect(store['x'], Record(Timestamp('a', now), 1));
  });
}
