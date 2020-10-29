import 'hlc.dart';

typedef KeyEncoder<K> = String Function(K key);
typedef ValueEncoder<K, V> = String Function(K key, V value);

typedef KeyDecoder<K> = K Function(String key);
typedef ValueDecoder<V> = V Function(String key, dynamic value);

/// Stores a value associated with a given HLC
class Record<V> {
  final Hlc hlc;
  final V value;

  bool get isDeleted => value == null;

  Record(this.hlc, this.value);

  Record.fromJson(dynamic key, Map<String, dynamic> map,
      [ValueDecoder<V> valueDecoder])
      : hlc = Hlc.parse(map['hlc']),
        value = valueDecoder == null || map['value'] == null
            ? map['value']
            : valueDecoder(key, map['value']);

  Map<String, dynamic> toJson<K>(K key, {ValueEncoder<K, V> valueEncoder}) => {
        'hlc': hlc.toJson(),
        'value': valueEncoder == null ? value : valueEncoder(key, value),
      };

  @override
  bool operator ==(other) =>
      other is Record<V> && hlc == other.hlc && value == other.value;

  @override
  String toString() => toJson('').toString();
}
