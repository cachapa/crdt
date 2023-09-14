import 'package:crdt/src/hlc.dart';
import 'package:test/test.dart';

const _isoTime = '2001-09-09T01:46:40.000Z';
final _dateTime = DateTime.parse(_isoTime);

void main() {
  group('Constructors', () {
    final hlc = Hlc(_dateTime, 0x42, 'abc');

    test('default', () {
      expect(hlc.dateTime, _dateTime);
      expect(hlc.counter, 0x42);
      expect(hlc.nodeId, 'abc');
    });

    test('default with microseconds', () {
      expect(Hlc(DateTime.parse('2001-09-09T01:46:40.000Z'), 0x42, 'abc'), hlc);
    });

    test('zero', () {
      final zero = Hlc.zero('abc');
      expect(
          zero,
          hlc.apply(
              dateTime: DateTime.fromMillisecondsSinceEpoch(0), counter: 0));
      expect(zero.toString(), '1970-01-01T00:00:00.000Z-0000-abc');
    });

    test('from date', () {
      expect(
          Hlc.fromDate(DateTime.parse(_isoTime), 'abc'), hlc.apply(counter: 0));
    });

    test('parse', () {
      expect(Hlc.parse('$_isoTime-0042-abc'), hlc);
    });
  });

  group('String operations', () {
    test('hlc to string', () {
      final hlc = Hlc.parse('$_isoTime-0042-abc');
      expect(hlc.toString(), '$_isoTime-0042-abc');
    });

    test('Parse hlc', () {
      expect(Hlc.parse('$_isoTime-0042-abc'), Hlc(_dateTime, 0x42, 'abc'));
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
      final hlc1 = Hlc(_dateTime, 0x42, 'abc');
      final hlc2 = Hlc(_dateTime.increment(), 0, 'abc');
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
      final hlc1 = Hlc(_dateTime.increment(), 0, 'abc');
      final hlc2 = Hlc(_dateTime, 0x42, 'abc');
      expect(hlc1 < hlc2, isFalse);
    });

    test('More than millis', () {
      final hlc1 = Hlc(_dateTime.increment(), 0x42, 'abc');
      final hlc2 = Hlc(_dateTime, 0, 'abc');
      expect(hlc1 > hlc2, isTrue);
      expect(hlc1 >= hlc2, isTrue);
    });

    test('More than counter', () {
      final hlc1 = Hlc(_dateTime.increment(), 0x42, 'abc');
      final hlc2 = Hlc(_dateTime, 0, 'abc');
      expect(hlc1 > hlc2, isTrue);
      expect(hlc1 >= hlc2, isTrue);
    });

    test('More than node id', () {
      final hlc1 = Hlc(_dateTime, 0x42, 'abc');
      final hlc2 = Hlc(_dateTime, 0x42, 'abb');
      expect(hlc1 > hlc2, isTrue);
      expect(hlc1 >= hlc2, isTrue);
    });

    test('Compare', () {
      final hlc = Hlc(_dateTime, 0x42, 'abc');
      expect(hlc.compareTo(Hlc(_dateTime, 0x42, 'abc')), 0);

      expect(hlc.compareTo(Hlc(_dateTime.increment(), 0x42, 'abc')), -1);
      expect(hlc.compareTo(Hlc(_dateTime, 0x43, 'abc')), -1);
      expect(hlc.compareTo(Hlc(_dateTime, 0x42, 'abd')), -1);

      expect(hlc.compareTo(Hlc(_dateTime.decrement(), 0x42, 'abc')), 1);
      expect(hlc.compareTo(Hlc(_dateTime, 0x41, 'abc')), 1);
      expect(hlc.compareTo(Hlc(_dateTime, 0x42, 'abb')), 1);
    });
  });

  group('Send', () {
    test('Higher canonical time', () {
      final hlc = Hlc(_dateTime.increment(), 0x42, 'abc');
      final sendHlc = hlc.increment(wallTime: _dateTime);
      expect(sendHlc, isNot(hlc));
      expect(sendHlc.dateTime, hlc.dateTime);
      expect(sendHlc.counter, 0x43);
      expect(sendHlc.nodeId, hlc.nodeId);
    });

    test('Equal canonical time', () {
      final hlc = Hlc(_dateTime, 0x42, 'abc');
      final sendHlc = hlc.increment(wallTime: _dateTime);
      expect(sendHlc, isNot(hlc));
      expect(sendHlc.dateTime, _dateTime);
      expect(sendHlc.counter, 0x43);
      expect(sendHlc.nodeId, hlc.nodeId);
    });

    test('Lower canonical time', () {
      final hlc = Hlc(_dateTime.decrement(), 0x42, 'abc');
      final sendHlc = hlc.increment(wallTime: _dateTime);
      expect(sendHlc, isNot(hlc));
      expect(sendHlc.dateTime, _dateTime);
      expect(sendHlc.counter, 0);
      expect(sendHlc.nodeId, hlc.nodeId);
    });

    test('Fail on clock drift', () {
      final hlc = Hlc(_dateTime.increment(60001), 0, 'abc');
      expect(() => hlc.increment(wallTime: _dateTime),
          throwsA(isA<ClockDriftException>()));
    });

    test('Fail on counter overflow', () {
      final hlc = Hlc(_dateTime, 0xFFFF, 'abc');
      expect(() => hlc.increment(wallTime: _dateTime),
          throwsA(isA<OverflowException>()));
    });
  });

  group('Receive', () {
    final canonical = Hlc.parse('$_isoTime-0042-abc');

    test('Higher canonical time', () {
      final remote = Hlc(_dateTime.decrement(), 0x42, 'abcd');
      final hlc = canonical.merge(remote, wallTime: _dateTime);
      expect(hlc, equals(canonical));
    });

    test('Same remote time', () {
      final remote = Hlc(_dateTime, 0x42, 'abcd');
      final hlc = canonical.merge(remote, wallTime: _dateTime);
      expect(hlc, Hlc(remote.dateTime, remote.counter, canonical.nodeId));
    });

    test('Higher remote time', () {
      final remote = Hlc(_dateTime.increment(), 0, 'abcd');
      final hlc = canonical.merge(remote, wallTime: _dateTime);
      expect(hlc, Hlc(remote.dateTime, remote.counter, canonical.nodeId));
    });

    test('Higher wall clock time', () {
      final remote = Hlc.parse('$_isoTime-0000-abcd');
      final hlc = canonical.merge(remote, wallTime: _dateTime.increment());
      expect(hlc, canonical);
    });

    test('Skip node id check if time is lower', () {
      final remote = Hlc(_dateTime.decrement(), 0x42, 'abc');
      expect(canonical.merge(remote, wallTime: _dateTime), canonical);
    });

    test('Skip node id check if time is same', () {
      final remote = Hlc(_dateTime, 0x42, 'abc');
      expect(canonical.merge(remote, wallTime: _dateTime), canonical);
    });

    test('Fail on node id', () {
      final remote = Hlc(_dateTime.increment(), 0, 'abc');
      expect(() => canonical.merge(remote, wallTime: _dateTime),
          throwsA(isA<DuplicateNodeException>()));
    });

    test('Fail on clock drift', () {
      final remote = Hlc(_dateTime.increment(60001), 0x42, 'abcd');
      expect(() => canonical.merge(remote, wallTime: _dateTime),
          throwsA(isA<ClockDriftException>()));
    });
  });
}

extension on DateTime {
  DateTime increment([int? millis]) => add(Duration(milliseconds: millis ?? 1));

  DateTime decrement() => subtract(Duration(milliseconds: 1));
}
