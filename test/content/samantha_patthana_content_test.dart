import 'dart:convert';
import 'dart:io';

import 'package:buddhist_gatha/content/model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

const _ids = [
  'u-homage',
  'u-verses',
  'u-list',
  'u-part-1',
  'u-part-2',
  'u-part-3',
  'u-part-4',
  'u-part-5',
  'u-part-6',
  'u-part-7',
  'u-part-8',
  'u-part-9',
  'u-part-10',
  'u-part-11',
  'u-part-12',
  'u-part-13',
  'u-part-14',
  'u-part-15',
  'u-part-16',
  'u-part-17',
  'u-part-18',
  'u-part-19',
  'u-part-20',
  'u-part-21',
  'u-part-22',
  'u-part-23',
  'u-part-24',
  'u-closing',
];
const _paliCounts = [3, 6, 11, 6, 27, 19, 55, 55, 14, 9, 31, 29, 45, 5, 10, 8, 5, 7, 22, 6, 6, 5, 6, 50, 6, 6, 50, 5];
const _sinhalaCounts = [4, 0, 9, 4, 26, 14, 43, 43, 12, 6, 23, 22, 43, 3, 7, 5, 3, 5, 15, 4, 4, 3, 4, 37, 4, 4, 37, 1];

void main() {
  late Library lib;
  late Map<String, dynamic> extracted;

  setUp(() {
    extracted =
        jsonDecode(
              File(
                'content/extracted/samantha_patthana.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  testWidgets('the bundle has three topics and Samantha Pattana is named', (
    t,
  ) async {
    lib = await realLibrary(t);
    expect(lib.categories.map((c) => c.title), [
      'Buddha Wandanawa',
      'Pirith',
      'Samantha Pattana Dharma Wandanawa',
    ]);
    final c = lib.category(samanthaCategoryId)!;
    expect(c.subtitle, 'සමන්ත පට්ඨාන ධර්ම වන්දනාව');
    expect(c.shortTitle, 'Samantha Pattana');
    expect(c.readings.map((r) => r.id), [spIntroductionId, spVandanaId]);
    final intro = c.readings[0];
    final vandana = c.readings[1];
    expect(intro.title, 'Introduction');
    expect(intro.sections.single.id, 'p');
    expect(intro.sections.single.heading, 'Introduction');
    expect(intro.audio, isNull);
    expect(vandana.title, c.subtitle);
    expect(vandana.titleRoman, 'Samantha Pattana Dharma Wandanawa');
    expect(vandana.sections.single.id, 'p');
    expect(vandana.sections.single.heading, c.subtitle);
    expect(extracted['title'], c.subtitle);
  });

  testWidgets('the Vandana lines and meanings are the extracted lines', (
    t,
  ) async {
    lib = await realLibrary(t);
    final verses = lib.reading(spVandanaId)!.sections.single.verses;
    final units = (extracted['units'] as List).cast<Map<String, dynamic>>();
    expect(verses.map((v) => v.id), _ids);
    expect(units.map((u) => u['id']), _ids);
    expect(verses.length, 28);
    for (final (i, v) in verses.indexed) {
      final unit = units[i];
      final pali = [for (final e in unit['pali'] as List) e['text'] as String];
      final meaning = [
        for (final e in unit['sinhala'] as List) e['text'] as String,
      ];
      expect(v.keepLines, isTrue, reason: v.id);
      expect(v.alwaysShown, isFalse, reason: v.id);
      expect(v.phrases.length, _paliCounts[i], reason: v.id);
      expect(v.phrases.map((p) => p.pali), pali, reason: v.id);
      expect(v.phrases.every((p) => p.sinhala.isEmpty && p.english.isEmpty), isTrue);
      expect(meaning.length, _sinhalaCounts[i], reason: v.id);
      expect(v.sinhala, meaning.isEmpty ? isNull : meaning.join('\n'), reason: v.id);
    }
    expect(verses.fold<int>(0, (n, v) => n + v.phrases.length), 507);
    expect(
      verses.fold<int>(0, (n, v) => n + (v.sinhala?.split('\n').length ?? 0)),
      385,
    );
  });

  testWidgets('the Introduction is the three extracted paragraphs', (t) async {
    lib = await realLibrary(t);
    final verses = lib.reading(spIntroductionId)!.sections.single.verses;
    expect(verses.map((v) => v.id), ['intro-1', 'intro-2', 'intro-3']);
    expect(verses.map((v) => v.sinhala), extracted['introduction']);
    expect(verses.every((v) => v.alwaysShown && !v.isPhrased), isTrue);
  });

  testWidgets('all 31 verses need checking', (t) async {
    lib = await realLibrary(t);
    final all = [
      for (final r in lib.category(samanthaCategoryId)!.readings)
        for (final s in r.sections) ...s.verses,
    ];
    expect(all.length, 31);
    expect(all.every((v) => v.check == CheckStatus.needsChecking), isTrue);
  });

  testWidgets('the recording is timed by block and by line', (t) async {
    lib = await realLibrary(t);
    final audio = lib.reading(spVandanaId)!.audio!;
    expect(audio.asset, 'assets/audio/samantha_patthana/hYXyO3o7Iac.m4a');
    expect(audio.label, 'Chanted by Ven. Kiriwaththuduwe Ariyadassana Thero');
    expect(audio.duration, const Duration(minutes: 47, seconds: 36));
    expect(audio.blockTimes.length, 28);
    expect(audio.blockTimes.every((b) => b != null), isTrue);
    final starts = [for (final b in audio.blockTimes) b!.start];
    for (var i = 1; i < starts.length; i++) {
      expect(starts[i] >= starts[i - 1], isTrue, reason: 'block $i');
    }
    final verses = lib.reading(spVandanaId)!.sections.single.verses;
    expect(audio.lineTimes.length, 28);
    for (final (i, lines) in audio.lineTimes.indexed) {
      expect(lines.length, verses[i].phrases.length, reason: _ids[i]);
      if (i == 0) {
        expect(lines.every((x) => x == null), isTrue);
      } else {
        expect(lines.every((x) => x != null), isTrue, reason: _ids[i]);
      }
    }
  });

  testWidgets('no Pirith reading has line times', (t) async {
    lib = await realLibrary(t);
    for (final r in lib.category(pirithCategoryId)!.readings) {
      expect(r.audio!.lineTimes, isEmpty, reason: r.id);
    }
  });

  test('the card picture is bundled', () {
    expect(File('assets/pictures/samantha_patthana.jpg').existsSync(), isTrue);
  });
}
