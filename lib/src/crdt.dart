import 'hlc.dart';
import 'store.dart';

typedef Decoder<T> = T Function(Map<String, dynamic> map);

class Crdt<T> {
  final Store<T> _store;

  /// Represents the latest logical time seen in the stored data
  Hlc _canonicalTime;

  Crdt(this._store) {
    // Seed canonical time
    _canonicalTime = _store.latestLogicalTime;
  }

  Crdt.fromMap(Map<String, Record<T>> map) : this(MapStore(map));

  Crdt.fromJson(Map<String, dynamic> map, [Decoder<T> decoder])
      : this.fromMap(map.map(
            (key, value) => MapEntry(key, Record<T>.fromJson(value, decoder))));

  Future<Map<String, Record<T>>> getMap([int logicalTime = 0]) =>
      _store.getMap(logicalTime);

  Future<Record<T>> get(String key) => _store.get(key);

  Future<void> put(String key, T value) async {
    _canonicalTime = Hlc.send(_canonicalTime);
    await _store.put(key, Record<T>(_canonicalTime, value));
  }

  Future<void> delete(String key) async => put(key, null);

  Future<void> merge(Map<String, Record<T>> remoteRecords) async {
    var localMap = await _store.getMap();
    var updatedRecords = <String, Record<T>>{};

    remoteRecords.forEach((key, remoteRecord) {
      var localRecord = localMap[key];

      if (localRecord == null) {
        // Insert if there's no local copy
        updatedRecords[key] = Record<T>(remoteRecord.hlc, remoteRecord.value);
      } else if (localRecord.hlc < remoteRecord.hlc) {
        // Update if local copy is older
        _canonicalTime = Hlc.recv(_canonicalTime, remoteRecord.hlc);
        updatedRecords[key] = Record<T>(_canonicalTime, remoteRecord.value);
      }
    });

    await _store.putAll(updatedRecords);
  }

  @override
  String toString() => _store.toString();
}

class Record<T> {
  final Hlc hlc;
  final T value;

  bool get isDeleted => value == null;

  Record(this.hlc, this.value);

  Record.fromJson(Map<String, dynamic> map, [Decoder<T> decoder])
      : hlc = Hlc.fromLogicalTime(map['hlc']),
        value = decoder == null ? map['value'] : decoder(map['value']);

  Map<String, dynamic> toJson() => {'hlc': hlc.logicalTime, 'value': value};

  @override
  bool operator ==(other) =>
      other is Record<T> && hlc == other.hlc && value == other.value;

  @override
  String toString() => toJson().toString();
}
