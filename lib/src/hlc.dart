import 'dart:math';

const _microsMask = 0xFFFFFFFFFFFF0000;
const _counterMask = 0xFFFF;
const _maxCounter = _counterMask;
const _maxDrift = 60000000; // 1h in µs

/// A Hybrid Logical Clock implementation.
/// This class trades time precision for a guaranteed monotonically increasing
/// clock in distributed systems.
/// Inspiration: https://cse.buffalo.edu/tech-reports/2014-04.pdf
class Hlc implements Comparable<Hlc> {
  final int logicalTime;

  int get micros => logicalTime & _microsMask;

  int get counter => logicalTime & _counterMask;

  Hlc([int micros, int counter = 0])
      : logicalTime =
            ((micros ?? DateTime.now().microsecondsSinceEpoch) & _microsMask) +
                counter,
        assert(counter <= _maxCounter);

  Hlc.fromLogicalTime(this.logicalTime);

  factory Hlc.parse(String timestamp) {
    var lastDash = timestamp.lastIndexOf('-');
    var micros =
        DateTime.parse(timestamp.substring(0, lastDash)).microsecondsSinceEpoch;
    var counter = int.parse(timestamp.substring(lastDash + 1), radix: 16);
    return Hlc(micros, counter);
  }

  /// Generates a unique, monotonic timestamp suitable for transmission to
  /// another system in string format. Local wall time will be used if [micros]
  /// isn't supplied, useful for testing.
  factory Hlc.send(Hlc timestamp, [int micros]) {
    // Retrieve the local wall time if micros is null
    micros = (micros ?? DateTime.now().microsecondsSinceEpoch) & _microsMask;

    // Unpack the timestamp's time and counter
    var microsOld = timestamp.micros;
    var counterOld = timestamp.counter;

    // Calculate the next logical time and counter
    // * ensure that the logical time never goes backward
    // * increment the counter if phys time does not advance
    var microsNew = max(microsOld, micros);
    var counterNew = microsOld == microsNew ? counterOld + 1 : 0;

    // Check the result for drift and counter overflow
    if (microsNew - micros > _maxDrift) {
      throw ClockDriftException(microsNew, micros);
    }
    if (counterNew > _maxCounter) {
      throw OverflowException(counterNew);
    }

    return Hlc(microsNew, counterNew);
  }

  /// Parses and merges a timestamp from a remote system with the local
  /// canonical timestamp to preserve monotonicity. Returns an updated canonical
  /// timestamp instance. Local wall time will be used if [micros] isn't
  /// supplied, useful for testing.
  factory Hlc.recv(Hlc local, Hlc remote, [int micros]) {
    // Retrieve the local wall time if micros is null
    micros = (micros ?? DateTime.now().microsecondsSinceEpoch) & _microsMask;

    // Unpack the remote's time and counter
    var microsRemote = remote.micros;
    var counterRemote = remote.counter;

    // Assert remote clock drift
    if (microsRemote - micros > _maxDrift) {
      throw ClockDriftException(microsRemote, micros);
    }

    // Unpack the clock.timestamp logical time and counter
    var microsLocal = local.micros;
    var counterLocal = local.counter;

    // Calculate the next logical time and counter.
    // Ensure that the logical time never goes backward;
    // * if all logical clocks are equal, increment the max counter,
    // * if max = old > message, increment local counter,
    // * if max = message > old, increment message counter,
    // * otherwise, clocks are monotonic, reset counter
    var microsNew = max(max(microsLocal, micros), microsRemote);
    var counterNew = microsNew == microsLocal && microsNew == microsRemote
        ? max(counterLocal, counterRemote) + 1
        : microsNew == microsLocal
            ? counterLocal + 1
            : microsNew == microsRemote ? counterRemote + 1 : 0;

    // Check the result for drift and counter overflow
    if (microsNew - micros > _maxDrift) {
      throw ClockDriftException(microsNew, micros);
    }
    if (counterNew > _maxCounter) {
      throw OverflowException(counterNew);
    }

    return Hlc(microsNew, counterNew);
  }

  String toJson() => toString();

  @override
  String toString() =>
      '${DateTime.fromMillisecondsSinceEpoch((micros / 1000).ceil(), isUtc: true).toIso8601String()}'
      '-'
      '${counter.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  @override
  int get hashCode => toString().hashCode;

  @override
  bool operator ==(other) => other is Hlc && logicalTime == other.logicalTime;

  bool operator <(other) => other is Hlc && logicalTime < other.logicalTime;

  bool operator <=(other) => other is Hlc && logicalTime <= other.logicalTime;

  bool operator >(other) => other is Hlc && logicalTime > other.logicalTime;

  bool operator >=(other) => other is Hlc && logicalTime >= other.logicalTime;

  @override
  int compareTo(Hlc other) => logicalTime.compareTo(other.logicalTime);
}

class ClockDriftException implements Exception {
  final int drift;

  ClockDriftException(int microsTs, int microsWall)
      : drift = microsTs - microsWall;

  @override
  String toString() => 'Clock drift of $drift ms exceeds maximum ($_maxDrift).';
}

class OverflowException implements Exception {
  final int counter;

  OverflowException(this.counter);

  @override
  String toString() => 'Timestamp counter overflow: $counter.';
}
