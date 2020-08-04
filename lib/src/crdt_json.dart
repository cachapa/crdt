import 'dart:convert';

import 'package:crdt/crdt.dart';

class CrdtJson {
  CrdtJson._();

  static String encode<K>(Map<K, Record> map) => jsonEncode(
      map.map((key, value) => MapEntry(key.toString(), value.toJson())));

  static Map<K, Record<V>> decode<K, V>(String json,
          {KeyDecoder<K> keyDecoder, ValueDecoder<V> valueDecoder}) =>
      (jsonDecode(json) as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          keyDecoder == null ? key : keyDecoder(key),
          Record.fromJson(value, valueDecoder),
        ),
      );
}
