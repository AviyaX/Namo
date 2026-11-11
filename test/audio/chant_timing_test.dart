import 'package:buddhist_gatha/audio/chant_timing.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

Duration s(num x) => Duration(microseconds: (x * 1000000).round());
BlockTime bt(num a, num b) => BlockTime(s(a), s(b));

void main() {
  group('placeAt', () {
    final lengths = [
      [10, 30],
      [5],
    ];

    test('before the first block, and the phrase within a block', () {
      final times = [bt(1, 10), bt(10, 20)];
      expect(placeAt(s(0.5), times, lengths), isNull);
      // block 0 spans 1..10 s (9 s); 10 of 40 units at 2.25 s into it
      expect(placeAt(s(3.2), times, lengths), const ChantPlace(0, 0));
      expect(placeAt(s(3.4), times, lengths), const ChantPlace(0, 1));
      expect(placeAt(s(10), times, lengths), const ChantPlace(1, 0));
      expect(placeAt(s(25), times, lengths), const ChantPlace(1, 0));
    });

    test('boundary at 2.4 s and 2.6 s with 0-10 s', () {
      final times = [bt(0, 10), bt(10, 20)];
      expect(placeAt(s(2.4), times, lengths), const ChantPlace(0, 0));
      expect(placeAt(s(2.6), times, lengths), const ChantPlace(0, 1));
    });

    test('a gap stays on the last phrase of the earlier block', () {
      final times = [bt(0, 5), bt(8, 10)];
      expect(placeAt(s(6), times, lengths), const ChantPlace(0, 1));
    });

    test('an overlap goes to the later block', () {
      final times = [bt(0, 5.2), bt(5.0, 9)];
      expect(placeAt(s(5.1), times, lengths), const ChantPlace(1, 0));
    });

    test('an empty block gives phrase 0; end <= start counts as done', () {
      expect(placeAt(s(1), [bt(0, 5)], [<int>[]]), const ChantPlace(0, 0));
      expect(
        placeAt(s(1), [bt(0, 0)], [
          [4, 4],
        ]),
        const ChantPlace(0, 1),
      );
    });

    test('an untimed block is never returned', () {
      for (final times in [
        [bt(0, 5), null, bt(6, 9)],
        [bt(0, 5), bt(5, 9), null],
      ]) {
        final ls = [
          [3, 3],
          [3, 3],
          [3, 3],
        ];
        final last = times.whereType<BlockTime>().last.end;
        for (var ms = 0; ms <= last.inMilliseconds * 2; ms += 250) {
          final p = placeAt(Duration(milliseconds: ms), times, ls);
          if (p != null) expect(times[p.block], isNotNull, reason: '$ms');
        }
      }
    });
  });

  group('placeAt without line times is unchanged', () {
    final lengths = [
      [10, 30],
      [5],
    ];
    final times = [bt(1, 10), bt(10, 20)];
    for (final extra in [null, const <List<Duration?>>[]]) {
      test('lineTimes ${extra == null ? 'left out' : 'const []'}', () {
        ChantPlace? at(num x) => extra == null
            ? placeAt(s(x), times, lengths)
            : placeAt(s(x), times, lengths, lineTimes: extra);
        expect(at(0.5), isNull);
        expect(at(3.2), const ChantPlace(0, 0));
        expect(at(3.4), const ChantPlace(0, 1));
        expect(at(10), const ChantPlace(1, 0));
      });
    }
  });

  group('placeAt with line times', () {
    final times = [bt(0, 10), bt(10, 20), bt(20, 30)];
    final lengths = [
      [1, 1, 1],
      [1, 1],
      [1, 1],
    ];
    final lineTimes = <List<Duration?>>[
      [s(2), s(4), s(6)],
      [s(11), null],
      [null, null],
    ];
    ChantPlace? at(num x) => placeAt(s(x), times, lengths, lineTimes: lineTimes);

    test('before the first line of a block is -1', () {
      expect(at(0), const ChantPlace(0, -1));
      expect(at(1.9), const ChantPlace(0, -1));
      expect(at(10.5), const ChantPlace(1, -1));
    });

    test('at a line start and after it', () {
      expect(at(2), const ChantPlace(0, 0));
      expect(at(5.9), const ChantPlace(0, 1));
      expect(at(6), const ChantPlace(0, 2));
      expect(at(9.9), const ChantPlace(0, 2));
    });

    test('a null line is skipped and the earlier timed line stays', () {
      expect(at(11), const ChantPlace(1, 0));
      expect(at(19), const ChantPlace(1, 0));
    });

    test('an all-null block is -1 throughout', () {
      for (final x in [20, 22, 25, 29.9, 40]) {
        expect(at(x), const ChantPlace(2, -1), reason: '$x');
      }
    });

    test('a block without an entry uses the length estimate', () {
      final p = placeAt(
        s(25),
        times,
        lengths,
        lineTimes: [
          [s(2)],
        ],
      );
      expect(p, const ChantPlace(2, 0));
    });
  });

  group('real Samantha Pattana line times', () {
    testWidgets('stepping through the recording', (t) async {
      final lib = await realLibrary(t);
      final r = lib.reading(spVandanaId)!;
      final audio = r.audio!;
      final times = audio.blockTimes;
      final lengths = paliLengthsOf(r);
      final lineTimes = audio.lineTimes;
      final reached = <int, Set<int>>{};
      var lastBlock = -1, lastPhrase = -2;
      final versesStart = times[1]!.start;
      for (
        var ms = 0;
        ms <= audio.duration!.inMilliseconds + 5000;
        ms += 500
      ) {
        final pos = Duration(milliseconds: ms);
        final p = placeAt(pos, times, lengths, lineTimes: lineTimes);
        if (p == null) continue;
        if (pos < versesStart) {
          expect(p, const ChantPlace(0, -1), reason: '$ms');
        }
        expect(p.block, greaterThanOrEqualTo(lastBlock), reason: '$ms');
        if (p.block == lastBlock) {
          expect(p.phrase, greaterThanOrEqualTo(lastPhrase), reason: '$ms');
        }
        lastBlock = p.block;
        lastPhrase = p.phrase;
        (reached[p.block] ??= {}).add(p.phrase);
      }
      for (final (b, lines) in lineTimes.indexed) {
        for (final (i, at) in lines.indexed) {
          if (at == null) continue;
          // A line closer than the step to the next can be passed over.
          final next = i + 1 < lines.length ? lines[i + 1] : null;
          if (next != null && next - at < const Duration(milliseconds: 500)) {
            continue;
          }
          expect(reached[b], contains(i), reason: 'block $b line $i');
        }
      }
    });
  });

  test('blockStart', () {
    final times = [bt(1, 2), null];
    expect(blockStart(times, 0), s(1));
    expect(blockStart(times, 1), isNull);
  });

  group('real recordings', () {
    for (final id in ['pirith-12-mettanisamsa', 'pirith-25-alavaka-suttam']) {
      testWidgets('walk through $id', (t) async {
        final lib = await realLibrary(t);
        final r = lib
            .category(pirithCategoryId)!
            .readings
            .firstWhere((r) => r.id == id);
        final times = r.audio!.blockTimes;
        final lengths = paliLengthsOf(r);
        expect(lengths.length, r.sections.first.verses.length);
        expect(
          lengths.first.first,
          r.sections.first.verses.first.phrases.first.pali.length,
        );
        var lastBlock = -1, lastPhrase = -1;
        for (
          var ms = 0;
          ms <= r.audio!.duration!.inMilliseconds;
          ms += 200
        ) {
          final p = placeAt(Duration(milliseconds: ms), times, lengths);
          if (p == null) continue;
          expect(p.block, inInclusiveRange(0, lengths.length - 1));
          expect(p.phrase, inInclusiveRange(0, lengths[p.block].length - 1));
          expect(times[p.block], isNotNull);
          expect(p.block, greaterThanOrEqualTo(lastBlock), reason: '$ms');
          if (p.block == lastBlock) {
            expect(p.phrase, greaterThanOrEqualTo(lastPhrase), reason: '$ms');
          }
          lastBlock = p.block;
          lastPhrase = p.phrase;
        }
        if (id.contains('alavaka')) {
          expect(times.last, isNull);
          expect(lastBlock, lessThan(lengths.length - 1));
        }
      });
    }
  });
}
