import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/audio/chant_timing.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/reader/chant_follow.dart';
import 'package:flutter_test/flutter_test.dart';

Duration _s(num s) => Duration(milliseconds: (s * 1000).round());

ChantState _at(ChantStatus status, num seconds) =>
    ChantState(status: status, position: _s(seconds), duration: _s(10));

ChantFollow _follow() => ChantFollow(
  times: [BlockTime(_s(0), _s(2)), null, BlockTime(_s(3), _s(5))],
  paliLengths: const [
    [5, 5],
    [3],
    [4, 4],
  ],
);

void main() {
  test('nothing is started, shown or paused at first', () {
    final f = _follow();
    expect(f.started, isFalse);
    expect(f.following, isTrue);
    expect(f.place.value, isNull);
  });

  test('the first playing state starts it and shows the place', () {
    final f = _follow();
    var notified = 0;
    f.addListener(() => notified++);
    f.onState(_at(ChantStatus.playing, 0.5));
    expect(f.started, isTrue);
    expect(f.place.value, const ChantPlace(0, 0));
    f.onState(_at(ChantStatus.playing, 1.5));
    expect(f.place.value, const ChantPlace(0, 1));
    expect(notified, 1, reason: 'started once; the place has its own listenable');
  });

  test('loading, ready and failed show nothing and do not start', () {
    final f = _follow();
    for (final s in [
      ChantStatus.idle,
      ChantStatus.loading,
      ChantStatus.ready,
      ChantStatus.failed,
    ]) {
      f.onState(_at(s, 0.5));
      expect(f.started, isFalse, reason: '$s');
      expect(f.place.value, isNull, reason: '$s');
    }
  });

  test('paused keeps the place', () {
    final f = _follow();
    f.onState(_at(ChantStatus.playing, 3.5));
    f.onState(_at(ChantStatus.paused, 3.5));
    expect(f.place.value, const ChantPlace(2, 0));
    expect(f.started, isTrue);
  });

  test('completed clears the place but stays started', () {
    final f = _follow();
    f.onState(_at(ChantStatus.playing, 4.5));
    expect(f.place.value, isNotNull);
    f.onState(_at(ChantStatus.completed, 10));
    expect(f.place.value, isNull);
    expect(f.started, isTrue);
  });

  test('loading and idle after started clear the place', () {
    final f = _follow();
    f.onState(_at(ChantStatus.playing, 1));
    f.onState(const ChantState(status: ChantStatus.loading));
    expect(f.place.value, isNull);
    f.onState(_at(ChantStatus.playing, 1));
    f.onState(const ChantState());
    expect(f.place.value, isNull);
  });

  test('an untimed block is never the place', () {
    final f = _follow();
    f.onState(_at(ChantStatus.playing, 2.5));
    expect(f.place.value, const ChantPlace(0, 1));
  });

  test('following starts true; a hand stops it; only resume restores it', () {
    final f = _follow();
    f.onState(_at(ChantStatus.playing, 0.5));
    var notified = 0;
    f.addListener(() => notified++);
    f.pausedByHand();
    expect(f.following, isFalse);
    expect(notified, 1);
    f.pausedByHand();
    expect(notified, 1, reason: 'already paused');
    f.onState(_at(ChantStatus.playing, 1.5));
    f.onState(_at(ChantStatus.paused, 1.5));
    f.onState(_at(ChantStatus.playing, 3.5));
    expect(f.following, isFalse, reason: 'never by itself');
    f.resume();
    expect(f.following, isTrue);
    expect(notified, 2);
    f.resume();
    expect(notified, 2);
  });

  test('pausedByHand before started changes nothing', () {
    final f = _follow();
    var notified = 0;
    f.addListener(() => notified++);
    f.pausedByHand();
    expect(f.following, isTrue);
    expect(notified, 0);
    f.onState(_at(ChantStatus.playing, 0.5));
    expect(f.following, isTrue);
  });

  test('reset clears started, the place and a paused following', () {
    final f = _follow();
    f.onState(_at(ChantStatus.playing, 0.5));
    f.pausedByHand();
    f.reset();
    expect(f.started, isFalse);
    expect(f.following, isTrue);
    expect(f.place.value, isNull);
    f.onState(_at(ChantStatus.paused, 0.5));
    expect(f.place.value, isNull, reason: 'not started again yet');
  });

  group('line times', () {
    ChantFollow withLines() => ChantFollow(
      times: [BlockTime(_s(0), _s(10)), null],
      paliLengths: const [
        [1, 1, 1],
        [1],
      ],
      lineTimes: [
        [_s(2), null, _s(6)],
        [_s(12)],
      ],
    );

    test('onState places by line times', () {
      final f = withLines();
      f.onState(_at(ChantStatus.playing, 1));
      expect(f.place.value, const ChantPlace(0, -1));
      f.onState(_at(ChantStatus.playing, 4));
      expect(f.place.value, const ChantPlace(0, 0));
      f.onState(_at(ChantStatus.playing, 7));
      expect(f.place.value, const ChantPlace(0, 2));
    });

    test('lineStart: timed line, null line, bad index', () {
      final f = withLines();
      expect(f.lineStart(0, 2), _s(6));
      expect(f.lineStart(0, 1), _s(0), reason: 'null line: block start');
      expect(f.lineStart(0, 9), _s(0));
      expect(f.lineStart(0, -1), _s(0));
      expect(f.lineStart(1, 0), _s(12), reason: 'its own time wins');
      expect(f.lineStart(1, 3), isNull, reason: 'untimed block, bad line');
      expect(f.lineStart(5, 0), isNull);
      expect(_follow().lineStart(0, 1), _s(0), reason: 'no line times');
    });
  });
}
