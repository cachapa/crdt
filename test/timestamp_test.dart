import 'package:crdt/src/hlc.dart';
import 'package:test/test.dart';

var testHlc = Hlc(1579633503119000, 42);

void main() {
  group('Comparison', () {
    test('Equality', () {
      var hlc = Hlc(1579633503119000, 42);
      expect(testHlc, hlc);
    });

    test('Equality with different nodes', () {
      var hlc = Hlc(1579633503119000, 42);
      expect(testHlc, hlc);
    });

    test('Less than millis', () {
      var hlc = Hlc(1579733503119000, 42);
      expect(testHlc < hlc, isTrue);
    });

    test('Less than counter', () {
      var hlc = Hlc(1579633503119000, 43);
      expect(testHlc < hlc, isTrue);
    });

    test('Fail less than if equals', () {
      var hlc = Hlc(1579633503119000, 42);
      expect(testHlc < hlc, isFalse);
    });

    test('Fail less than if millis and counter disagree', () {
      var hlc = Hlc(1579533503119000, 43);
      expect(testHlc < hlc, isFalse);
    });
  });

  group('Logical time representation', () {
    test('Hlc as logical time', () {
      expect(testHlc.logicalTime, 1579633503109162);
    });

    test('Hlc from logical time', () {
      expect(Hlc.fromLogicalTime(1579633503109162), testHlc);
    });
  });

  group('String operations', () {
    test('hlc to string', () {
      expect(testHlc.toString(), '2020-01-21T19:05:03.110Z-002A');
    });

    test('Parse hlc', () {
      expect(Hlc.parse('2020-01-21T19:05:03.119Z-002A'), testHlc);
    });
  });

  group('Send', () {
    test('Send before', () {
      var hlc = Hlc.send(testHlc, 1579633503110000);
      expect(hlc, isNot(testHlc));
      expect(hlc.toString(), '2020-01-21T19:05:03.110Z-002B');
    });

    test('Send simultaneous', () {
      var hlc = Hlc.send(testHlc, 1579633503119000);
      expect(hlc, isNot(testHlc));
      expect(hlc.toString(), '2020-01-21T19:05:03.110Z-002B');
    });

    test('Send later', () {
      var hlc = Hlc.send(testHlc, 1579733503119000);
      expect(hlc, Hlc(1579733503119000));
    });
  });

  group('Receive', () {
    test('Receive before', () {
      var remoteHlc = Hlc(1579633503110000);
      var hlc = Hlc.recv(testHlc, remoteHlc, 1579633503119000);
      expect(hlc, isNot(equals(testHlc)));
    });

    test('Receive simultaneous', () {
      var remoteHlc = Hlc(1579633503119000);
      var hlc = Hlc.recv(testHlc, remoteHlc, 1579633503119000);
      expect(hlc, isNot(testHlc));
    });

    test('Receive after', () {
      var remoteHlc = Hlc(1579633503119000);
      var hlc = Hlc.recv(testHlc, remoteHlc, 1579633503129000);
      expect(hlc, isNot(testHlc));
    });
  });
}
