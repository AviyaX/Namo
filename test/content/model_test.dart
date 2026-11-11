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

  test('every verse has Pali and Sinhala; none has Roman Pali', () {
    expect(verses.length, 28);
    for (final v in verses) {
      expect(v.text(ReadingLanguage.pali), isNotNull, reason: v.id);
      expect(v.text(ReadingLanguage.sinhala), isNotNull, reason: v.id);
      expect(v.paliRoman, isNull, reason: v.id);
    }
  });

  test('English cover per section', () {
    expect(sec(1).coverOf(ReadingLanguage.english), LanguageCover.all);
    expect(sec(8).coverOf(ReadingLanguage.english), LanguageCover.part);
    expect(sec(18).coverOf(ReadingLanguage.english), LanguageCover.part);
    for (final n in [9, 14, 16, 17]) {
      expect(sec(n).coverOf(ReadingLanguage.english), LanguageCover.none);
    }
    expect(sec(9).coverOf(ReadingLanguage.pali), LanguageCover.all);
  });

  test('sections 4-6 English is marked as an explanation', () {
    for (final n in [4, 5, 6]) {
      for (final v in sec(n).verses) {
        if (v.text(ReadingLanguage.english) != null) {
          expect(v.englishKind, EnglishKind.explanation, reason: v.id);
        }
      }
    }
    expect(verse('s01-v1').englishKind, EnglishKind.translation);
  });

  test('English carries its own source', () {
    expect(
      verse('s07-v1').englishSource!.translator,
      contains('Cynthia Gunawardana'),
    );
    expect(
      verse('s01-v1').englishSource!.translator,
      'not named by the source',
    );
    expect(verse('s09-v1').englishSource, isNull);
    expect(sec(1).source.name, 'namo.lk');
  });

  test('four verses need checking and say why', () {
    final need = verses.where((v) => v.check == CheckStatus.needsChecking);
    expect(need.map((v) => v.id).toSet(), {
      's11-v1',
      's12-v2',
      's18-v4',
      's19-v3',
    });
    for (final v in need) {
      expect(v.notes, isNotEmpty, reason: v.id);
    }
    expect(sec(11).check, CheckStatus.needsChecking);
    expect(sec(1).check, CheckStatus.checkedAgainstSource);
  });

  test('corrections are read with from, to, count and reason', () {
    final c = verse('s02-v1').corrections.first;
    expect(c.count, 9);
    expect(c.field, 'pali_si');
    expect(c.from, isNotEmpty);
    expect(c.to, isNotEmpty);
    expect(c.reason, isNotEmpty);
    expect(sec(18).corrections, isNotEmpty);
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
            'asset': 'a.m4a',
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
      expect(a.asset, 'a.m4a');
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
