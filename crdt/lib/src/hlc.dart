import 'dart:math';

const _microsMask = 0xFFFFFFFFFFFF0000;
const _counterMask = 0xFFFF;
const _maxCounter = _counterMask;
const _maxDrift = 60000000; // 1h in µs

// Used to disambiguate otherwise equal HLCs deterministically.
// In this case, node ids with a lower string comparison win.
Comparator<String> _idDisambiguator = (s1, s2) => s2.compareTo(s1);

/// A Hybrid Logical Clock implementation.
/// This class trades time precision for a guaranteed monotonically increasing
/// clock in distributed systems.
/// Inspiration: https://cse.buffalo.edu/tech-reports/2014-04.pdf
class Hlc implements Comparable<Hlc> {
  final int micros;
  final int counter;

  final String nodeId;

  int get logicalTime => (micros & _microsMask) + counter;

  const Hlc(int micros, this.counter, this.nodeId)
      : micros = micros & _microsMask,
        assert(counter <= _maxCounter),
        assert(micros != null),
        assert(counter != null),
        assert(nodeId != null);

  const Hlc.zero(String nodeId) : this(0, 0, nodeId);

  Hlc.now(String nodeId)
      : this(DateTime.now().microsecondsSinceEpoch, 0, nodeId);

  const Hlc.fromLogicalTime(logicalTime, String nodeId)
      : this(logicalTime & _microsMask, logicalTime & _counterMask, nodeId);

  factory Hlc.parse(String timestamp) {
    final counterDash = timestamp.indexOf('-', timestamp.lastIndexOf(':'));
    final nodeIdDash = timestamp.indexOf('-', counterDash + 1);
    final micros = DateTime.parse(timestamp.substring(0, counterDash))
        .microsecondsSinceEpoch;
    final counter =
        int.parse(timestamp.substring(counterDash + 1, nodeIdDash), radix: 16);
    final nodeId = timestamp.substring(nodeIdDash + 1);
    return Hlc(micros, counter, nodeId);
  }

  Hlc apply({int micros, int counter, String nodeId}) => Hlc(
      micros ?? this.micros, counter ?? this.counter, nodeId ?? this.nodeId);

  /// Generates a unique, monotonic timestamp suitable for transmission to
  /// another system in string format. Local wall time will be used if
  /// [micros] isn't supplied.
  factory Hlc.send(Hlc canonical, {int micros}) {
    // Retrieve the local wall time if micros is null
    micros = (micros ?? DateTime.now().microsecondsSinceEpoch) & _microsMask;

    // Unpack the canonical time and counter
    final microsOld = canonical.micros;
    final counterOld = canonical.counter;

    // Calculate the next time and counter
    // * ensure that the logical time never goes backward
    // * increment the counter if time does not advance
    final microsNew = max(microsOld, micros);
    final counterNew = microsOld == microsNew ? counterOld + 1 : 0;

    // Check the result for drift and counter overflow
    if (microsNew - micros > _maxDrift) {
      throw ClockDriftException(microsNew, micros);
    }
    if (counterNew > _maxCounter) {
      throw OverflowException(counterNew);
    }

    return Hlc(microsNew, counterNew, canonical.nodeId);
  }

  /// Compares and validates a timestamp from a remote system with the local
  /// canonical timestamp to preserve monotonicity.
  /// Returns an updated canonical timestamp instance.
  /// Local wall time will be used if [micros] isn't supplied.
  factory Hlc.recv(Hlc canonical, Hlc remote, {int micros}) {
    // Retrieve the local wall time if micros is null
    micros = (micros ?? DateTime.now().microsecondsSinceEpoch) & _microsMask;

    // Assert the node id
    if (canonical.nodeId == remote.nodeId) {
      throw DuplicateNodeException(canonical.nodeId);
    }
    // Assert the remote clock drift
    if (remote.micros - micros > _maxDrift) {
      throw ClockDriftException(remote.micros, micros);
    }

    // No need to do any more work if the canonical logical time is higher
    if (canonical.logicalTime > remote.logicalTime) return canonical;

    // Ensure that new canonical time is higher than the remote
    final microsNew = max(micros, remote.micros);
    final counterNew = microsNew == remote.micros ? remote.counter + 1 : 0;

    return Hlc(microsNew, counterNew, canonical.nodeId);
  }

  String toJson() => toString();

  @override
  String toString() =>
      '${DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true).toIso8601String()}'
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

  ClockDriftException(int microsTs, int microsWall)
      : drift = microsTs - microsWall;

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
