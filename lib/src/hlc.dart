const _timestampShift = 16;
const _maxCounter = 0xFFFF;
const _maxDrift = Duration(minutes: 1);

/// A Hybrid Logical Clock implementation.
/// This class trades time precision for a guaranteed monotonically increasing
/// clock in distributed systems.
/// Inspiration: https://cse.buffalo.edu/tech-reports/2014-04.pdf
class Hlc implements Comparable<Hlc> {
  final DateTime dateTime;
  final int counter;
  final String nodeId;

  /// Returns this timestamp's [dateTime] and [counter] components as a single
  /// 64-bit integer.
  ///
  /// Convenient when using HLCs to record local modified timestamps, where the
  /// node id isn't relevant and int comparisons are more efficient.
  int get logicalTime =>
      (dateTime.millisecondsSinceEpoch << _timestampShift) + counter;

  Hlc(DateTime dateTime, this.counter, this.nodeId)
    : // Ensure millisecond precision and UTC
      dateTime = dateTime.normalize,
      assert(counter <= _maxCounter);

  /// Instantiates an Hlc at the beginning of time and space: January 1, 1970.
  /// Use [generateNodeId()] for a random node id.
  Hlc.zero(String nodeId) : this(DateTime.utc(1970), 0, nodeId);

  /// Instantiates an Hlc at [dateTime] with logical counter zero.
  /// Use [generateNodeId()] for a random node id.
  Hlc.fromDate(DateTime dateTime, String nodeId) : this(dateTime, 0, nodeId);

  /// Instantiates an Hlc using the wall clock.
  /// Use [generateNodeId()] for a random node id.
  Hlc.now(String nodeId) : this.fromDate(DateTime.now(), nodeId);

  /// Instantiates an Hlc from a [logicalTime].
  /// Use [generateNodeId()] for a random node id.
  Hlc.fromLogicalTime(int logicalTime, String nodeId)
    : this(
        DateTime.fromMillisecondsSinceEpoch(logicalTime >> _timestampShift),
        logicalTime & _maxCounter,
        nodeId,
      );

  /// Parse an HLC string in the format `ISO8601 date-counter-node id`.
  factory Hlc.parse(String timestamp) {
    final counterDash = timestamp.indexOf('-', timestamp.lastIndexOf(':'));
    final nodeIdDash = timestamp.indexOf('-', counterDash + 1);
    final dateTime = DateTime.parse(timestamp.substring(0, counterDash));
    final counter = int.parse(
      timestamp.substring(counterDash + 1, nodeIdDash),
      radix: 16,
    );
    final nodeId = timestamp.substring(nodeIdDash + 1);
    return Hlc(dateTime, counter, nodeId);
  }

  static Hlc? maybeParse(String? timestamp) =>
      timestamp == null ? null : Hlc.parse(timestamp);

  /// Create a copy of this object applying the optional properties.
  Hlc apply({DateTime? dateTime, int? counter, String? nodeId}) => Hlc(
    dateTime ?? this.dateTime,
    counter ?? this.counter,
    nodeId ?? this.nodeId,
  );

  /// Increments the current timestamp for transmission to another system.
  /// The local wall time will be used if [wallTime] isn't supplied.
  Hlc increment({DateTime? wallTime}) {
    // Retrieve the local wall time if millis is null
    wallTime = (wallTime ?? DateTime.now()).normalize;

    // Calculate the next time and counter
    // * ensure that the logical time never goes backward
    // * increment the counter if time does not advance
    final dateTimeNew = wallTime.isAfter(dateTime) ? wallTime : dateTime;
    final counterNew = dateTimeNew == dateTime ? counter + 1 : 0;

    // Check the result for drift and counter overflow
    if (dateTimeNew.difference(wallTime) > _maxDrift) {
      throw ClockDriftException(dateTimeNew, wallTime);
    }
    if (counterNew > _maxCounter) {
      throw OverflowException(counterNew);
    }

    return Hlc(dateTimeNew, counterNew, nodeId);
  }

  /// Compares and validates a timestamp from a remote system with the local
  /// timestamp to preserve monotonicity.
  /// Local wall time will be used if [wallTime] isn't supplied.
  Hlc merge(Hlc remote, {DateTime? wallTime}) {
    // No need to do any more work if our date + counter is same or higher
    if (remote.dateTime.isBefore(dateTime) ||
        (remote.dateTime.isAtSameMomentAs(dateTime) &&
            remote.counter <= counter)) {
      return this;
    }

    // Assert the node id
    if (nodeId == remote.nodeId) {
      throw DuplicateNodeException(nodeId);
    }
    // Assert the remote clock drift
    wallTime = (wallTime ?? DateTime.now()).normalize;
    if (remote.dateTime.difference(wallTime) > _maxDrift) {
      throw ClockDriftException(remote.dateTime, wallTime);
    }

    return remote.apply(nodeId: nodeId);
  }

  /// Convenience method for easy json encoding.
  String toJson() => toString();

  @override
  String toString() =>
      '${dateTime.toIso8601String()}'
      '-${counter.toRadixString(16).toUpperCase().padLeft(4, '0')}'
      '-$nodeId';

  @override
  int get hashCode => Object.hash(dateTime, counter, nodeId);

  @override
  bool operator ==(other) => other is Hlc && compareTo(other) == 0;

  bool operator <(Hlc other) => compareTo(other) < 0;

  bool operator <=(Hlc other) => this < other || this == other;

  bool operator >(Hlc other) => compareTo(other) > 0;

  bool operator >=(Hlc other) => this > other || this == other;

  @override
  int compareTo(Hlc other) => dateTime.isAtSameMomentAs(other.dateTime)
      ? counter == other.counter
            ? nodeId.compareTo(other.nodeId)
            : counter - other.counter
      : dateTime.compareTo(other.dateTime);
}

class ClockDriftException implements Exception {
  final Duration drift;

  ClockDriftException(DateTime dateTime, DateTime wallTime)
    : drift = dateTime.difference(wallTime);

  @override
  String toString() => 'Clock drift of $drift ms exceeds maximum ($_maxDrift)';
}

class OverflowException implements Exception {
  final int counter;

  OverflowException(this.counter);

  @override
  String toString() => 'Timestamp counter overflow: $counter';
}

class DuplicateNodeException implements Exception {
  final String nodeId;

  DuplicateNodeException(this.nodeId);

  @override
  String toString() => 'Duplicate node: $nodeId';
}

extension on DateTime {
  // Clamps to millisecond precision and ensures it's UTC
  DateTime get normalize =>
      DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch, isUtc: true);
}
