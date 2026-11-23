import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart' show realCategoryId;
import '../support/test_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  pirithModelTests();

  late Reading reading;
  late List<Verse> verses;

  Section sec(int n) => reading.sections.firstWhere((s) => s.number == n);
  Verse verse(String id) => verses.firstWhere((v) => v.id == id);

  setUpAll(() async {
    final lib = await AssetContentRepository(rootBundle).load();
    reading = lib.category(realCategoryId)!.readings.single;
    verses = [for (final s in reading.sections) ...s.verses];
  });

  test('every verse has Pali; the verses the booklet prints have Roman Pali', () {
    expect(verses.length, 114);
    // The app's own verses the Nottingham booklet does not print, and the
    // ones whose booklet wording differs (Roman stays empty for them; s12-v1
    // follows Ven. Na Uyane Ariyadhamma Thero's chanting, the owner's call).
    const noRoman = {
      's10-v3',
      's11-v1',
      's12-v1',
      's13-v1',
      's16-v1',
      's18-v1',
      's20-v3',
    };
    for (final v in verses) {
      expect(v.text(ReadingLanguage.pali), isNotNull, reason: v.id);
      if (noRoman.contains(v.id)) {
        expect(v.paliRoman, isNull, reason: v.id);
      } else {
        expect(v.paliRoman, isNotNull, reason: v.id);
      }
    }
    // Sinhala: the 28 verses the app had, and four reused from paritha.org.
    expect(
      verses.where((v) => v.text(ReadingLanguage.sinhala) != null).length,
      32,
    );
    for (final id in ['s08-v6', 's08-v7', 's08-v8', 's23-v1']) {
      expect(verse(id).text(ReadingLanguage.sinhala), isNotNull, reason: id);
    }
    expect(verse('s24-v1').text(ReadingLanguage.sinhala), isNull);
  });

  test('English cover per section', () {
    expect(sec(2).coverOf(ReadingLanguage.english), LanguageCover.all);
    expect(sec(1).coverOf(ReadingLanguage.english), LanguageCover.part);
    expect(sec(10).coverOf(ReadingLanguage.english), LanguageCover.part);
    expect(sec(19).coverOf(ReadingLanguage.english), LanguageCover.all);
    expect(sec(22).coverOf(ReadingLanguage.english), LanguageCover.all);
    for (final n in [11, 16, 18]) {
      expect(sec(n).coverOf(ReadingLanguage.english), LanguageCover.none);
    }
    expect(sec(11).coverOf(ReadingLanguage.pali), LanguageCover.all);
  });

  test('sections 5-7 first-verse English is marked as an explanation', () {
    for (final n in [5, 6, 7]) {
      final v = sec(n).verses.first;
      expect(v.englishKind, EnglishKind.explanation, reason: v.id);
      for (final extra in sec(n).verses.skip(1)) {
        expect(extra.englishKind, EnglishKind.translation, reason: extra.id);
      }
    }
    expect(verse('s02-v1').englishKind, EnglishKind.translation);
  });

  test('English carries its own source', () {
    expect(
      verse('s09-v1').englishSource!.translator,
      contains('Cynthia Gunawardana'),
    );
    expect(
      verse('s02-v1').englishSource!.translator,
      'not named by the source',
    );
    expect(verse('s11-v1').englishSource, isNull);
    expect(verse('s19-v1').englishSource!.name, contains('Nottingham'));
    expect(sec(2).source.name, 'namo.lk');
  });

  test("the booklet's sections and verses carry their sources", () {
    expect(sec(1).source.name, contains('Nottingham'));
    expect(sec(33).source.name, contains('Nottingham'));
    expect(verse('s05-v1').source, isNull);
    expect(verse('s05-v1').sourceOr(sec(5)).name, 'namo.lk');
    for (final n in [5, 6, 7]) {
      for (final v in sec(n).verses.skip(1)) {
        expect(v.source!.name, contains('Nottingham'), reason: v.id);
        expect(v.sourceOr(sec(n)).name, contains('Nottingham'), reason: v.id);
      }
    }
    expect(
      verse('s08-v6').sinhalaSource!.name,
      'paritha.org booklet (Wandana Gatha)',
    );
    expect(verse('s23-v1').sinhalaSource!.locator, endsWith('printed page 38'));
    expect(verse('s08-v1').sinhalaSource, isNull);
  });

  test('four verses need checking and say why; the new sections say why', () {
    final withNotes = verses.where((v) => v.notes.isNotEmpty);
    expect(withNotes.map((v) => v.id).toSet(), {
      's13-v1',
      's14-v2',
      's22-v4',
      's20-v3',
    });
    for (final v in withNotes) {
      expect(v.check, CheckStatus.needsChecking, reason: v.id);
    }
    const newSections = [1, 8, 21, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33];
    // Exactly these need checking: the four old verses, every verse of the new
    // sections, and verses 2-5 of sections 5-7.
    expect(
      verses.where((v) => v.check == CheckStatus.needsChecking).map((v) => v.id).toSet(),
      {
        's13-v1',
        's14-v2',
        's22-v4',
        's20-v3',
        for (final n in newSections) ...sec(n).verses.map((v) => v.id),
        for (final n in [5, 6, 7]) ...sec(n).verses.skip(1).map((v) => v.id),
      },
    );
    expect(
      [for (final n in [5, 6, 7]) sec(n).verses.length],
      [5, 5, 5],
    );
    for (final n in [...newSections, 5, 6, 7]) {
      expect(sec(n).check, CheckStatus.needsChecking, reason: '$n');
      expect(sec(n).notes, hasLength(1), reason: '$n');
    }
    for (final n in newSections) {
      for (final v in sec(n).verses) {
        expect(v.check, CheckStatus.needsChecking, reason: v.id);
      }
    }
    expect(
      reading.sections.where((s) => s.notes.isNotEmpty).map((s) => s.number),
      [1, 5, 6, 7, 8, 21, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33],
    );
    expect(verse('s05-v1').check, CheckStatus.checkedAgainstSource);
    expect(sec(13).check, CheckStatus.needsChecking);
    expect(sec(2).check, CheckStatus.checkedAgainstSource);
  });

  test('corrections are read with from, to, count and reason', () {
    final c = verse('s03-v1').corrections.first;
    expect(c.count, 9);
    expect(c.field, 'pali_si');
    expect(c.from, isNotEmpty);
    expect(c.to, isNotEmpty);
    expect(c.reason, isNotEmpty);
    expect(sec(22).corrections, isNotEmpty);
  });

  test('text() treats an empty string as missing', () {
    final v = Verse.fromJson({
      'id': 'x',
      'pali_si': 'p',
      'sinhala': '',
      'english': '  ',
    });
    expect(v.text(ReadingLanguage.english), isNull);
    expect(v.text(ReadingLanguage.sinhala), isNull);
    expect(v.text(ReadingLanguage.pali), 'p');
  });

  test('missing or unknown fields do not crash loading', () {
    final v = Verse.fromJson({
      'id': 'x',
      'check': 'something else',
      'english_kind': 'odd',
    });
    expect(v.check, CheckStatus.unchecked);
    expect(v.englishKind, isNull);
    expect(v.notes, isEmpty);
    expect(v.corrections, isEmpty);
    expect(v.englishSource, isNull);
  });

  test('a verse reads its own source and sinhala_source', () {
    const rec = {
      'name': 'N',
      'locator': 'L',
      'collected': 'C',
      'translator': 'T',
    };
    final v = Verse.fromJson({
      'id': 'x',
      'source': rec,
      'sinhala_source': {...rec, 'name': 'M'},
    });
    expect(v.source!.name, 'N');
    expect(v.sinhalaSource!.name, 'M');
    final bare = Verse.fromJson({'id': 'y'});
    expect(bare.source, isNull);
    expect(bare.sinhalaSource, isNull);
    final section = Section.fromJson({
      'id': 's',
      'number': 1,
      'heading': 'H',
      'source': {...rec, 'name': 'S'},
    });
    expect(v.sourceOr(section).name, 'N');
    expect(bare.sourceOr(section).name, 'S');
  });

  test('a section reads its notes', () {
    final s = Section.fromJson({
      'id': 's',
      'number': 1,
      'heading': 'H',
      'notes': ['a'],
    });
    expect(s.notes, ['a']);
    final none = Section.fromJson({'id': 's', 'number': 1, 'heading': 'H'});
    expect(none.notes, isEmpty);
  });

  test('reading languages parse from their codes', () {
    expect(ReadingLanguage.fromCode('si'), ReadingLanguage.sinhala);
    expect(ReadingLanguage.fromCode('en'), ReadingLanguage.english);
    expect(ReadingLanguage.fromCode('pi'), ReadingLanguage.pali);
    expect(ReadingLanguage.fromCode('xx'), isNull);
  });

  test('the test library matches its description', () {
    final r = testLibrary().reading('r1')!;
    expect(r.sections.map((s) => s.id), ['s01', 's02', 's03']);
    expect(r.sections[0].verses.length, 2);
    expect(r.sections[0].coverOf(ReadingLanguage.english), LanguageCover.all);
    expect(r.sections[1].coverOf(ReadingLanguage.english), LanguageCover.none);
    final s3 = r.sections[2];
    expect(s3.coverOf(ReadingLanguage.english), LanguageCover.part);
    expect(s3.verses.first.englishKind, EnglishKind.explanation);
  });
}

void pirithModelTests() {
  group('phrases and recordings', () {
    test('Verse.fromJson with and without phrases', () {
      final plain = Verse.fromJson({'id': 'v', 'pali_si': 'A1'});
      expect(plain.phrases, isEmpty);
      expect(plain.isPhrased, isFalse);
      final v = Verse.fromJson({
        'id': 'b1',
        'phrases': [
          {'pali': 'A1', 'sinhala': 'B1', 'english': 'C1'},
        ],
      });
      expect(v.isPhrased, isTrue);
      expect(v.paliSi, isNull);
      expect(v.text(ReadingLanguage.pali), isNull);
      expect(v.phrases.single.text(ReadingLanguage.pali), 'A1');
      expect(v.phrases.single.text(ReadingLanguage.sinhala), 'B1');
      expect(v.phrases.single.text(ReadingLanguage.english), 'C1');
    });

    Map<String, dynamic> reading({Object? audio}) => {
      'id': 'r',
      'title': 'T',
      'title_roman': 'Ti',
      'audio': ?audio,
      'sections': [
        {
          'id': 'p',
          'number': 1,
          'heading': 'H',
          'verses': [
            {
              'id': 'b1',
              'phrases': [
                {'pali': 'A1', 'sinhala': 'B1', 'english': 'C1'},
              ],
            },
          ],
        },
      ],
    };

    test('Reading.fromJson without audio', () {
      final r = Reading.fromJson(reading());
      expect(r.audio, isNull);
      expect(r.titleRoman, 'Ti');
      expect(r.isPhrased, isTrue);
      expect(
        r.sections.single.coverOf(ReadingLanguage.english),
        LanguageCover.all,
      );
    });

    test('Reading.fromJson with audio', () {
      final r = Reading.fromJson(
        reading(
          audio: {
            'path': 'a.m4a',
            'bytes': 6,
            'sha256': 'abc',
            'label': 'L',
            'duration_ms': 1500,
            'block_times': [
              [0.25, 1.5],
              null,
            ],
          },
        ),
      );
      final a = r.audio!;
      expect(a.path, 'a.m4a');
      expect(a.bytes, 6);
      expect(a.sha256, 'abc');
      expect(a.label, 'L');
      expect(a.duration, const Duration(milliseconds: 1500));
      expect(a.blockTimes, [
        const BlockTime(
          Duration(milliseconds: 250),
          Duration(milliseconds: 1500),
        ),
        null,
      ]);
    });

    test('a recording without bytes or sha256 reads 0 and empty', () {
      final a = RecordingInfo.fromJson({'path': 'a.m4a', 'label': 'L'});
      expect(a.bytes, 0);
      expect(a.sha256, '');
    });

    test('the new verse, category and recording fields parse', () {
      final v = Verse.fromJson({
        'id': 'v',
        'keep_lines': true,
        'always_shown': true,
      });
      expect(v.keepLines, isTrue);
      expect(v.alwaysShown, isTrue);
      final plain = Verse.fromJson({'id': 'v'});
      expect(plain.keepLines, isFalse);
      expect(plain.alwaysShown, isFalse);
      final kept = v.withId('w');
      expect(kept.id, 'w');
      expect(kept.keepLines, isTrue);
      expect(kept.alwaysShown, isTrue);

      Category cat(Map<String, dynamic> extra) => Category.fromJson({
        'id': 'c',
        'title': 'T',
        'subtitle': 'S',
        'readings': [],
        ...extra,
      });
      expect(cat({'short_title': 'Short'}).shortTitle, 'Short');
      expect(cat({}).shortTitle, isNull);

      final a = RecordingInfo.fromJson({
        'path': 'a.m4a',
        'label': 'L',
        'line_times': [
          [0.5, null, 2],
          [],
          [null],
        ],
      });
      expect(a.lineTimes, [
        [const Duration(milliseconds: 500), null, const Duration(seconds: 2)],
        <Duration?>[],
        [null],
      ]);
      expect(RecordingInfo.fromJson({'path': 'a', 'label': 'L'}).lineTimes, isEmpty);
    });

    test('a plain reading is not phrased', () {
      final r = Reading(
        id: 'r',
        title: 't',
        sections: [
          Section(id: 's', number: 1, heading: 'h', verses: [Verse(id: 'v')]),
        ],
      );
      expect(r.isPhrased, isFalse);
      expect(const Reading(id: 'r', title: 't', sections: []).isPhrased, isFalse);
    });
  });
}
