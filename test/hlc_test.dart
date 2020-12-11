import 'package:crdt/src/hlc.dart';
import 'package:test/test.dart';

void main() {
  group('String operations', () {
    test('hlc to string', () {
      final hlc = Hlc.parse('2020-01-01T10:00:00.088064Z-0042-abc');
      expect(hlc.toString(), '2020-01-01T10:00:00.088064Z-0042-abc');
    });

    test('Parse hlc', () {
      expect(Hlc.parse('2020-01-01T10:00:00.089Z-0042-abc'),
          Hlc(1577872800088064, 0x42, 'abc'));
    });
  });

  group('Comparison', () {
    test('Equality', () {
      final hlc1 = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      final hlc2 = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      expect(hlc1, hlc2);
      expect(hlc1 <= hlc2, isTrue);
      expect(hlc1 >= hlc2, isTrue);
    });

    test('Different node ids', () {
      final hlc1 = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      final hlc2 = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abcd');
      expect(hlc1, isNot(hlc2));
    });

    test('Less than millis', () {
      final hlc1 = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      final hlc2 = Hlc.parse('2020-01-21T19:05:03.210Z-0000-abc');
      expect(hlc1 < hlc2, isTrue);
      expect(hlc1 <= hlc2, isTrue);
    });

    test('Less than counter', () {
      final hlc1 = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      final hlc2 = Hlc.parse('2020-01-21T19:05:03.110Z-0043-abc');
      expect(hlc1 < hlc2, isTrue);
      expect(hlc1 <= hlc2, isTrue);
    });

    test('Less than node id', () {
      final hlc1 = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      final hlc2 = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abd');
      expect(hlc1 > hlc2, isTrue);
      expect(hlc1 >= hlc2, isTrue);
    });

    test('Fail less than if equals', () {
      final hlc1 = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      final hlc2 = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      expect(hlc1 < hlc2, isFalse);
    });

    test('Fail less than if millis and counter disagree', () {
      final hlc1 = Hlc.parse('2020-01-21T19:05:03.210Z-000-abc');
      final hlc2 = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      expect(hlc1 < hlc2, isFalse);
    });

    test('More than millis', () {
      final hlc1 = Hlc.parse('2020-01-21T19:05:03.210Z-0042-abc');
      final hlc2 = Hlc.parse('2020-01-21T19:05:03.110Z-0000-abc');
      expect(hlc1 > hlc2, isTrue);
      expect(hlc1 >= hlc2, isTrue);
    });

    test('More than counter', () {
      final hlc1 = Hlc.parse('2020-01-21T19:05:03.210Z-0042-abc');
      final hlc2 = Hlc.parse('2020-01-21T19:05:03.110Z-0000-abc');
      expect(hlc1 > hlc2, isTrue);
      expect(hlc1 >= hlc2, isTrue);
    });

    test('More than node id', () {
      final hlc1 = Hlc.parse('2020-01-21T19:05:03.210Z-0042-abc');
      final hlc2 = Hlc.parse('2020-01-21T19:05:03.110Z-0000-abc');
      expect(hlc1 > hlc2, isTrue);
      expect(hlc1 >= hlc2, isTrue);
    });

    test('Compare', () {
      final hlc = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      expect(hlc.compareTo(Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc')), 0);

      expect(hlc.compareTo(Hlc.parse('2020-01-21T19:05:03.210Z-0042-abc')), -1);
      expect(hlc.compareTo(Hlc.parse('2020-01-21T19:05:03.110Z-0043-abc')), -1);
      expect(hlc.compareTo(Hlc.parse('2020-01-21T19:05:03.110Z-0042-abb')), -1);

      expect(hlc.compareTo(Hlc.parse('2020-01-21T19:05:03.010Z-0042-abc')), 1);
      expect(hlc.compareTo(Hlc.parse('2020-01-21T19:05:03.110Z-0041-abc')), 1);
      expect(hlc.compareTo(Hlc.parse('2020-01-21T19:05:03.110Z-0042-abd')), 1);
    });
  });

  group('Logical time representation', () {
    test('Hlc as logical time', () {
      final hlc = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      expect(hlc.logicalTime, 1579633503109186);
    });

    test('Hlc from logical time', () {
      final hlc = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      expect(Hlc.fromLogicalTime(1579633503109186, 'abc'), hlc);
    });
  });

  group('Send', () {
    test('Higher canonical time', () {
      final hlc = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      final sendHlc = Hlc.send(hlc, micros: 1579633503110000);
      expect(sendHlc, isNot(hlc));
      expect(sendHlc.micros, hlc.micros);
      expect(sendHlc.counter, 0x43);
      expect(sendHlc.nodeId, hlc.nodeId);
    });

    test('Equal canonical time', () {
      final hlc = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      final sendHlc = Hlc.send(hlc, micros: 1579633503109120);
      expect(sendHlc, isNot(hlc));
      expect(sendHlc.micros, 1579633503109120);
      expect(sendHlc.counter, 0x43);
      expect(sendHlc.nodeId, hlc.nodeId);
    });

    test('Lower canonical time', () {
      final hlc = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');
      final sendHlc = Hlc.send(hlc, micros: 1579633513070592);
      expect(sendHlc, isNot(hlc));
      expect(sendHlc.micros, 1579633513070592);
      expect(sendHlc.counter, 0);
      expect(sendHlc.nodeId, hlc.nodeId);
    });

    test('Fail on clock drift', () {
      final hlc = Hlc(1579633503119000, 0, 'abc');
      expect(() => Hlc.send(hlc, micros: 1579633403129000),
          throwsA(isA<ClockDriftException>()));
    });

    test('Fail on counter overflow', () {
      final hlc = Hlc(1579633503119000, 0xFFFF, 'abc');
      expect(() => Hlc.send(hlc, micros: 1579633403129000),
          throwsA(isA<ClockDriftException>()));
    });
  });

  group('Receive', () {
    final canonical = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abc');

    test('Higher canonical time', () {
      final remote = Hlc.parse('2020-01-21T19:05:03.110Z-0000-abcd');
      final hlc = Hlc.recv(canonical, remote, micros: 1579633503119000);
      expect(hlc, equals(canonical));
    });

    test('Same remote time', () {
      final remote = Hlc.parse('2020-01-21T19:05:03.110Z-0042-abcd');
      final hlc = Hlc.recv(canonical, remote, micros: 1579633503119000);
      expect(hlc, Hlc(remote.micros, remote.counter + 1, canonical.nodeId));
    });

    test('Higher remote time', () {
      final remote = Hlc.parse('2020-01-21T19:05:04.110Z-0000-abcd');
      final hlc = Hlc.recv(canonical, remote, micros: 1579633503119000);
      expect(hlc, Hlc(remote.micros, remote.counter + 1, canonical.nodeId));
    });

    test('Higher wall clock time', () {
      final remote = Hlc.parse('2020-01-21T19:05:04.110Z-0000-abcd');
      final hlc = Hlc.recv(canonical, remote, micros: 1579633513129000);
      expect(hlc, Hlc(1579633513129000, 0, canonical.nodeId));
    });

    test('Fail on clock drift', () {
      final remote = Hlc.parse('2020-01-21T19:05:04.110Z-0000-abcd');
      expect(() => Hlc.recv(canonical, remote, micros: 1579633403129000),
          throwsA(isA<ClockDriftException>()));
    });

    test('Fail on node id', () {
      final remote = Hlc.parse('2020-01-21T19:05:03.110Z-0000-abc');
      expect(() => Hlc.recv(canonical, remote, micros: 1579633403129000),
          throwsA(isA<DuplicateNodeException>()));
    });
  });
}
