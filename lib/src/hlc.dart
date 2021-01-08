import 'dart:math';

const _shift = 16;
const _maxCounter = 0xFFFF;
const _maxDrift = 60000; // 1 minute in ms

// Used to disambiguate otherwise equal HLCs deterministically.
// In this case, node ids with a lower string comparison win.
Comparator<String> _idDisambiguator = (s1, s2) => s2.compareTo(s1);

/// A Hybrid Logical Clock implementation.
/// This class trades time precision for a guaranteed monotonically increasing
/// clock in distributed systems.
/// Inspiration: https://cse.buffalo.edu/tech-reports/2014-04.pdf
class Hlc implements Comparable<Hlc> {
  final int millis;
  final int counter;
  final String nodeId;

  int get logicalTime => (millis << _shift) + counter;

  Hlc(this.millis, this.counter, this.nodeId)
      : assert(millis < 0x0001000000000000),
        // Sanity check: ensure time in millis, not micros
        assert(counter <= _maxCounter),
        assert(millis != null),
        assert(counter != null),
        assert(nodeId != null);

  Hlc.zero(String nodeId) : this(0, 0, nodeId);

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

  Hlc apply({int millis, int counter, String nodeId}) => Hlc(
      millis ?? this.millis, counter ?? this.counter, nodeId ?? this.nodeId);

  /// Generates a unique, monotonic timestamp suitable for transmission to
  /// another system in string format. Local wall time will be used if
  /// [millis] isn't supplied.
  factory Hlc.send(Hlc canonical, {int millis}) {
    // Retrieve the local wall time if millis is null
    millis = millis ?? DateTime.now().millisecondsSinceEpoch;

    // Unpack the canonical time and counter
    final millisOld = canonical.millis;
    final counterOld = canonical.counter;

    // Calculate the next time and counter
    // * ensure that the logical time never goes backward
    // * increment the counter if time does not advance
    final millisNew = max(millisOld, millis);
    final counterNew = millisOld == millisNew ? counterOld + 1 : 0;

    // Check the result for drift and counter overflow
    if (millisNew - millis > _maxDrift) {
      throw ClockDriftException(millisNew, millis);
    }
    if (counterNew > _maxCounter) {
      throw OverflowException(counterNew);
    }

    return Hlc(millisNew, counterNew, canonical.nodeId);
  }

  /// Compares and validates a timestamp from a remote system with the local
  /// canonical timestamp to preserve monotonicity.
  /// Returns an updated canonical timestamp instance.
  /// Local wall time will be used if [millis] isn't supplied.
  factory Hlc.recv(Hlc canonical, Hlc remote, {int millis}) {
    // Retrieve the local wall time if millis is null
    millis = millis ?? DateTime.now().millisecondsSinceEpoch;

    // Assert the node id
    if (canonical.nodeId == remote.nodeId) {
      throw DuplicateNodeException(canonical.nodeId);
    }
    // Assert the remote clock drift
    if (remote.millis - millis > _maxDrift) {
      throw ClockDriftException(remote.millis, millis);
    }

    // No need to do any more work if the canonical logical time is higher
    if (canonical.logicalTime > remote.logicalTime) return canonical;

    // Ensure that new canonical time is higher than the remote
    final millisNew = max(millis, remote.millis);
    final counterNew = millisNew == remote.millis ? remote.counter + 1 : 0;

    if (counterNew > _maxCounter) {
      throw OverflowException(counterNew);
    }

    return Hlc(millisNew, counterNew, canonical.nodeId);
  }

  String toJson() => toString();

  @override
  String toString() =>
      '${DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toIso8601String()}'
      '-${counter.toRadixString(16).toUpperCase().padLeft(4, '0')}'
      '-$nodeId';

  @override
  int get hashCode => toString().hashCode;

  @override
  bool operator ==(other) =>
      other is Hlc &&
      logicalTime == other.logicalTime &&
      nodeId == other.nodeId;

  bool operator <(other) =>
      other is Hlc &&
      (logicalTime < other.logicalTime ||
          logicalTime == other.logicalTime &&
              _idDisambiguator(nodeId, other.nodeId) < 0);

  bool operator <=(other) => this < other || this == other;

  bool operator >(other) =>
      other is Hlc &&
      (logicalTime > other.logicalTime ||
          logicalTime == other.logicalTime &&
              _idDisambiguator(nodeId, other.nodeId) > 0);

  bool operator >=(other) => this > other || this == other;

  @override
  int compareTo(Hlc other) {
    final time = logicalTime.compareTo(other.logicalTime);
    return time == 0 ? _idDisambiguator(nodeId, other.nodeId) : time;
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
