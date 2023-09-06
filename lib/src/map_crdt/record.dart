import '../hlc.dart';

/// Stores a value associated with a given HLC
class Record<V> {
  final V? value;
  final bool isDeleted;
  final Hlc hlc;
  final Hlc modified;

  Record(this.value, this.isDeleted, this.hlc, this.modified);

  /// Convenience method to implicitly copy the record type
  Record<V> copyWith(V? value, bool isDeleted, Hlc hlc, Hlc modified) =>
      Record(value, isDeleted, hlc, modified);

  Map<String, dynamic> toJson() => {
        'value': value,
        'is_deleted': isDeleted,
        'hlc': hlc,
      };

  @override
  bool operator ==(other) =>
      other is Record<V> && hlc == other.hlc && value == other.value;

  @override
  int get hashCode => Object.hash(hlc, value, modified);

  @override
  String toString() => toJson().toString();
}
