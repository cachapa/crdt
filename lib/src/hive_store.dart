import 'package:crdt/crdt.dart';
import 'package:hive/hive.dart';

class HiveStore extends Store {
  final Box _box;

  HiveStore._(this._box);

  static Future<HiveStore> create(String path, name) async {
    Hive
      ..init(path)
      ..registerAdapter(ItemAdapter())
      ..registerAdapter(TimestampAdapter());
    var box = await Hive.openBox(name);
    return HiveStore._(box);
  }

  @override
  Record operator [](String key) => _box.get(key);

  @override
  void operator []=(String key, Record value) => _box.put(key, value);

  @override
  Map<String, Record> get map => _box.toMap().cast<String, Record>();

  @override
  Iterable<Record> get values => _box.values.cast<Record>();

  Future<void> clear() async => _box.clear();
}

class ItemAdapter extends TypeAdapter<Record> {
  @override
  Record read(BinaryReader reader) => Record(reader.read(), reader.read());

  @override
  void write(BinaryWriter writer, Record item) {
    writer.write(item.timestamp);
    writer.write(item.data);
  }

  @override
  int get typeId => 0;
}

class TimestampAdapter extends TypeAdapter<Timestamp> {
  @override
  Timestamp read(BinaryReader reader) =>
      Timestamp(reader.readString(), reader.readInt(), reader.readInt());

  @override
  void write(BinaryWriter writer, Timestamp timestamp) {
    writer.writeString(timestamp.nodeId);
    writer.writeInt(timestamp.millis);
    writer.writeInt(timestamp.counter);
  }

  @override
  int get typeId => 1;
}
