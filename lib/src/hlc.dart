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

  const Hlc(this.dateTime, this.counter, this.nodeId)
      : assert(counter <= _maxCounter);

  /// Instantiates an Hlc at the beginning of time and space: January 1, 1970.
  Hlc.zero(String nodeId)
      : this(DateTime.fromMillisecondsSinceEpoch(0), 0, nodeId);

  /// Instantiates an Hlc at [dateTime] with logical counter zero.
  Hlc.fromDate(DateTime dateTime, String nodeId) : this(dateTime, 0, nodeId);

  /// Instantiates an Hlc using the wall clock.
  Hlc.now(String nodeId) : this.fromDate(DateTime.now(), nodeId);

  /// Parse an HLC string in the format `ISO8601 date-counter-node id`.
  factory Hlc.parse(String timestamp) {
    final counterDash = timestamp.indexOf('-', timestamp.lastIndexOf(':'));
    final nodeIdDash = timestamp.indexOf('-', counterDash + 1);
    final dateTime = DateTime.parse(timestamp.substring(0, counterDash));
    final counter =
        int.parse(timestamp.substring(counterDash + 1, nodeIdDash), radix: 16);
    final nodeId = timestamp.substring(nodeIdDash + 1);
    return Hlc(dateTime, counter, nodeId);
  }

  /// Create a copy of this object applying the optional properties.
  Hlc apply({DateTime? dateTime, int? counter, String? nodeId}) => Hlc(
      dateTime ?? this.dateTime,
      counter ?? this.counter,
      nodeId ?? this.nodeId);

  /// Increments the current timestamp for transmission to another system.
  /// The local wall time will be used if [wallTime] isn't supplied.
  Hlc increment({DateTime? wallTime}) {
    // Retrieve the local wall time if millis is null
    wallTime ??= DateTime.now();

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
    // Retrieve the local wall time if millis is null
    wallTime ??= DateTime.now();

    // No need to do any more work if our date + counter is same or higher
    if (remote.dateTime.isBefore(dateTime) ||
        (remote.dateTime.isAtSameMomentAs(dateTime) &&
            remote.counter <= counter)) return this;

    // Assert the node id
    if (nodeId == remote.nodeId) {
      throw DuplicateNodeException(nodeId);
    }
    // Assert the remote clock drift
    if (remote.dateTime.difference(wallTime) > _maxDrift) {
      throw ClockDriftException(remote.dateTime, wallTime);
    }

    return remote.apply(nodeId: nodeId);
  }

  /// Convenience method for easy json encoding.
  String toJson() => toString();

  @override
  String toString() => '${dateTime.toIso8601String()}'
      '-${counter.toRadixString(16).toUpperCase().padLeft(4, '0')}'
      '-$nodeId';

  @override
  int get hashCode => toString().hashCode;

  @override
  bool operator ==(other) => other is Hlc && compareTo(other) == 0;

  bool operator <(other) => other is Hlc && compareTo(other) < 0;

  bool operator <=(other) => this < other || this == other;

  bool operator >(other) => other is Hlc && compareTo(other) > 0;

  bool operator >=(other) => this > other || this == other;

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

extension StringHlcX on String {
  Hlc get toHlc => Hlc.parse(this);
}
