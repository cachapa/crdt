import 'package:crdt/src/hlc.dart';
import 'package:test/test.dart';

const _millis = 1000000000000;
const _isoTime = '2001-09-09T01:46:40.000Z';
const _logicalTime = 65536000000000066;

void main() {
  group('Constructors', () {
    final hlc = Hlc(_millis, 0x42, 'abc');

    test('default', () {
      expect(hlc.millis, _millis);
      expect(hlc.counter, 0x42);
      expect(hlc.nodeId, 'abc');
    });

    test('default with microseconds', () {
      expect(Hlc(_millis * 1000, 0x42, 'abc'), hlc);
    });

    test('zero', () {
      expect(Hlc.zero('abc'), hlc.apply(millis: 0, counter: 0));
    });

    test('from date', () {
      expect(
          Hlc.fromDate(DateTime.parse(_isoTime), 'abc'), hlc.apply(counter: 0));
    });

    test('logical time', () {
      expect(Hlc.fromLogicalTime(_logicalTime, 'abc'), hlc);
    });

    test('parse', () {
      expect(Hlc<String>.parse('$_isoTime-0042-abc'), hlc);
    });
  });

  group('String operations', () {
    test('hlc to string', () {
      final hlc = Hlc.parse('$_isoTime-0042-abc');
      expect(hlc.toString(), '$_isoTime-0042-abc');
    });

    test('Parse hlc', () {
      expect(
          Hlc<String>.parse('$_isoTime-0042-abc'), Hlc(_millis, 0x42, 'abc'));
    });
  });

  group('Non-String node id', () {
    test('to hlc', () {
      final hlc = Hlc<int>.parse('$_isoTime-0042-1', int.parse);
      expect(hlc, Hlc(_millis, 0x42, 1));
    });

    test('to string', () {
      final hlc = Hlc(_millis, 0x42, 1);
      expect(hlc.toString(), '$_isoTime-0042-1');
    });
  });

  group('Comparison', () {
    test('Equality', () {
      final hlc1 = Hlc.parse('$_isoTime-0042-abc');
      final hlc2 = Hlc.parse('$_isoTime-0042-abc');
      expect(hlc1, hlc2);
      expect(hlc1 <= hlc2, isTrue);
      expect(hlc1 >= hlc2, isTrue);
    });

    test('Different node ids', () {
      final hlc1 = Hlc.parse('$_isoTime-0042-abc');
      final hlc2 = Hlc.parse('$_isoTime-0042-abcd');
      expect(hlc1, isNot(hlc2));
    });

    test('Less than millis', () {
      final hlc1 = Hlc(_millis, 0x42, 'abc');
      final hlc2 = Hlc(_millis + 1, 0, 'abc');
      expect(hlc1 < hlc2, isTrue);
      expect(hlc1 <= hlc2, isTrue);
    });

    test('Less than counter', () {
      final hlc1 = Hlc.parse('$_isoTime-0042-abc');
      final hlc2 = Hlc.parse('$_isoTime-0043-abc');
      expect(hlc1 < hlc2, isTrue);
      expect(hlc1 <= hlc2, isTrue);
    });

    test('Less than node id', () {
      final hlc1 = Hlc.parse('$_isoTime-0042-abc');
      final hlc2 = Hlc.parse('$_isoTime-0042-abb');
      expect(hlc1 > hlc2, isTrue);
      expect(hlc1 >= hlc2, isTrue);
    });

    test('Fail less than if equals', () {
      final hlc1 = Hlc.parse('$_isoTime-0042-abc');
      final hlc2 = Hlc.parse('$_isoTime-0042-abc');
      expect(hlc1 < hlc2, isFalse);
    });

    test('Fail less than if millis and counter disagree', () {
      final hlc1 = Hlc(_millis + 1, 0, 'abc');
      final hlc2 = Hlc(_millis, 0x42, 'abc');
      expect(hlc1 < hlc2, isFalse);
    });

    test('More than millis', () {
      final hlc1 = Hlc(_millis + 1, 0x42, 'abc');
      final hlc2 = Hlc(_millis, 0, 'abc');
      expect(hlc1 > hlc2, isTrue);
      expect(hlc1 >= hlc2, isTrue);
    });

    test('More than counter', () {
      final hlc1 = Hlc(_millis + 1, 0x42, 'abc');
      final hlc2 = Hlc(_millis, 0, 'abc');
      expect(hlc1 > hlc2, isTrue);
      expect(hlc1 >= hlc2, isTrue);
    });

    test('More than node id', () {
      final hlc1 = Hlc(_millis, 0x42, 'abc');
      final hlc2 = Hlc(_millis, 0x42, 'abb');
      expect(hlc1 > hlc2, isTrue);
      expect(hlc1 >= hlc2, isTrue);
    });

    test('Compare', () {
      final hlc = Hlc(_millis, 0x42, 'abc');
      expect(hlc.compareTo(Hlc(_millis, 0x42, 'abc')), 0);

      expect(hlc.compareTo(Hlc(_millis + 1, 0x42, 'abc')), -1);
      expect(hlc.compareTo(Hlc(_millis, 0x43, 'abc')), -1);
      expect(hlc.compareTo(Hlc(_millis, 0x42, 'abd')), -1);

      expect(hlc.compareTo(Hlc(_millis - 1, 0x42, 'abc')), 1);
      expect(hlc.compareTo(Hlc(_millis, 0x41, 'abc')), 1);
      expect(hlc.compareTo(Hlc(_millis, 0x42, 'abb')), 1);
    });
  });

  group('Logical time representation', () {
    test('Logical time stability', () {
      final hlc = Hlc.fromLogicalTime(_logicalTime, 'abc');
      expect(hlc.logicalTime, _logicalTime);
    });

    test('Hlc as logical time', () {
      final hlc = Hlc.parse('$_isoTime-0042-abc');
      expect(hlc.logicalTime, _logicalTime);
    });

    test('Hlc from logical time', () {
      final hlc = Hlc.parse('$_isoTime-0042-abc');
      expect(Hlc.fromLogicalTime(_logicalTime, 'abc'), hlc);
    });
  });

  group('Send', () {
    test('Higher canonical time', () {
      final hlc = Hlc(_millis + 1, 0x42, 'abc');
      final sendHlc = Hlc.send(hlc, millis: _millis);
      expect(sendHlc, isNot(hlc));
      expect(sendHlc.millis, hlc.millis);
      expect(sendHlc.counter, 0x43);
      expect(sendHlc.nodeId, hlc.nodeId);
    });

    test('Equal canonical time', () {
      final hlc = Hlc(_millis, 0x42, 'abc');
      final sendHlc = Hlc.send(hlc, millis: _millis);
      expect(sendHlc, isNot(hlc));
      expect(sendHlc.millis, _millis);
      expect(sendHlc.counter, 0x43);
      expect(sendHlc.nodeId, hlc.nodeId);
    });

    test('Lower canonical time', () {
      final hlc = Hlc(_millis - 1, 0x42, 'abc');
      final sendHlc = Hlc.send(hlc, millis: _millis);
      expect(sendHlc, isNot(hlc));
      expect(sendHlc.millis, _millis);
      expect(sendHlc.counter, 0);
      expect(sendHlc.nodeId, hlc.nodeId);
    });

    test('Fail on clock drift', () {
      final hlc = Hlc(_millis + 60001, 0, 'abc');
      expect(() => Hlc.send(hlc, millis: _millis),
          throwsA(isA<ClockDriftException>()));
    });

    test('Fail on counter overflow', () {
      final hlc = Hlc(_millis, 0xFFFF, 'abc');
      expect(() => Hlc.send(hlc, millis: _millis),
          throwsA(isA<OverflowException>()));
    });
  });

  group('Receive', () {
    final canonical = Hlc.parse('$_isoTime-0042-abc');

    test('Higher canonical time', () {
      final remote = Hlc(_millis - 1, 0x42, 'abcd');
      final hlc = Hlc.recv(canonical, remote, millis: _millis);
      expect(hlc, equals(canonical));
    });

    test('Same remote time', () {
      final remote = Hlc(_millis, 0x42, 'abcd');
      final hlc = Hlc.recv(canonical, remote, millis: _millis);
      expect(hlc, Hlc(remote.millis, remote.counter, canonical.nodeId));
    });

    test('Higher remote time', () {
      final remote = Hlc(_millis + 1, 0x42, 'abcd');
      final hlc = Hlc.recv(canonical, remote, millis: _millis);
      expect(hlc, Hlc(remote.millis, remote.counter, canonical.nodeId));
    });

    test('Higher wall clock time', () {
      final remote = Hlc.parse('$_isoTime-0000-abcd');
      final hlc = Hlc.recv(canonical, remote, millis: _millis + 1);
      expect(hlc, canonical);
    });

    test('Fail on node id', () {
      final remote = Hlc.parse('$_isoTime-0000-abc');
      expect(() => Hlc.recv(canonical, remote, millis: _millis),
          throwsA(isA<DuplicateNodeException>()));
    });

    test('Fail on clock drift', () {
      final remote = Hlc(_millis + 60001, 0x42, 'abcd');
      expect(() => Hlc.recv(canonical, remote, millis: _millis),
          throwsA(isA<ClockDriftException>()));
    });
  });
}
