import 'package:uuid/uuid.dart';

import '../crdt.dart';
import 'store.dart';

class Crdt {
  final String nodeId;
  final Store _store;

  Timestamp _canonicalTime;

  Map<String, Record> get map => _store.map;

  Crdt(this.nodeId, this._store) {
    _canonicalTime = Timestamp(nodeId, 0);

    // Seed max canonical time
    for (var item in _store.values) {
      if (_canonicalTime < item.timestamp) {
        _canonicalTime = item.timestamp;
      }
    }
  }

  Crdt.fromMap(String nodeId, Map<String, Record> map)
      : this(nodeId, MapStore(map));

  void put(String name, dynamic data) {
    _canonicalTime = Timestamp.send(_canonicalTime);
    _store[name] = Record(_canonicalTime, data);
  }

  Record get(String name) => _store[name];

  dynamic delete(String name) => put(name, null);

  void merge(Map<String, Record> remoteItems) {
    remoteItems.forEach((name, remoteItem) {
      var localItem = _store[name];

      if (localItem == null) {
        // Insert if there's no local copy
        _store[name] =
            Record(remoteItem.timestamp.clone(nodeId), remoteItem.data);
      } else if (localItem.timestamp < remoteItem.timestamp) {
        // Update if local copy is older
        _canonicalTime = Timestamp.recv(_canonicalTime, remoteItem.timestamp);
        _store[name] = Record(_canonicalTime, remoteItem.data);
      }
    });
  }

  @override
  String toString() => _store.toString();

  static String generateNodeId() =>
      Uuid().v4().replaceAll('-', '').substring(16);
}

class Record {
  final Timestamp timestamp;
  final dynamic data;

  Record(this.timestamp, this.data);

  factory Record.fromMap(Map<String, dynamic> map) =>
      Record(Timestamp.parse(map['timestamp']), map['data']);

  Map<String, dynamic> toMap() =>
      {'timestamp': timestamp.toString(), 'data': data};

  dynamic toJson() => toMap();

  @override
  bool operator ==(other) =>
      other is Record && timestamp == other.timestamp && data == other.data;

  @override
  String toString() => toMap().toString();
}
