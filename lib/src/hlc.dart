import 'dart:math';

const _shift = 16;
const _maxCounter = 0xFFFF;
const _maxDrift = 60000; // 1 minute in ms

/// A Hybrid Logical Clock implementation.
/// This class trades time precision for a guaranteed monotonically increasing
/// clock in distributed systems.
/// Inspiration: https://cse.buffalo.edu/tech-reports/2014-04.pdf
class Hlc implements Comparable<Hlc> {
  final int millis;
  final int counter;
  final String nodeId;

  int get logicalTime => (millis << _shift) + counter;

  const Hlc(int millis, this.counter, this.nodeId)
      : assert(counter <= _maxCounter),
        // Detect microseconds and convert to millis
        millis = millis < 0x0001000000000000 ? millis : millis ~/ 1000;

  const Hlc.zero(String nodeId) : this(0, 0, nodeId);

  Hlc.fromDate(DateTime dateTime, String nodeId)
      : this(dateTime.millisecondsSinceEpoch, 0, nodeId);

  Hlc.now(String nodeId) : this.fromDate(DateTime.now(), nodeId);

  Hlc.fromLogicalTime(logicalTime, String nodeId)
      : this(logicalTime >> _shift, logicalTime & _maxCounter, nodeId);

  factory Hlc.parse(String timestamp) {
    final counterDash = timestamp.indexOf('-', timestamp.lastIndexOf(':'));
    final nodeIdDash = timestamp.indexOf('-', counterDash + 1);
    final millis = DateTime.parse(timestamp.substring(0, counterDash))
        .millisecondsSinceEpoch;
    final counter =
        int.parse(timestamp.substring(counterDash + 1, nodeIdDash), radix: 16);
    final nodeId = timestamp.substring(nodeIdDash + 1);
    return Hlc(millis, counter, nodeId);
  }

  Hlc apply({int? millis, int? counter, String? nodeId}) => Hlc(
      millis ?? this.millis, counter ?? this.counter, nodeId ?? this.nodeId);

  /// Increments the current timestamp for transmission to another system.
  /// The local wall time will be used if [wallMillis] isn't supplied.
  Hlc increment({int? wallMillis}) {
    // Retrieve the local wall time if millis is null
    wallMillis ??= DateTime.now().millisecondsSinceEpoch;

    // Calculate the next time and counter
    // * ensure that the logical time never goes backward
    // * increment the counter if time does not advance
    final millisNew = max(millis, wallMillis);
    final counterNew = millis == millisNew ? counter + 1 : 0;

    // Check the result for drift and counter overflow
    if (millisNew - wallMillis > _maxDrift) {
      throw ClockDriftException(millisNew, wallMillis);
    }
    if (counterNew > _maxCounter) {
      throw OverflowException(counterNew);
    }

    return Hlc(millisNew, counterNew, nodeId);
  }

  /// Compares and validates a timestamp from a remote system with the local
  /// timestamp to preserve monotonicity.
  /// Local wall time will be used if [wallMillis] isn't supplied.
  Hlc merge(Hlc remote, {int? wallMillis}) {
    // Retrieve the local wall time if millis is null
    wallMillis ??= DateTime.now().millisecondsSinceEpoch;

    // No need to do any more work if the remote logical time is lower
    if (logicalTime >= remote.logicalTime) return this;

    // Assert the node id
    if (nodeId == remote.nodeId) {
      throw DuplicateNodeException(nodeId);
    }
    // Assert the remote clock drift
    if (remote.millis - wallMillis > _maxDrift) {
      throw ClockDriftException(remote.millis, wallMillis);
    }

    return Hlc.fromLogicalTime(remote.logicalTime, nodeId);
  }

  /// Convenience class to conform to the dart:convert convention.
  String toJson() => toString();

  @override
  String toString() =>
      '${DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toIso8601String()}'
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
  int compareTo(Hlc other) {
    final time = logicalTime.compareTo(other.logicalTime);
    return time != 0 ? time : nodeId.compareTo(other.nodeId);
  }
}

class ClockDriftException implements Exception {
  final int drift;

  ClockDriftException(int millisTs, int millisWall)
      : drift = millisTs - millisWall;

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
