import 'hlc.dart' if (dart.library.js) 'hlcjs.dart';

typedef KeyEncoder<K> = String Function(K key);
typedef ValueEncoder<K, V> = dynamic Function(K key, V? value);

typedef KeyDecoder<K> = K Function(String key);
typedef ValueDecoder<V> = V Function(String key, dynamic value);

typedef NodeIdDecoder = dynamic Function(String nodeId);

/// Stores a value associated with a given HLC
class Record<V> {
  final Hlc hlc;
  final V? value;
  final Hlc modified;

  bool get isDeleted => value == null;

  Record(this.hlc, this.value, this.modified);

  Record.fromJson(dynamic key, Map<String, dynamic> map, this.modified,
      {ValueDecoder<V>? valueDecoder, NodeIdDecoder? nodeIdDecoder})
      : hlc = Hlc.parse(map['hlc'], nodeIdDecoder),
        value = valueDecoder == null || map['value'] == null
            ? map['value']
            : valueDecoder(key, map['value']);

  Map<String, dynamic> toJson<K>(K key, {ValueEncoder<K, V>? valueEncoder}) => {
        'hlc': hlc.toJson(),
        'value': valueEncoder == null ? value : valueEncoder(key, value),
      };

  @override
  bool operator ==(other) =>
      other is Record<V> && hlc == other.hlc && value == other.value;

  @override
  String toString() => toJson('').toString();
}
