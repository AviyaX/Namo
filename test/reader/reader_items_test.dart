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
}
