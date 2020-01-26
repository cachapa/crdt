import '../crdt.dart';
import 'store.dart';

class Crdt {
  final Store _store;

  Timestamp _canonicalTime;

  Map<String, Record> get map => _store.map;

  Crdt(this._store) {
    _canonicalTime = Timestamp(0);

    // Seed max canonical time
    for (var item in _store.values) {
      if (_canonicalTime < item.timestamp) {
        _canonicalTime = item.timestamp;
      }
    }
  }

  Crdt.fromMap(Map<String, Record> map) : this(MapStore(map));

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

class Record {
  final Timestamp timestamp;
  final dynamic value;

  Record(this.timestamp, this.value);

  factory Record.fromMap(Map<String, dynamic> map) =>
      Record(Timestamp.parse(map['timestamp']), map['value']);

  Map<String, dynamic> toMap() =>
      {'timestamp': timestamp.toString(), 'value': value};

  dynamic toJson() => toMap();

  @override
  bool operator ==(other) =>
      other is Record && timestamp == other.timestamp && value == other.value;

  @override
  String toString() => toMap().toString();
}
