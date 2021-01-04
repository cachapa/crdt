import 'dart:convert';

import 'package:crdt/crdt.dart';

class CrdtJson {
  CrdtJson._();

  static String encode<K, V>(Map<K, Record<V>> map,
          {KeyEncoder<K>? keyEncoder, ValueEncoder<K, V>? valueEncoder}) =>
      jsonEncode(
        map.map(
          (key, value) => MapEntry(
            keyEncoder == null ? key.toString() : keyEncoder(key),
            value.toJson(key, valueEncoder: valueEncoder),
          ),
        ),
      );

  static Map<K, Record<V>> decode<K, V>(String json, Hlc canonicalTime,
      {KeyDecoder<K>? keyDecoder,
      ValueDecoder<V>? valueDecoder,
      NodeIdDecoder? nodeIdDecoder}) {
    final now = Hlc.now(canonicalTime.nodeId);
    final modified = canonicalTime >= now ? canonicalTime : now;
    return (jsonDecode(json) as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        keyDecoder == null ? key as K : keyDecoder(key),
        Record.fromJson(
          key,
          value,
          modified,
          valueDecoder: valueDecoder,
          nodeIdDecoder: nodeIdDecoder,
        ),
      ),
    );
  }
}
