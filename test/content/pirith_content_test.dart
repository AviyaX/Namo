import 'dart:convert';
import 'dart:io';

import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

void main() {
  testWidgets('the bundled pirith content', (t) async {
    final lib = await realLibrary(t);
    expect(lib.categories.map((c) => c.id), [realCategoryId, pirithCategoryId]);
    final pirith = lib.category(pirithCategoryId)!;
    expect(pirith.readings.length, 39);
    final verses = [
      for (final r in pirith.readings)
        for (final s in r.sections) ...s.verses,
    ];
    expect(verses.length, 1157);
    expect(verses.fold<int>(0, (n, v) => n + v.phrases.length), 5692);

    final nulls = <String>[];
    for (final r in pirith.readings) {
      expect(r.isPhrased, isTrue, reason: r.id);
      expect(r.sections.length, 1, reason: r.id);
      expect(r.sections.single.id, 'p', reason: r.id);
      expect(r.sections.single.number, 1, reason: r.id);
      expect(r.titleRoman, isNotNull, reason: r.id);
      expect(r.titleRoman!.trim(), isNotEmpty, reason: r.id);
      expect(r.audio, isNotNull, reason: r.id);
      expect(
        r.audio!.blockTimes.length,
        r.sections.single.verses.length,
        reason: r.id,
      );
      for (final (j, b) in r.audio!.blockTimes.indexed) {
        if (b == null) nulls.add('${r.id}#$j');
      }
    }
    final alavaka = pirith.readings.firstWhere(
      (r) => r.id == 'pirith-25-alavaka-suttam',
    );
    expect(nulls, [
      'pirith-25-alavaka-suttam#${alavaka.audio!.blockTimes.length - 1}',
    ]);

    final src =
        jsonDecode(
              File('content/extracted/pitaka_lk_pirith.json')
                  .readAsStringSync(),
            )
            as Map<String, dynamic>;
    final byId = {
      for (final it in src['items'] as List) 'pirith-${(it as Map)['id']}': it,
    };
    // The order of readings may change; the number is the position.
    for (final (i, r) in pirith.readings.indexed) {
      expect(pirith.numberOf(r.id), i + 1);
    }
    expect(pirith.numberOf('nope'), 0);
    var compared = 0;
    for (final r in pirith.readings) {
      final blocks = (byId[r.id] as Map)['blocks'] as List;
      final vs = r.sections.single.verses;
      expect(vs.length, blocks.length, reason: r.id);
      for (var b = 0; b < blocks.length; b++) {
        final pairs = blocks[b]['pairs'] as List;
        expect(vs[b].phrases.length, pairs.length, reason: '${r.id} $b');
        for (var p = 0; p < pairs.length; p++) {
          final ph = vs[b].phrases[p];
          expect(ph.pali, pairs[p]['pali']);
          expect(ph.sinhala, pairs[p]['sinhala']);
          expect(ph.english, pairs[p]['english']);
          compared++;
        }
      }
    }
    expect(compared, 5692);
  });

  testWidgets('the catalogue gives a timed recording', (t) async {
    final l = await realLibrary(t);
    final rec = ContentAudioCatalogue(l).recordingFor(mangalaReadingId)!;
    expect(rec.timed, isTrue);
    expect(rec.asset, 'assets/audio/pirith/08-mahamangala.m4a');
  });
}
