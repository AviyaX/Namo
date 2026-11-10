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
