import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/home/today.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

Library _lib(List<Verse> verses) => Library(
  categories: [
    Category(
      id: 'c',
      title: 'c',
      subtitle: 's',
      readings: [
        Reading(
          id: 'r',
          title: 'r',
          sections: [
            Section(id: 's1', number: 1, heading: 'h', verses: verses),
          ],
        ),
      ],
    ),
  ],
);

Verse _v(
  String id, {
  String? pali = 'aaa',
  String? english,
  String? sinhala,
  CheckStatus check = CheckStatus.checkedAgainstSource,
}) => Verse(
  id: id,
  paliSi: pali,
  english: english,
  sinhala: sinhala,
  check: check,
);

Library _numbered(int n) =>
    _lib([for (var i = 0; i < n; i++) _v('v$i')]);

List<String> _ids(List<GathaPick> p) => [for (final g in p) g.verse.id];

void main() {
  group('greetingFor', () {
    String at(int h, int m) => greetingFor(DateTime(2026, 3, 4, h, m));
    test('by time of day', () {
      expect(at(4, 59), 'Good evening');
      expect(at(5, 0), 'Good morning');
      expect(at(11, 59), 'Good morning');
      expect(at(12, 0), 'Good afternoon');
      expect(at(16, 59), 'Good afternoon');
      expect(at(17, 0), 'Good evening');
      expect(at(0, 0), 'Good evening');
    });
  });

  group('eligibleGathas', () {
    testWidgets('bundled content gives the listed verses', (t) async {
      final lib = await realLibrary(t);
      final picks = eligibleGathas(lib);
      expect(_ids(picks), [
        's01-v1', 's07-v1', 's08-v1', 's08-v2', 's08-v3', 's09-v1',
        's10-v1', 's11-v2', 's12-v1', 's13-v1', 's14-v1', 's15-v1',
        's16-v1', 's17-v1', 's18-v1', 's18-v2', 's18-v3', 's19-v1',
        's19-v2',
      ]);
      for (final p in picks) {
        expect(p.verse.check, CheckStatus.checkedAgainstSource);
      }
    });

    test('placeholder rules', () {
      final lib = _lib([
        _v('five-lines', pali: List.filled(5, 'a').join('\n')),
        _v('long-english', english: 'a' * 321),
        _v('needs', check: CheckStatus.needsChecking),
        _v('unchecked', check: CheckStatus.unchecked),
        _v('no-pali', pali: null),
        _v(
          'ok',
          pali: List.filled(4, 'a').join('\n'),
          english: 'a' * 320,
        ),
      ]);
      expect(_ids(eligibleGathas(lib)), ['ok']);
    });

    test('length counts characters not code units', () {
      // 320 astral characters are 640 UTF-16 code units.
      final lib = _lib([_v('astral', english: '\u{10000}' * 320)]);
      expect(_ids(eligibleGathas(lib)), ['astral']);
    });
  });

  group('gathaForDay', () {
    test('same pick all day, next date differs', () {
      final lib = _numbered(5);
      final a = gathaForDay(lib, DateTime(2026, 3, 4, 0, 0))!;
      final b = gathaForDay(lib, DateTime(2026, 3, 4, 23, 59))!;
      final c = gathaForDay(lib, DateTime(2026, 3, 5))!;
      expect(a.verse.id, b.verse.id);
      expect(c.verse.id, isNot(a.verse.id));
    });

    test('every verse once over consecutive dates', () {
      final lib = _numbered(7);
      final seen = [
        for (var d = 0; d < 7; d++)
          gathaForDay(lib, DateTime(2026, 3, 1 + d))!.verse.id,
      ];
      expect(seen.toSet().length, 7);
    });

    test('null for an empty library', () {
      expect(gathaForDay(const Library(categories: []), DateTime(2026)), isNull);
    });

    test('edges', () {
      expect(dayNumber(DateTime(1969, 12, 31)), -1);
      expect(dayNumber(DateTime(1970, 1, 1, 23, 59)), 0);
      expect(
        dayNumber(DateTime(2026, 3, 4, 0, 30)),
        dayNumber(DateTime(2026, 3, 4, 23, 30)),
      );
      final lib = _numbered(5);
      expect(gathaForDay(lib, DateTime(1969, 12, 31))!.verse.id, 'v4');
    });
  });

  group('gathaTexts', () {
    final verse = _v('x', pali: 'ppp', sinhala: 'sss');
    test('skips languages the verse lacks', () {
      final r = gathaTexts(
        verse,
        const LanguageSelection([
          ReadingLanguage.sinhala,
          ReadingLanguage.english,
        ]),
      );
      expect(r, [(ReadingLanguage.sinhala, 'sss')]);
    });
    test('falls back to Pali', () {
      final r = gathaTexts(
        verse,
        const LanguageSelection([ReadingLanguage.english]),
      );
      expect(r, [(ReadingLanguage.pali, 'ppp')]);
    });
    test('keeps chosen order and strings', () {
      final r = gathaTexts(
        verse,
        const LanguageSelection([
          ReadingLanguage.sinhala,
          ReadingLanguage.pali,
        ]),
      );
      expect(r, [
        (ReadingLanguage.sinhala, 'sss'),
        (ReadingLanguage.pali, 'ppp'),
      ]);
      expect(identical(r.first.$2, verse.sinhala), isTrue);
    });
  });
}
