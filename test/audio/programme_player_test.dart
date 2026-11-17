import 'dart:async';

import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/audio/chant_programme.dart';
import 'package:buddhist_gatha/audio/programme_player.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_chant_player.dart';

class _SpyPlayer extends FakeChantPlayer {
  _SpyPlayer({super.length});

  final seeks = <Duration>[];

  @override
  Future<void> seek(Duration to) {
    seeks.add(to);
    return super.seek(to);
  }
}

Duration s(int x) => Duration(seconds: x);

Recording rec(String id, Duration duration) => Recording(
  readingId: id,
  path: 'audio/$id.m4a',
  label: 'Recording $id',
  placeholder: false,
  duration: duration,
);

final a = rec('aa', s(10));
final b = rec('bb', s(20));

/// Legs of [recordings] one after another.
ChantProgramme programme(List<Recording> recordings) {
  final legs = <ChantLeg>[];
  var start = Duration.zero;
  for (final r in recordings) {
    final leg = ChantLeg(
      recording: r,
      sectionId: 'sec-${r.readingId}',
      firstBlock: legs.length,
      start: start,
    );
    legs.add(leg);
    start = leg.end;
  }
  return ChantProgramme(
    legs: legs,
    sectionCount: legs.length,
    times: const [],
    lineTimes: const [],
    paliLengths: const [],
  );
}

/// Lets every pending event and continuation run.
Future<void> settle() => Future<void>.delayed(Duration.zero);

ChantState st(ChantStatus status, Duration position, [Duration? duration]) =>
    ChantState(status: status, position: position, duration: duration);

class _Rig {
  _Rig({Set<Recording> missing = const {}, Duration? length})
    : missing = {...missing},
      inner = _SpyPlayer(length: length ?? s(10)) {
    player = ProgrammePlayer(
      inner,
      isAvailable: (r) => !this.missing.contains(r),
    );
    player.onAwait = awaited.add;
  }

  final Set<Recording> missing;
  final _SpyPlayer inner;
  late final ProgrammePlayer player;
  final awaited = <int>[];

  /// Binds A then B, plays and lets leg 1 run to its end.
  Future<void> throughLeg1() async {
    player.bind(programme([a, b]));
    await player.play();
    await settle();
    inner.advance(s(10));
    await settle();
  }
}

void main() {
  test('a one-leg programme reports the inner state unchanged', () async {
    final r = _Rig();
    r.player.bind(programme([a]));
    await r.player.play();
    await settle();
    expect(r.inner.loaded, [a]);
    expect(r.player.state, r.inner.state);
    expect(r.player.state.duration, r.inner.length);
    r.inner.advance(s(3));
    await settle();
    expect(r.player.state, st(ChantStatus.playing, s(3), s(10)));
    await r.player.seek(s(5));
    await settle();
    expect(r.inner.seeks, [s(5)]);
    expect(r.player.state, st(ChantStatus.playing, s(5), s(10)));
    await r.player.restart();
    await settle();
    expect(r.inner.seeks.last, Duration.zero);
    expect(r.inner.loaded, [a]);
    expect(r.player.state, st(ChantStatus.playing, Duration.zero, s(10)));
  });

  test('nothing is loaded on bind; the first play loads leg 0', () async {
    final r = _Rig();
    r.player.bind(programme([a, b]));
    await settle();
    expect(r.inner.loaded, isEmpty);
    expect(r.player.leg, isNull);
    expect(r.player.state, const ChantState());
    await r.player.play();
    await settle();
    expect(r.inner.loaded, [a]);
    expect(r.player.leg, 0);
    expect(r.player.state, st(ChantStatus.playing, Duration.zero, s(30)));
  });

  test('play while loading is ignored', () async {
    final r = _Rig();
    r.inner.gate = Completer<void>();
    r.player.bind(programme([a, b]));
    unawaited(r.player.play());
    await settle();
    expect(r.player.state.status, ChantStatus.loading);
    unawaited(r.player.play());
    await settle();
    expect(r.inner.loaded, [a]);
    r.inner.gate!.complete();
    await settle();
    expect(r.inner.loaded, [a]);
    expect(r.player.state, st(ChantStatus.playing, Duration.zero, s(30)));
  });

  test('leg 1 completing loads and plays leg 2 when available', () async {
    final r = _Rig();
    r.player.bind(programme([a, b]));
    await r.player.play();
    await settle();
    r.inner.advance(s(4));
    await settle();
    expect(r.player.state, st(ChantStatus.playing, s(4), s(30)));
    r.inner.advance(s(6));
    await settle();
    expect(r.inner.loaded, [a, b]);
    expect(r.player.leg, 1);
    expect(r.player.state, st(ChantStatus.playing, s(10), s(30)));
    r.inner.advance(s(2));
    await settle();
    expect(r.player.state, st(ChantStatus.playing, s(12), s(30)));
  });

  test('a position past the listed length is clamped', () async {
    final short = rec('cc', s(8));
    final r = _Rig();
    r.player.bind(programme([short, b]));
    await r.player.play();
    await settle();
    r.inner.advance(s(9));
    await settle();
    expect(r.player.state, st(ChantStatus.playing, s(8), s(28)));
  });

  test(
    'with leg 2 unavailable the chant waits paused at its start and asks once',
    () async {
      final r = _Rig(missing: {b});
      await r.throughLeg1();
      expect(r.player.state, st(ChantStatus.paused, s(10), s(30)));
      expect(r.player.awaiting, (leg: 1, at: Duration.zero));
      expect(r.awaited, [1]);
      expect(r.player.armed, isTrue);
      expect(r.inner.loaded, [a]);
    },
  );

  test('pause while waiting disarms, play arms again', () async {
    final r = _Rig(missing: {b});
    await r.throughLeg1();
    await r.player.pause();
    await settle();
    expect(r.player.armed, isFalse);
    expect(r.player.state, st(ChantStatus.paused, s(10), s(30)));
    await r.player.play();
    await settle();
    expect(r.player.armed, isTrue);
    expect(r.awaited, [1, 1]);
    expect(r.player.state, st(ChantStatus.paused, s(10), s(30)));
    expect(r.inner.loaded, [a]);
  });

  test('arrived loads the awaited leg and plays when armed', () async {
    final r = _Rig(missing: {b});
    await r.throughLeg1();
    await r.player.arrived();
    await settle();
    expect(r.inner.loaded, [a], reason: 'still unavailable');
    r.missing.clear();
    await r.player.arrived();
    await settle();
    expect(r.inner.loaded, [a, b]);
    expect(r.player.awaiting, isNull);
    expect(r.player.leg, 1);
    expect(r.player.state, st(ChantStatus.playing, s(10), s(30)));

    final d = _Rig(missing: {b});
    await d.throughLeg1();
    await d.player.pause();
    d.missing.clear();
    await d.player.arrived();
    await settle();
    expect(d.inner.loaded, [a, b]);
    expect(d.player.state, st(ChantStatus.paused, s(10), s(30)));
  });

  test('restart while waiting goes back to leg 0', () async {
    final r = _Rig(missing: {b});
    await r.throughLeg1();
    await r.player.restart();
    await settle();
    expect(r.player.awaiting, isNull);
    expect(r.player.leg, 0);
    expect(r.player.state, st(ChantStatus.playing, Duration.zero, s(30)));
  });

  test('seek into another leg loads it and keeps playing or paused', () async {
    final r = _Rig();
    r.player.bind(programme([a, b]));
    await r.player.play();
    await settle();
    await r.player.seek(s(15));
    await settle();
    expect(r.inner.loaded, [a, b]);
    expect(r.inner.seeks.last, s(5));
    expect(r.player.leg, 1);
    expect(r.player.state, st(ChantStatus.playing, s(15), s(30)));

    final p = _Rig();
    p.player.bind(programme([a, b]));
    await p.player.play();
    await settle();
    await p.player.pause();
    await settle();
    await p.player.seek(s(15));
    await settle();
    expect(p.inner.loaded, [a, b]);
    expect(p.player.state, st(ChantStatus.paused, s(15), s(30)));
    await p.player.seek(s(12));
    await settle();
    expect(p.inner.loaded, [a, b], reason: 'same leg: no load');
    expect(p.player.state, st(ChantStatus.paused, s(12), s(30)));
  });

  test('seek into an unavailable leg waits at the chosen point', () async {
    final r = _Rig(missing: {b});
    r.player.bind(programme([a, b]));
    await r.player.play();
    await settle();
    await r.player.seek(s(17));
    await settle();
    expect(r.player.awaiting, (leg: 1, at: s(7)));
    expect(r.player.armed, isTrue);
    expect(r.awaited, [1]);
    expect(r.player.state, st(ChantStatus.paused, s(17), s(30)));
    expect(r.inner.state.status, ChantStatus.paused);
  });

  test('speed set while waiting reaches the next leg', () async {
    final r = _Rig(missing: {b});
    await r.throughLeg1();
    await r.player.setSpeed(1.25);
    r.missing.clear();
    await r.player.arrived();
    await settle();
    expect(r.inner.loaded, [a, b]);
    expect(r.inner.speeds.last, 1.25);
    expect(r.inner.speed, 1.25);
  });

  test(
    'a failed load of a later leg is reported as failed and play retries it',
    () async {
      final r = _Rig();
      r.player.bind(programme([a, b]));
      await r.player.play();
      await settle();
      r.inner.failOnLoad = true;
      r.inner.advance(s(10));
      await settle();
      expect(r.inner.loaded, [a, b]);
      expect(r.player.state, st(ChantStatus.failed, s(10), s(30)));
      r.inner.failOnLoad = false;
      await r.player.play();
      await settle();
      expect(r.inner.loaded, [a, b, b]);
      expect(r.player.state, st(ChantStatus.playing, s(10), s(30)));
    },
  );

  test('completed at the end of the last leg', () async {
    final r = _Rig();
    r.player.bind(programme([a, b]));
    await r.player.play();
    await settle();
    r.inner.advance(s(10));
    await settle();
    r.inner.advance(s(10));
    await settle();
    expect(r.player.state, st(ChantStatus.completed, s(30), s(30)));
    await r.player.play();
    await settle();
    expect(r.inner.loaded, [a, b, a], reason: 'play after the end: leg 0');
    expect(r.player.state, st(ChantStatus.playing, Duration.zero, s(30)));
  });

  test('states from before this player loaded anything are ignored', () async {
    final r = _Rig();
    await r.inner.load(a);
    await r.inner.play();
    await settle();
    expect(r.inner.state.status, ChantStatus.playing);
    r.player.bind(programme([a, b]));
    r.inner.advance(s(2));
    await settle();
    expect(r.player.state, const ChantState());
  });
}
