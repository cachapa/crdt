import '../crdt.dart';
import 'store.dart';

typedef Decoder<T> = T Function(Map<String, dynamic> map);

class Crdt<T> {
  final Store _store;

  Timestamp _canonicalTime;

  Map<String, Record<T>> get map => _store.map;

  Crdt(this._store) {
    _canonicalTime = Timestamp(0);

    // Seed max canonical time
    for (var item in _store.values) {
      if (_canonicalTime < item.timestamp) {
        _canonicalTime = item.timestamp;
      }
    }
  }

  Crdt.fromMap(Map<String, Record<T>> map) : this(MapStore(map));

  Crdt.fromJson(Map<String, dynamic> map, [Decoder<T> decoder])
      : this.fromMap(map.map(
            (key, value) => MapEntry(key, Record<T>.fromJson(value, decoder))));

  Record operator [](String key) => _store[key];

  void operator []=(String key, dynamic value) {
    _canonicalTime = Timestamp.send(_canonicalTime);
    _store[key] = Record(_canonicalTime, value);
  }

  dynamic delete(String key) => this[key] = null;

  void merge(Map<String, Record> remoteRecords) {
    remoteRecords.forEach((key, remoteRecord) {
      var localRecord = _store[key];

      if (localRecord == null) {
        // Insert if there's no local copy
        _store[key] = Record(remoteRecord.timestamp, remoteRecord.value);
      } else if (localRecord.timestamp < remoteRecord.timestamp) {
        // Update if local copy is older
        _canonicalTime = Timestamp.recv(_canonicalTime, remoteRecord.timestamp);
        _store[key] = Record(_canonicalTime, remoteRecord.value);
      }
    });
  }

  @override
  String toString() => _store.toString();
}

class Record<T> {
  final Timestamp timestamp;
  final T value;

  bool get isDeleted => value == null;

  Record(this.timestamp, this.value);

  Record.fromJson(Map<String, dynamic> map, Decoder<T> decoder)
      : timestamp = Timestamp.parse(map['timestamp']),
        value = decoder == null ? map['value'] : decoder(map['value']);

  Map<String, dynamic> toJson() =>
      {'timestamp': timestamp.toString(), 'value': value};

  @override
  bool operator ==(other) =>
      other is Record && timestamp == other.timestamp && value == other.value;

  @override
  String toString() => toJson().toString();
}
