import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/reader/reader_items.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_content.dart';

const _pali = ReadingLanguage.pali;
const _sinhala = ReadingLanguage.sinhala;
const _english = ReadingLanguage.english;

const _explanationNote =
    'The English here explains each quality; it is not a line-by-line '
    'translation.';

/// H(s01) for a heading, V(s01-v1, pi) for a verse text.
List<String> _kinds(List<ReaderItem> items) => [
  for (final i in items)
    switch (i) {
      HeadingItem() => 'H(${i.sectionId})',
      VerseTextItem() => 'V(${i.verseId}, ${i.language.code})',
      PhraseBlockItem() => 'B(${i.verseId}, ${i.index})',
    },
];

List<ReaderItem> _build(
  List<ReadingLanguage> languages,
  TwoLanguageLayout layout,
) => buildReaderItems(
  testLibrary().reading('r1')!,
  LanguageSelection(languages),
  layout,
);

void main() {
  test('verse layout pairs each verse', () {
    final items = _build([_pali, _sinhala], TwoLanguageLayout.verse);
    expect(_kinds(items), [
      'H(s01)',
      'V(s01-v1, pi)',
      'V(s01-v1, si)',
      'V(s01-v2, pi)',
      'V(s01-v2, si)',
      'H(s02)',
      'V(s02-v1, pi)',
      'V(s02-v1, si)',
      'H(s03)',
      'V(s03-v1, pi)',
      'V(s03-v1, si)',
      'V(s03-v2, pi)',
      'V(s03-v2, si)',
    ]);
  });

  test('section layout groups by language', () {
    final items = _build([_pali, _sinhala], TwoLanguageLayout.section);
    expect(_kinds(items), [
      'H(s01)',
      'V(s01-v1, pi)',
      'V(s01-v2, pi)',
      'V(s01-v1, si)',
      'V(s01-v2, si)',
      'H(s02)',
      'V(s02-v1, pi)',
      'V(s02-v1, si)',
      'H(s03)',
      'V(s03-v1, pi)',
      'V(s03-v2, pi)',
      'V(s03-v1, si)',
      'V(s03-v2, si)',
    ]);
  });

  test('one language gives the same list in both layouts', () {
    final bySection = _build([_sinhala], TwoLanguageLayout.section);
    final byVerse = _build([_sinhala], TwoLanguageLayout.verse);
    expect(_kinds(bySection), _kinds(byVerse));
    expect(_kinds(bySection), [
      'H(s01)',
      'V(s01-v1, si)',
      'V(s01-v2, si)',
      'H(s02)',
      'V(s02-v1, si)',
      'H(s03)',
      'V(s03-v1, si)',
      'V(s03-v2, si)',
    ]);
    expect(
      byVerse.whereType<VerseTextItem>().every((v) => !v.secondary),
      isTrue,
    );
  });

  test('a section with no English shows its heading, a note and the other '
      'language', () {
    final items = _build([_english, _pali], TwoLanguageLayout.verse);
    final s02 = items.where((i) => i.sectionId == 's02').toList();
    expect(_kinds(s02), ['H(s02)', 'V(s02-v1, pi)']);
    expect((s02.first as HeadingItem).notes, [
      'English is not yet available for this section.',
    ]);
  });

  test('only English chosen and none available leaves the heading and its '
      'note', () {
    final items = _build([_english], TwoLanguageLayout.verse);
    final s02 = items.where((i) => i.sectionId == 's02').toList();
    expect(s02, hasLength(1));
    expect((s02.single as HeadingItem).notes, [
      'English is not yet available for this section.',
    ]);
  });

  test('partial English is noted and the missing verse is skipped', () {
    final items = _build([_english, _pali], TwoLanguageLayout.verse);
    final s03 = items.where((i) => i.sectionId == 's03').toList();
    expect(
      (s03.first as HeadingItem).notes,
      contains('English is not yet available for part of this section.'),
    );
    expect(_kinds(s03), contains('V(s03-v1, en)'));
    expect(_kinds(s03), isNot(contains('V(s03-v2, en)')));
    expect(_kinds(s03), contains('V(s03-v2, pi)'));
  });

  test('explanation English is labelled', () {
    final withEnglish = _build([_english, _pali], TwoLanguageLayout.verse);
    final heading =
        withEnglish.firstWhere((i) => i.sectionId == 's03') as HeadingItem;
    expect(heading.notes, [
      'English is not yet available for part of this section.',
      _explanationNote,
    ]);
    final s01 = withEnglish.first as HeadingItem;
    expect(s01.notes, isEmpty);

    final without = _build([_pali, _sinhala], TwoLanguageLayout.verse);
    for (final h in without.whereType<HeadingItem>()) {
      expect(h.notes, isNot(contains(_explanationNote)));
    }
  });

  test('the second language is marked secondary', () {
    for (final layout in TwoLanguageLayout.values) {
      final verses = _build(
        [_pali, _sinhala],
        layout,
      ).whereType<VerseTextItem>();
      expect(
        verses.every((v) => v.secondary == (v.language == _sinhala)),
        isTrue,
      );
      expect(verses.any((v) => v.secondary), isTrue);
      expect(verses.any((v) => !v.secondary), isTrue);
    }
  });

  group('a phrased reading', () {
    Phrase p(String s) => Phrase(pali: 'p$s', sinhala: 's$s', english: 'e$s');
    final reading = Reading(
      id: 'x',
      title: 'Title',
      titleRoman: 'Roman',
      audio: const RecordingInfo(asset: 'a.m4a', label: 'Credit line'),
      sections: [
        Section(
          id: 'x-s',
          number: 1,
          heading: 'Title',
          verses: [
            Verse(id: 'x-1', phrases: [p('1'), p('2')]),
            Verse(id: 'x-2', phrases: [p('3')]),
            Verse(id: 'x-3', phrases: [p('4'), p('5'), p('6')]),
          ],
        ),
      ],
    );

    test('gives a heading and one block per verse, whatever the layout', () {
      for (final layout in TwoLanguageLayout.values) {
        final items = buildReaderItems(
          reading,
          const LanguageSelection([_pali, _english]),
          layout,
        );
        expect(_kinds(items), ['H(x-s)', 'B(x-1, 0)', 'B(x-2, 1)', 'B(x-3, 2)']);
        final blocks = items.whereType<PhraseBlockItem>().toList();
        for (var i = 0; i < blocks.length; i++) {
          expect(blocks[i].phrases, same(reading.sections[0].verses[i].phrases));
          expect(blocks[i].languages, [_pali, _english]);
          expect(blocks[i].sectionId, 'x-s');
        }
      }
    });

    test('the heading carries the Roman name and credit, and no bookmark', () {
      final heading =
          buildReaderItems(
                reading,
                LanguageSelection.initial,
                TwoLanguageLayout.verse,
              ).first
              as HeadingItem;
      expect(heading.romanTitle, 'Roman');
      expect(heading.credit, 'Credit line');
      expect(heading.canBookmark, isFalse);
      expect(heading.notes, isEmpty);
    });

    group('a mixed reading', () {
      final mixed = Reading(
        id: 'm',
        title: 'Mixed',
        sections: [
          Section(
            id: 'o1',
            number: 1,
            heading: 'One',
            verses: [Verse(id: 'o1-1', paliSi: 'p o1', sinhala: 's o1')],
          ),
          Section(
            id: 'ph',
            number: 2,
            heading: 'Two',
            verses: [
              Verse(id: 'ph-1', phrases: [p('1'), p('2')]),
              Verse(id: 'ph-2', phrases: [p('3')]),
            ],
          ),
          Section(
            id: 'o2',
            number: 3,
            heading: 'Three',
            verses: [
              Verse(id: 'o2-1', paliSi: 'p o2a', sinhala: 's o2a'),
              Verse(id: 'o2-2', paliSi: 'p o2b', sinhala: 's o2b'),
            ],
          ),
        ],
      );

      test('verse layout gives each section its own content once, in '
          'order', () {
        final items = buildReaderItems(
          mixed,
          const LanguageSelection([_pali, _sinhala]),
          TwoLanguageLayout.verse,
        );
        expect(_kinds(items), [
          'H(o1)',
          'V(o1-1, pi)',
          'V(o1-1, si)',
          'H(ph)',
          'B(ph-1, 0)',
          'B(ph-2, 1)',
          'H(o2)',
          'V(o2-1, pi)',
          'V(o2-1, si)',
          'V(o2-2, pi)',
          'V(o2-2, si)',
        ]);
      });

      test('section layout gives each section its own content once, in '
          'order', () {
        final items = buildReaderItems(
          mixed,
          const LanguageSelection([_pali, _sinhala]),
          TwoLanguageLayout.section,
        );
        expect(_kinds(items), [
          'H(o1)',
          'V(o1-1, pi)',
          'V(o1-1, si)',
          'H(ph)',
          'B(ph-1, 0)',
          'B(ph-2, 1)',
          'H(o2)',
          'V(o2-1, pi)',
          'V(o2-2, pi)',
          'V(o2-1, si)',
          'V(o2-2, si)',
        ]);
      });

      test('the phrased section heading has no bookmark and its blocks carry '
          'the chosen languages', () {
        for (final layout in TwoLanguageLayout.values) {
          final items = buildReaderItems(
            mixed,
            const LanguageSelection([_pali, _sinhala]),
            layout,
          );
          final headings = items.whereType<HeadingItem>().toList();
          expect(headings.map((h) => h.canBookmark), [true, false, true]);
          expect(headings[1].notes, isEmpty);
          expect(headings[1].romanTitle, isNull);
          expect(headings[1].credit, isNull);
          final blocks = items.whereType<PhraseBlockItem>().toList();
          expect(blocks.map((b) => b.index), [0, 1]);
          for (var i = 0; i < blocks.length; i++) {
            expect(blocks[i].sectionId, 'ph');
            expect(blocks[i].languages, [_pali, _sinhala]);
            expect(
              blocks[i].phrases,
              same(mixed.sections[1].verses[i].phrases),
            );
          }
        }
      });
    });

    test('an ordinary reading heading can be bookmarked', () {
      final heading =
          _build([_pali], TwoLanguageLayout.verse).first as HeadingItem;
      expect(heading.canBookmark, isTrue);
      expect(heading.romanTitle, isNull);
      expect(heading.credit, isNull);
    });
  });

  group('a reading of units kept line by line', () {
    Phrase line(String s) => Phrase(pali: 'l$s', sinhala: '', english: '');
    final reading = Reading(
      id: 'k',
      title: 'Units',
      titleRoman: 'Roman units',
      audio: const RecordingInfo(asset: 'a.m4a', label: 'Credit line'),
      sections: [
        Section(
          id: 'k-s',
          number: 1,
          heading: 'Units',
          verses: [
            Verse(
              id: 'k-1',
              keepLines: true,
              sinhala: 'mone\nmtwo',
              phrases: [line('1'), line('2')],
            ),
            Verse(id: 'k-2', keepLines: true, phrases: [line('3')]),
          ],
        ),
      ],
    );

    List<PhraseBlockItem> blocks(List<ReadingLanguage> languages) {
      final items = buildReaderItems(
        reading,
        LanguageSelection(languages),
        TwoLanguageLayout.verse,
      );
      expect(_kinds(items), ['H(k-s)', 'B(k-1, 0)', 'B(k-2, 1)']);
      return items.whereType<PhraseBlockItem>().toList();
    }

    test('each unit is one block that keeps its lines and carries its '
        'meaning', () {
      final b = blocks([_pali]);
      expect(b.map((x) => x.keepLines), [true, true]);
      expect(b[0].meaning, 'mone\nmtwo');
      expect(b[1].meaning, isNull);
      expect(b[0].phrases, same(reading.sections[0].verses[0].phrases));
    });

    test('Pali shows the lines', () {
      expect(blocks([_pali]).map((x) => x.languages), [
        [_pali],
        [_pali],
      ]);
    });

    test('Sinhala shows the meaning, and nothing for a unit without one', () {
      expect(blocks([_sinhala]).map((x) => x.languages), [
        [_sinhala],
        <ReadingLanguage>[],
      ]);
    });

    test('English shows nothing, as in a pirith without English', () {
      expect(blocks([_english]).map((x) => x.languages), [
        <ReadingLanguage>[],
        <ReadingLanguage>[],
      ]);
    });

    test('Pali with Sinhala shows the lines and the meaning under them, in '
        'either order of choosing', () {
      for (final chosen in [
        [_pali, _sinhala],
        [_sinhala, _pali],
      ]) {
        expect(blocks(chosen).map((x) => x.languages), [
          [_pali, _sinhala],
          [_pali],
        ]);
      }
    });

    test('English with Sinhala shows the meaning only', () {
      expect(blocks([_english, _sinhala]).map((x) => x.languages), [
        [_sinhala],
        <ReadingLanguage>[],
      ]);
    });

    test('the heading is a pirith heading', () {
      final heading =
          buildReaderItems(
                reading,
                const LanguageSelection([_english]),
                TwoLanguageLayout.verse,
              ).first
              as HeadingItem;
      expect(heading.romanTitle, 'Roman units');
      expect(heading.credit, 'Credit line');
      expect(heading.canBookmark, isFalse);
      expect(heading.notes, isEmpty);
    });

    test('a pirith block keeps neither lines nor a meaning', () {
      final items = buildReaderItems(
        Reading(
          id: 'x',
          title: 'Title',
          sections: [
            Section(
              id: 'x-s',
              number: 1,
              heading: 'Title',
              verses: [
                Verse(
                  id: 'x-1',
                  sinhala: 'unused',
                  phrases: const [Phrase(pali: 'a', sinhala: 'b', english: '')],
                ),
              ],
            ),
          ],
        ),
        const LanguageSelection([_english, _sinhala]),
        TwoLanguageLayout.verse,
      );
      final block = items.whereType<PhraseBlockItem>().single;
      expect(block.keepLines, isFalse);
      expect(block.meaning, isNull);
      expect(block.languages, [_english, _sinhala]);
    });
  });

  group('verses shown whatever the languages', () {
    final reading = Reading(
      id: 'i',
      title: 'Intro',
      sections: [
        Section(
          id: 'i-s',
          number: 1,
          heading: 'Intro',
          verses: [
            Verse(id: 'i-1', sinhala: 'aone', alwaysShown: true),
            Verse(id: 'i-2', sinhala: 'atwo', alwaysShown: true),
          ],
        ),
      ],
    );

    for (final chosen in [
      [_pali],
      [_english],
    ]) {
      test('${chosen.single.label} only shows each paragraph in Sinhala, in '
          'the main colour, with no note and no bookmark', () {
        for (final layout in TwoLanguageLayout.values) {
          final items = buildReaderItems(
            reading,
            LanguageSelection(chosen),
            layout,
          );
          expect(_kinds(items), ['H(i-s)', 'V(i-1, si)', 'V(i-2, si)']);
          final heading = items.first as HeadingItem;
          expect(heading.notes, isEmpty);
          expect(heading.canBookmark, isFalse);
          final verses = items.whereType<VerseTextItem>().toList();
          expect(verses.map((v) => v.text), ['aone', 'atwo']);
          expect(verses.every((v) => !v.secondary), isTrue);
        }
      });
    }
  });
}
