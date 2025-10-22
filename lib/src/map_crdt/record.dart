import '../hlc.dart';

/// Stores a value associated with a given HLC
class Record {
  final Object? data;
  final Hlc hlc;
  final Hlc modified;

  bool get isDeleted => data == null;

  Record(this.data, this.hlc, this.modified);

  @override
  String toString() => '$data';
}
