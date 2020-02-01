import '../crdt.dart';
import 'store.dart';

typedef Decoder<T> = T Function(Map<String, dynamic> map);

class Crdt<T> {
  final Store<T> _store;

  Hlc _canonicalTime;

  Map<String, Record<T>> get map => _store.map;

  Crdt(this._store) {
    _canonicalTime = Hlc(0);

    // Seed max canonical time
    for (var item in _store.values) {
      if (_canonicalTime < item.hlc) {
        _canonicalTime = item.hlc;
      }
    }
  }

  Crdt.fromMap(Map<String, Record<T>> map) : this(MapStore(map));

  Crdt.fromJson(Map<String, dynamic> map, [Decoder<T> decoder])
      : this.fromMap(map.map(
            (key, value) => MapEntry(key, Record<T>.fromJson(value, decoder))));

  Map<String, Record<T>> toJson() => map;

  Record<T> operator [](String key) => _store[key];

  void operator []=(String key, T value) {
    _canonicalTime = Hlc.send(_canonicalTime);
    _store[key] = Record<T>(_canonicalTime, value);
  }

  dynamic delete(String key) => this[key] = null;

  void merge(Map<String, Record<T>> remoteRecords) {
    remoteRecords.forEach((key, remoteRecord) {
      var localRecord = _store[key];

      if (localRecord == null) {
        // Insert if there's no local copy
        _store[key] = Record<T>(remoteRecord.hlc, remoteRecord.value);
      } else if (localRecord.hlc < remoteRecord.hlc) {
        // Update if local copy is older
        _canonicalTime = Hlc.recv(_canonicalTime, remoteRecord.hlc);
        _store[key] = Record<T>(_canonicalTime, remoteRecord.value);
      }
    });
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
