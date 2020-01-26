import 'package:crdt/src/timestamp.dart';
import 'package:test/test.dart';

var testTimestamp = Timestamp('12', 1579633503119, 42);

void main() {
  group('Comparison', () {
    test('Equality', () {
      var timestamp = Timestamp('12', 1579633503119, 42);
      expect(testTimestamp, timestamp);
    });

    test('Equality with different nodes', () {
      var timestamp = Timestamp('13', 1579633503119, 42);
      expect(testTimestamp, timestamp);
    });

    test('Less than timestamp', () {
      var timestamp = Timestamp('12', 1579633503120, 42);
      expect(testTimestamp < timestamp, isTrue);
    });

    test('Less than counter', () {
      var timestamp = Timestamp('12', 1579633503119, 43);
      expect(testTimestamp < timestamp, isTrue);
    });

    test('Fail less than if equals', () {
      var timestamp = Timestamp('12', 1579633503120, 42);
      expect(testTimestamp < timestamp, isTrue);
    });

    test('Fail less than if ts and counter disagree', () {
      var timestamp = Timestamp('12', 1579633503120, 43);
      expect(testTimestamp < timestamp, isTrue);
    });
  });

  group('String operations', () {
    test('Timestamp to string', () {
      expect(testTimestamp.toString(),
          '2020-01-21T19:05:03.119Z-002A-0000000000000012');
    });

    test('Parse timestamp', () {
      expect(Timestamp.parse('2020-01-21T19:05:03.119Z-002A-0000000000000012'),
          testTimestamp);
    });
  });

  group('Send', () {
    test('Send before', () {
      var timestamp = Timestamp.send(testTimestamp, 1579633503110);
      expect(timestamp, isNot(testTimestamp));
      expect(timestamp.toString(),
          '2020-01-21T19:05:03.119Z-002B-0000000000000012');
    });

    test('Send simultaneous', () {
      var timestamp = Timestamp.send(testTimestamp, 1579633503119);
      expect(timestamp, isNot(testTimestamp));
      expect(timestamp.toString(),
          '2020-01-21T19:05:03.119Z-002B-0000000000000012');
    });

    test('Send later', () {
      var timestamp = Timestamp.send(testTimestamp, 1579633503129);
      expect(timestamp, Timestamp('12', 1579633503129, 0));
      expect(timestamp.toString(),
          '2020-01-21T19:05:03.129Z-0000-0000000000000012');
    });
  });

  group('Receive', () {
    test('Receive before', () {
      var remoteTimestamp = Timestamp('14', 1579633503110, 0);
      var timestamp =
          Timestamp.recv(testTimestamp, remoteTimestamp, 1579633503119);
      expect(timestamp, isNot(equals(testTimestamp)));
      expect(timestamp.toString(),
          '2020-01-21T19:05:03.119Z-002B-0000000000000012');
    });

    test('Receive simultaneous', () {
      var remoteTimestamp = Timestamp('14', 1579633503119, 0);
      var timestamp =
          Timestamp.recv(testTimestamp, remoteTimestamp, 1579633503119);
      expect(timestamp, isNot(testTimestamp));
      expect(timestamp.toString(),
          '2020-01-21T19:05:03.119Z-002B-0000000000000012');
    });

    test('Receive after', () {
      var remoteTimestamp = Timestamp('14', 1579633503119, 0);
      var timestamp =
          Timestamp.recv(testTimestamp, remoteTimestamp, 1579633503129);
      expect(timestamp, isNot(testTimestamp));
      expect(timestamp.toString(),
          '2020-01-21T19:05:03.129Z-0000-0000000000000012');
    });
  });
}
