import 'dart:math';

const _maxDrift = 60000; // ms
const _maxCounter = 65535;

/// A Hybrid Logical Clock implementation. Implements https://cse.buffalo.edu/tech-reports/2014-04.pdf
class Timestamp {
  final int millis;
  final int counter;

  Timestamp([int millis, this.counter = 0])
      : millis = millis ?? DateTime.now().millisecondsSinceEpoch;

  factory Timestamp.parse(String timestamp) {
    var lastDash = timestamp.lastIndexOf('-');
    var millis =
        DateTime.parse(timestamp.substring(0, lastDash)).millisecondsSinceEpoch;
    var counter = int.parse(timestamp.substring(lastDash + 1), radix: 16);
    return Timestamp(millis, counter);
  }

  /// Generates a unique, monotonic timestamp suitable for transmission to
  /// another system in string format. Local wall time will be used if [millis]
  /// isn't supplied, useful for testing.
  factory Timestamp.send(Timestamp timestamp, [int millis]) {
    // Retrieve the local wall time if millis is null
    millis ??= DateTime.now().millisecondsSinceEpoch;

    // Unpack the timestamp's time and counter
    var millisOld = timestamp.millis;
    var counterOld = timestamp.counter;

    // Calculate the next logical time and counter
    // * ensure that the logical time never goes backward
    // * increment the counter if phys time does not advance
    var millisNew = max(millisOld, millis);
    var counterNew = millisOld == millisNew ? counterOld + 1 : 0;

    // Check the result for drift and counter overflow
    if (millisNew - millis > _maxDrift) {
      throw ClockDriftException(millisNew, millis);
    }
    if (counterNew > _maxCounter) {
      throw OverflowException(counterNew);
    }

    return Timestamp(millisNew, counterNew);
  }

  /// Parses and merges a timestamp from a remote system with the local
  /// canonical timestamp to preserve monotonicity. Returns an updated canonical
  /// timestamp instance. Local wall time will be used if [millis] isn't
  /// supplied, useful for testing.
  factory Timestamp.recv(Timestamp local, Timestamp remote, [int millis]) {
    // Retrieve the local wall time if millis is null
    millis ??= DateTime.now().millisecondsSinceEpoch;

    // Unpack the remote's time and counter
    var millisRemote = remote.millis;
    var counterRemote = remote.counter;

    // Assert remote clock drift
    if (millisRemote - millis > _maxDrift) {
      throw ClockDriftException(millisRemote, millis);
    }

    // Unpack the clock.timestamp logical time and counter
    var millisLocal = local.millis;
    var counterLocal = local.counter;

    // Calculate the next logical time and counter.
    // Ensure that the logical time never goes backward;
    // * if all logical clocks are equal, increment the max counter,
    // * if max = old > message, increment local counter,
    // * if max = message > old, increment message counter,
    // * otherwise, clocks are monotonic, reset counter
    var millisNew = max(max(millisLocal, millis), millisRemote);
    var counterNew = millisNew == millisLocal && millisNew == millisRemote
        ? max(counterLocal, counterRemote) + 1
        : millisNew == millisLocal
            ? counterLocal + 1
            : millisNew == millisRemote ? counterRemote + 1 : 0;

    // Check the result for drift and counter overflow
    if (millisNew - millis > _maxDrift) {
      throw ClockDriftException(millisNew, millis);
    }
    if (counterNew > _maxCounter) {
      throw OverflowException(counterNew);
    }

    return Timestamp(millisNew, counterNew);
  }

  @override
  String toString() =>
      '${DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toIso8601String()}'
      '-'
      '${counter.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  @override
  int get hashCode => toString().hashCode;

  @override
  bool operator ==(other) =>
      other is Timestamp && millis == other.millis && counter == other.counter;

  bool operator <(other) =>
      other is Timestamp &&
      (millis < other.millis ||
          (millis == other.millis && counter < other.counter));
}

class ClockDriftException implements Exception {
  final int drift;

  ClockDriftException(int millisTs, int millisWall)
      : drift = millisWall - millisTs;

  @override
  String toString() => 'Clock drift of $drift ms exceeds maximum ($_maxDrift).';
}

class OverflowException implements Exception {
  final int counter;

  OverflowException(this.counter);

  @override
  String toString() => 'Timestamp counter overflow: $counter.';
}
