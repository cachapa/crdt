export 'bigint_max.dart';

import 'package:crdt/src/bigint_max.dart';

const _shift = 16;
BigInt _maxCounter = BigInt.from(0xFFFF);
BigInt _maxDrift = BigInt.from(60000); // 1 minute in ms

/// A Hybrid Logical Clock implementation.
/// This class trades time precision for a guaranteed monotonically increasing
/// clock in distributed systems.
/// Inspiration: https://cse.buffalo.edu/tech-reports/2014-04.pdf
///
/// This is a JavaScript compatible version that uses BigInt.
/// CRDTs use 64-bit integers but JavaScript integers are in the range of
/// -(2^53 - 1)..(2^53 - 1) and bit operations are truncated to 32-bit.
/// BigInt is able to handle full 64-bit range in JavaScript but are much less
/// efficient.
class Hlc<T> implements Comparable<Hlc> {
  final BigInt millis;
  final BigInt counter;
  final T nodeId;

  BigInt get logicalTime => (millis << _shift) + counter;

  Hlc(BigInt millis, this.counter, this.nodeId)
      : assert(counter <= _maxCounter),
        assert(nodeId is Comparable),
        assert(nodeId != null),
        // Detect microseconds and convert to millis
        millis = millis < BigInt.from(0x0001000000000000)
            ? millis
            : millis ~/ BigInt.from(1000);

  Hlc.zero(T nodeId) : this(BigInt.zero, BigInt.zero, nodeId);

  Hlc.fromDate(DateTime dateTime, T nodeId)
      : this(BigInt.from(dateTime.millisecondsSinceEpoch), BigInt.zero, nodeId);

  Hlc.now(T nodeId) : this.fromDate(DateTime.now(), nodeId);

  Hlc.fromLogicalTime(BigInt logicalTime, T nodeId)
      : this(logicalTime >> _shift, logicalTime & _maxCounter, nodeId);

  factory Hlc.parse(String timestamp, [T Function(String value)? idDecoder]) {
    final counterDash = timestamp.indexOf('-', timestamp.lastIndexOf(':'));
    final nodeIdDash = timestamp.indexOf('-', counterDash + 1);
    final millis = DateTime.parse(timestamp.substring(0, counterDash))
        .millisecondsSinceEpoch;
    final counter =
        int.parse(timestamp.substring(counterDash + 1, nodeIdDash), radix: 16);
    final nodeId = timestamp.substring(nodeIdDash + 1);
    return Hlc(BigInt.from(millis), BigInt.from(counter),
        idDecoder != null ? idDecoder(nodeId) : nodeId as T);
  }

  Hlc apply({BigInt? millis, BigInt? counter, T? nodeId}) => Hlc(
      millis ?? this.millis, counter ?? this.counter, nodeId ?? this.nodeId);

  /// Generates a unique, monotonic timestamp suitable for transmission to
  /// another system in string format. Local wall time will be used if
  /// [millis] isn't supplied.
  factory Hlc.send(Hlc<T> canonical, {BigInt? millis}) {
    // Retrieve the local wall time if millis is null
    millis = millis ?? BigInt.from(DateTime.now().millisecondsSinceEpoch);

    // Unpack the canonical time and counter
    final millisOld = canonical.millis;
    final counterOld = canonical.counter;

    // Calculate the next time and counter
    // * ensure that the logical time never goes backward
    // * increment the counter if time does not advance
    final millisNew = max(millisOld, millis);
    final counterNew =
        millisOld == millisNew ? counterOld + BigInt.one : BigInt.zero;

    // Check the result for drift and counter overflow
    if (millisNew - millis > _maxDrift) {
      throw ClockDriftException(millisNew, millis);
    }
    if (counterNew > _maxCounter) {
      throw OverflowException(counterNew.toInt());
    }

    return Hlc(millisNew, counterNew, canonical.nodeId);
  }

  /// Compares and validates a timestamp from a remote system with the local
  /// canonical timestamp to preserve monotonicity.
  /// Returns an updated canonical timestamp instance.
  /// Local wall time will be used if [millis] isn't supplied.
  factory Hlc.recv(Hlc<T> canonical, Hlc<T> remote, {BigInt? millis}) {
    // Retrieve the local wall time if millis is null
    millis = millis ?? BigInt.from(DateTime.now().millisecondsSinceEpoch);

    // No need to do any more work if the remote logical time is lower
    if (canonical.logicalTime >= remote.logicalTime) return canonical;

    // Assert the node id
    if (canonical.nodeId == remote.nodeId) {
      throw DuplicateNodeException(canonical.nodeId.toString());
    }
    // Assert the remote clock drift
    if (remote.millis - millis > _maxDrift) {
      throw ClockDriftException(remote.millis, millis);
    }

    return Hlc<T>.fromLogicalTime(remote.logicalTime, canonical.nodeId);
  }

  String toJson() => toString();

  @override
  String toString() =>
      '${DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true).toIso8601String()}'
      '-${counter.toRadixString(16).toUpperCase().padLeft(4, '0')}'
      '-$nodeId';

  @override
  int get hashCode => toString().hashCode;

  @override
  bool operator ==(other) => other is Hlc<T> && compareTo(other) == 0;

  bool operator <(other) => other is Hlc<T> && compareTo(other) < 0;

  bool operator <=(other) => this < other || this == other;

  bool operator >(other) => other is Hlc<T> && compareTo(other) > 0;

  bool operator >=(other) => this > other || this == other;

  @override
  int compareTo(Hlc other) {
    final time = logicalTime.compareTo(other.logicalTime);
    return time != 0 ? time : (nodeId as Comparable).compareTo(other.nodeId);
  }
}

class ClockDriftException implements Exception {
  final BigInt drift;

  ClockDriftException(BigInt millisTs, BigInt millisWall)
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
