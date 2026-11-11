import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/library/search.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

const _english = LanguageSelection([ReadingLanguage.english]);
const _sinhala = LanguageSelection([ReadingLanguage.sinhala]);

Library _lib() => const Library(
  categories: [
    Category(
      id: 'c1',
      title: 'Refuge chants',
      subtitle: 'Daily practice',
      readings: [
        Reading(
          id: 'r1',
          title: 'Morning reading',
          sections: [
            Section(
              id: 's1',
              number: 1,
              heading: 'Triple refuge',
              verses: [
                Verse(
                  id: 's1-v1',
                  paliRoman: 'Buddhaṃ saraṇaṃ gacchāmi\nDhammaṃ saraṇaṃ',
                  english: 'I go to the Buddha for refuge',
                ),
                Verse(
                  id: 's1-v2',
                  paliRoman: 'Saṅgha vandāmi',
                  sinhala: 'sinhala text',
                  english: 'end of one\nstart of two',
                ),
              ],
            ),
            Section(
              id: 's2',
              number: 2,
              heading: 'Lamp offering',
              verses: [
                Verse(id: 's2-v1', paliSi: 'pali lamp', english: 'lamp light'),
                Verse(id: 's2-v2', paliSi: 'pali lamp again'),
              ],
            ),
          ],
        ),
      ],
    ),
    Category(
      id: 'c2',
      title: 'Other',
      subtitle: 'More',
      readings: [
        Reading(
          id: 'r2',
          title: 'Evening reading',
          sections: [
            Section(id: 's3', number: 1, heading: 'Evening lamp', verses: []),
          ],
        ),
      ],
    ),
  ],
);

List<String> _ids(List<SearchHit> h) => [for (final x in h) x.section.id];

void main() {
  group('foldForSearch', () {
    test('lower-cases, strips diacritics, collapses whitespace', () {
      expect(foldForSearch('  Saṅgha\n  VANDĀMI '), 'sangha vandami');
    });
    test('removes joiners', () {
      expect(foldForSearch('a‍b‌c'), 'abc');
    });
    test('maps the listed letters and Latin-1 vowels', () {
      expect(foldForSearch('āīūṅñṭḍṇḷṃṁśṣṛ'), 'aiunntdnlmmssr');
      expect(foldForSearch('ĀĪŪṄÑṬḌṆḶṂṀŚṢṚ'), 'aiunntdnlmmssr');
      expect(foldForSearch('àéîõüÿ x'), 'aeiouy x');
    });
  });

  group('searchLibrary with placeholder content', () {
    final lib = _lib();
    test('folded queries find the diacritic verse', () {
      for (final q in ['sangha', 'SANGHA', 'saṅgha']) {
        expect(_ids(searchLibrary(lib, q, _english)), ['s1']);
      }
    });
    test('heading match has no line; verse match keeps stored line', () {
      final h = searchLibrary(lib, 'triple', _english).single;
      expect(h.line, isNull);
      expect(h.lineLanguage, isNull);
      final v = searchLibrary(lib, 'for refuge', _english).single;
      expect(v.line, 'I go to the Buddha for refuge');
    });
    test('several matches in one section give one hit', () {
      final hits = searchLibrary(lib, 'lamp', _english);
      expect(_ids(hits), ['s2', 's3']);
    });
    test('category title match returns every section in order', () {
      expect(_ids(searchLibrary(lib, 'refuge chants', _english)), ['s1', 's2']);
      expect(_ids(searchLibrary(lib, 'daily', _english)), ['s1', 's2']);
    });
    test('reading title matches', () {
      expect(_ids(searchLibrary(lib, 'evening reading', _english)), ['s3']);
    });
    test('language order', () {
      final e = searchLibrary(lib, 'lamp', _english).first;
      expect(e.lineLanguage, ReadingLanguage.english);
      expect(e.lineLanguageChosen, isTrue);
      expect(e.line, 'lamp light');
      final s = searchLibrary(lib, 'lamp', _sinhala).first;
      expect(s.lineLanguage, ReadingLanguage.pali);
      expect(s.lineLanguageChosen, isFalse);
      expect(s.line, 'pali lamp');
    });
    test('roman pali line is the matching stored line', () {
      final h = searchLibrary(lib, 'dhammam', _sinhala).single;
      expect(h.line, 'Dhammaṃ saraṇaṃ');
      expect(h.lineLanguage, ReadingLanguage.pali);
    });
    test('match across a line break gives the first line', () {
      final h = searchLibrary(lib, 'one start', _english).single;
      expect(h.line, 'end of one');
    });
    test('odd queries never throw and never match as patterns', () {
      for (final q in [
        '',
        ' ',
        'a',
        '‍‍‍',
        '((',
        r'\',
        '.*',
        '[a-',
        'x' * 5000,
      ]) {
        expect(searchLibrary(lib, q, _english), isEmpty, reason: q);
      }
    });
  });

  group('searchLibrary with bundled content', () {
    testWidgets('sinhala heading prefix finds its section', (t) async {
      final lib = await realLibrary(t);
      final s = lib.categories.first.readings.first.sections.first;
      final q = String.fromCharCodes(s.heading.runes.take(3));
      expect(
        _ids(searchLibrary(lib, q, LanguageSelection.initial)),
        contains(s.id),
      );
    });
    testWidgets('pali and english words find their verse', (t) async {
      final lib = await realLibrary(t);
      var checked = 0;
      for (final c in lib.categories) {
        for (final r in c.readings) {
          for (final s in r.sections) {
            for (final v in s.verses) {
              final p = v.paliSi;
              final e = v.english;
              if (checked > 0 || p == null || e == null) continue;
              final pw = p
                  .split(RegExp(r'\s+'))
                  .firstWhere((w) => w.runes.length >= 3, orElse: () => '');
              final ew = e
                  .split(RegExp(r'\s+'))
                  .firstWhere(
                    (w) => RegExp(r'^[A-Za-z]{4,}$').hasMatch(w),
                    orElse: () => '',
                  );
              if (pw.isEmpty || ew.isEmpty) continue;
              checked++;
              final ph = searchLibrary(
                lib,
                pw,
                LanguageSelection.initial,
              ).where((h) => h.section.id == s.id).first;
              expect(ph.line, contains(pw));
              for (final q in [ew, ew.toUpperCase()]) {
                expect(_ids(searchLibrary(lib, q, _english)), contains(s.id));
              }
            }
          }
        }
      }
      expect(checked, 1);
    });
    testWidgets('every line is a stored line of that section', (t) async {
      final lib = await realLibrary(t);
      final verses = [
        for (final c in lib.categories)
          for (final r in c.readings)
            for (final s in r.sections) ...s.verses,
      ];
      String? first(String? Function(Verse) get) {
        for (final v in verses) {
          final x = get(v);
          if (x != null) return x;
        }
        return null;
      }

      final head = lib.categories.first.readings.first.sections.first.heading;
      final queries = <String>[
        for (final x in [
          head,
          first((v) => v.paliSi),
          first((v) => v.paliRoman),
          first((v) => v.sinhala),
          first((v) => v.english),
        ])
          if (x != null) String.fromCharCodes(x.trim().runes.take(3)),
      ].where((q) => foldForSearch(q).runes.length >= searchMinLength);
      expect(queries, isNotEmpty);
      var checked = 0;
      for (final sel in [LanguageSelection.initial, _english, _sinhala]) {
        for (final query in queries) {
          for (final h in searchLibrary(lib, query, sel)) {
            final line = h.line;
            if (line == null) continue;
            final stored = <String>{
              for (final v in h.section.verses)
                for (final x in [v.paliSi, v.paliRoman, v.sinhala, v.english])
                  if (x != null) ...x.split('\n').map((l) => l.trim()),
              // A pirith hit's line is the text of one of its phrases.
              for (final s in h.reading.sections)
                for (final v in s.verses)
                  for (final ph in v.phrases)
                    for (final x in [ph.pali, ph.sinhala, ph.english])
                      ...x.split('\n').map((l) => l.trim()),
            };
            expect(stored, contains(line));
            checked++;
          }
        }
      }
      expect(checked, greaterThan(0));
    });
  });

  group('searchLibrary, Samantha Pattana', () {
    const initial = LanguageSelection.initial;
    List<String> readings(List<SearchHit> h) => [for (final x in h) x.reading.id];

    /// The Vandana's unit at [i] (by line, not typed here).
    Future<Verse> unit(WidgetTester t, int i) async =>
        (await realLibrary(t)).reading(spVandanaId)!.sections.single.verses[i];

    testWidgets('a Pali line finds only the Vandana, once, with that line', (
      t,
    ) async {
      final lib = await realLibrary(t);
      final v = (await unit(t, 3));
      expect(v.keepLines, isTrue);
      final line = v.phrases[1].pali.trim();
      final hits = searchLibrary(lib, line, initial);
      expect(readings(hits), [spVandanaId]);
      expect(hits.single.line, line);
      expect(hits.single.lineLanguage, ReadingLanguage.pali);
    });

    testWidgets('a meaning line finds only the Vandana, once, with that line', (
      t,
    ) async {
      final lib = await realLibrary(t);
      final v = await unit(t, 3);
      final line = v.sinhala!.split('\n')[1].trim();
      final hits = searchLibrary(lib, line, initial);
      expect(readings(hits), [spVandanaId]);
      expect(hits.single.line, line);
      expect(hits.single.lineLanguage, ReadingLanguage.sinhala);
      expect(hits.single.lineLanguageChosen, isTrue);
    });

    testWidgets('with Sinhala not chosen a meaning match names its language', (
      t,
    ) async {
      final lib = await realLibrary(t);
      final v = await unit(t, 3);
      final line = v.sinhala!.split('\n')[1].trim();
      final hit = searchLibrary(lib, line, _english).single;
      expect(hit.reading.id, spVandanaId);
      expect(hit.line, line);
      expect(hit.lineLanguage, ReadingLanguage.sinhala);
      expect(hit.lineLanguageChosen, isFalse);
    });

    testWidgets('a word of the Introduction finds it', (t) async {
      final lib = await realLibrary(t);
      final text = lib.reading(spIntroductionId)!.sections.single.verses.first
          .sinhala!;
      final word = text
          .split(RegExp(r'\s+'))
          .firstWhere((w) => w.runes.length >= 5);
      final hits = searchLibrary(lib, word, initial)
          .where((h) => h.reading.id == spIntroductionId)
          .toList();
      expect(hits, hasLength(1));
      expect(hits.single.line, contains(word));
      expect(readings(searchLibrary(lib, 'Introduction', initial)), [
        spIntroductionId,
      ]);
    });

    testWidgets('"Samantha" finds both readings, one hit each', (t) async {
      final lib = await realLibrary(t);
      List<String> mine(String q) => [
        for (final h in searchLibrary(lib, q, initial))
          if (h.category.id == samanthaCategoryId) h.reading.id,
      ];
      for (final q in [
        'Samantha',
        'samantha pattana',
        lib.category(samanthaCategoryId)!.subtitle,
      ]) {
        expect(mine(q), [spIntroductionId, spVandanaId], reason: q);
      }
      // Any other hit (a pirith of a like name) is in the topics before.
      final hits = searchLibrary(lib, 'Samantha', initial);
      expect(readings(hits).sublist(hits.length - 2), [
        spIntroductionId,
        spVandanaId,
      ]);
    });
  });
}
