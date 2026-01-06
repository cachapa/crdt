import '../hlc.dart';

/// Stores a value associated with a given HLC
class Record {
  final Map<String, Object?>? data;
  final Hlc hlc;
  final int modified;

  bool get isDeleted => data == null;

  Record(this.data, this.hlc, this.modified);

  @override
  String toString() => '$data';
}
