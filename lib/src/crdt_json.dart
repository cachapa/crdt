import 'dart:convert';

import 'package:crdt/crdt.dart';

class CrdtJson {
  CrdtJson._();

  static String encode<K, V>(Map<K, Record<V>> map,
          {KeyEncoder<K> keyEncoder, ValueEncoder<K, V> valueEncoder}) =>
      jsonEncode(
        map.map(
          (key, value) => MapEntry(
            keyEncoder == null ? key.toString() : keyEncoder(key),
            value.toJson(key, valueEncoder: valueEncoder),
          ),
        ),
      );

  static Map<K, Record<V>> decode<K, V>(String json,
          {KeyDecoder<K> keyDecoder, ValueDecoder<V> valueDecoder}) =>
      (jsonDecode(json) as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          keyDecoder == null ? key : keyDecoder(key),
          Record.fromJson(key, value, valueDecoder),
        ),
      );
}
