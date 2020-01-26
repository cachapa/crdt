import 'dart:math';

const _maxDrift = 60000; // ms

class Timestamp {
  //extends Comparable<Timestamp> {
  final int millis;
  final int counter;
  final String nodeId;

  Timestamp(this.nodeId, [int millis, this.counter = 0])
      : millis = millis ?? DateTime.now().millisecondsSinceEpoch;

  factory Timestamp.parse(String timestamp) {
    var parts = timestamp.split('-');
    var millis =
        DateTime.parse(parts.getRange(0, 3).join('-')).millisecondsSinceEpoch;
    var counter = int.parse(parts[3], radix: 16);
    var nodeId = parts[4];
    return Timestamp(nodeId, millis, counter);
  }

  /// Generates a unique, monotonic timestamp suitable for transmission to
  /// another system in string format
  factory Timestamp.send(Timestamp timestamp, [int phys]) {
    // Retrieve the local wall time
    phys ??= DateTime.now().millisecondsSinceEpoch;

    // Unpack the clock.timestamp logical time and counter
    var lOld = timestamp.millis;
    var cOld = timestamp.counter;

    // Calculate the next logical time and counter
    // * ensure that the logical time never goes backward
    // * increment the counter if phys time does not advance
    var lNew = max(lOld, phys);
    var cNew = lOld == lNew ? cOld + 1 : 0;

    // Check the result for drift and counter overflow
    if (lNew - phys > _maxDrift) {
      throw ClockDriftException(lNew, phys, _maxDrift);
    }
    if (cNew > 65535) {
      throw OverflowException(cNew);
    }

    return Timestamp(timestamp.nodeId, lNew, cNew);
  }

  /// Parses and merges a timestamp from a remote system with the local
  /// timeglobal uniqueness and monotonicity are preserved
  factory Timestamp.recv(Timestamp clock, Timestamp msg, [int phys]) {
    phys ??= DateTime.now().millisecondsSinceEpoch;

    // Unpack the message wall time/counter
    var lMsg = msg.millis;
    var cMsg = msg.counter;

    // Assert the node id and remote clock drift
    if (msg.nodeId == clock.nodeId) {
      throw DuplicateNodeException(clock.nodeId);
    }
    if (lMsg - phys > _maxDrift) {
      throw ClockDriftException(lMsg, phys, _maxDrift);
    }

    // Unpack the clock.timestamp logical time and counter
    var lOld = clock.millis;
    var cOld = clock.counter;

    // Calculate the next logical time and counter.
    // Ensure that the logical time never goes backward;
    // * if all logical clocks are equal, increment the max counter,
    // * if max = old > message, increment local counter,
    // * if max = message > old, increment message counter,
    // * otherwise, clocks are monotonic, reset counter
    var lNew = max(max(lOld, phys), lMsg);
    var cNew = lNew == lOld && lNew == lMsg
        ? max(cOld, cMsg) + 1
        : lNew == lOld ? cOld + 1 : lNew == lMsg ? cMsg + 1 : 0;

    // Check the result for drift and counter overflow
    if (lNew - phys > _maxDrift) {
      throw ClockDriftException(lNew, phys, _maxDrift);
    }
    if (cNew > 65535) {
      throw OverflowException(cNew);
    }

    return Timestamp(clock.nodeId, lNew, cNew);
  }

  /// Create a copy with a new nodeId
  Timestamp clone(String nodeId) => Timestamp(nodeId, millis, counter);

  @override
  String toString() =>
      '${DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toIso8601String()}'
      '-'
      '${counter.toRadixString(16).toUpperCase().padLeft(4, '0')}'
      '-'
      '${nodeId.toString().padLeft(16, '0')}';

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
  final int lNew;
  final int phys;
  final int maxDrift;

  ClockDriftException(this.lNew, this.phys, this.maxDrift);

  @override
  String toString() => 'Maximum clock drift exceeded: $lNew, $phys, $maxDrift';
}

class OverflowException implements Exception {
  final int cNew;

  OverflowException(this.cNew);

  @override
  String toString() => 'Timestamp counter overflow: $cNew';
}

class DuplicateNodeException implements Exception {
  factory DuplicateNodeException(String node) =>
      Exception('duplicate node identifier $node');
}
