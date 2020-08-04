import 'hlc.dart';

typedef KeyDecoder<K> = K Function(String key);
typedef ValueDecoder<V> = V Function(dynamic value);

/// Stores a value associated with a given HLC
class Record<V> {
  final Hlc hlc;
  final V value;

  bool get isDeleted => value == null;

  Record(this.hlc, this.value);

  Record.fromJson(Map<String, dynamic> map, [ValueDecoder<V> decoder])
      : hlc = Hlc.parse(map['hlc']),
        value = decoder == null || map['value'] == null
            ? map['value']
            : decoder(map['value']);

  Map<String, dynamic> toJson() => {'hlc': hlc.toJson(), 'value': value};

  @override
  bool operator ==(other) =>
      other is Record<V> && hlc == other.hlc && value == other.value;

  @override
  String toString() => toJson().toString();
}
