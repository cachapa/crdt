import 'hlc.dart';

typedef KeyEncoder<K> = String Function(K key);
typedef ValueEncoder<V> = String Function(V value);

typedef KeyDecoder<K> = K Function(String key);
typedef ValueDecoder<V> = V Function(dynamic value);

/// Stores a value associated with a given HLC
class Record<V> {
  final Hlc hlc;
  final V value;

  bool get isDeleted => value == null;

  Record(this.hlc, this.value);

  Record.fromJson(Map<String, dynamic> map, [ValueDecoder<V> valueDecoder])
      : hlc = Hlc.parse(map['hlc']),
        value = valueDecoder == null || map['value'] == null
            ? map['value']
            : valueDecoder(map['value']);

  Map<String, dynamic> toJson({ValueEncoder valueEncoder}) => {
        'hlc': hlc.toJson(),
        'value': valueEncoder == null ? value : valueEncoder(value),
      };

  @override
  bool operator ==(other) =>
      other is Record<V> && hlc == other.hlc && value == other.value;

  @override
  String toString() => toJson().toString();
}
