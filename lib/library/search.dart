import '../content/model.dart';
import '../settings/reading_language.dart';

/// Queries shorter than this (after folding, in characters) find nothing.
const searchMinLength = 2;

const _foldTable = <String, String>{
  'ā': 'a',
  'ī': 'i',
  'ū': 'u',
  'ṅ': 'n',
  'ñ': 'n',
  'ṭ': 't',
  'ḍ': 'd',
  'ṇ': 'n',
  'ḷ': 'l',
  'ṃ': 'm',
  'ṁ': 'm',
  'ś': 's',
  'ṣ': 's',
  'ṛ': 'r',
  'Ā': 'a',
  'Ī': 'i',
  'Ū': 'u',
  'Ṅ': 'n',
  'Ñ': 'n',
  'Ṭ': 't',
  'Ḍ': 'd',
  'Ṇ': 'n',
  'Ḷ': 'l',
  'Ṃ': 'm',
  'Ṁ': 'm',
  'Ś': 's',
  'Ṣ': 's',
  'Ṛ': 'r',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ç': 'c',
  'À': 'a',
  'Á': 'a',
  'Â': 'a',
  'Ã': 'a',
  'Ä': 'a',
  'Å': 'a',
  'È': 'e',
  'É': 'e',
  'Ê': 'e',
  'Ë': 'e',
  'Ì': 'i',
  'Í': 'i',
  'Î': 'i',
  'Ï': 'i',
  'Ò': 'o',
  'Ó': 'o',
  'Ô': 'o',
  'Õ': 'o',
  'Ö': 'o',
  'Ù': 'u',
  'Ú': 'u',
  'Û': 'u',
  'Ü': 'u',
  'Ý': 'y',
  'Ç': 'c',
};

final _joiners = RegExp('[‍‌]');
final _whitespace = RegExp(r'\s+');

/// Lower-cases, maps Latin letters with diacritics to their base letters,
/// removes zero-width joiners, collapses whitespace and trims. Sinhala letters
/// are left as they are.
String foldForSearch(String s) {
  final b = StringBuffer();
  for (final ch in s.replaceAll(_joiners, '').split('')) {
    b.write(_foldTable[ch] ?? ch.toLowerCase());
  }
  return b.toString().replaceAll(_whitespace, ' ').trim();
}

class SearchHit {
  const SearchHit({
    required this.category,
    required this.reading,
    required this.section,
    this.line,
    this.lineLanguage,
    this.lineLanguageChosen = false,
  });

  final Category category;
  final Reading reading;
  final Section section;

  /// The stored line that matched, or null when only a title or heading did.
  final String? line;
  final ReadingLanguage? lineLanguage;
  final bool lineLanguageChosen;
}

typedef _Field = (ReadingLanguage, String? Function(Verse));

String? _paliSi(Verse v) => v.paliSi;
String? _paliRoman(Verse v) => v.paliRoman;
String? _sinhala(Verse v) => v.sinhala;
String? _english(Verse v) => v.english;

_Field _fieldsOf(ReadingLanguage l, int i) => switch (l) {
  ReadingLanguage.sinhala => (l, _sinhala),
  ReadingLanguage.english => (l, _english),
  ReadingLanguage.pali => (l, i == 0 ? _paliSi : _paliRoman),
};

/// The text fields to look in, in order: chosen languages in chosen order,
/// then Pali, Sinhala, English; Pali is the Sinhala-letter text then Roman.
List<_Field> _fieldOrder(LanguageSelection selection) {
  final langs = <ReadingLanguage>[
    ...selection.languages,
    for (final l in [
      ReadingLanguage.pali,
      ReadingLanguage.sinhala,
      ReadingLanguage.english,
    ])
      if (!selection.has(l)) l,
  ];
  return [
    for (final l in langs)
      if (l == ReadingLanguage.pali) ...[
        _fieldsOf(l, 0),
        _fieldsOf(l, 1),
      ] else
        _fieldsOf(l, 0),
  ];
}

bool _has(String? text, String q) =>
    text != null && foldForSearch(text).contains(q);

/// One hit per matching section, in content order. Plain "contains" on folded
/// text; the query is never used as a pattern.
List<SearchHit> searchLibrary(
  Library library,
  String query,
  LanguageSelection selection,
) {
  final q = foldForSearch(query);
  if (q.runes.length < searchMinLength) return const [];
  final fields = _fieldOrder(selection);
  final hits = <SearchHit>[];
  for (final c in library.categories) {
    final categoryMatch = _has(c.title, q) || _has(c.subtitle, q);
    for (final r in c.readings) {
      final readingMatch = categoryMatch || _has(r.title, q);
      for (final s in r.sections) {
        final (line, language) = _verseLine(s, q, fields);
        if (!readingMatch && !_has(s.heading, q) && line == null) {
          continue;
        }
        hits.add(
          SearchHit(
            category: c,
            reading: r,
            section: s,
            line: line,
            lineLanguage: language,
            lineLanguageChosen: language != null && selection.has(language),
          ),
        );
      }
    }
  }
  return hits;
}

(String?, ReadingLanguage?) _verseLine(
  Section s,
  String q,
  List<_Field> fields,
) {
  for (final (language, get) in fields) {
    for (final v in s.verses) {
      final text = get(v);
      if (text == null || !_has(text, q)) continue;
      final lines = text.split('\n');
      for (final l in lines) {
        if (foldForSearch(l).contains(q)) return (l.trim(), language);
      }
      return (lines.first.trim(), language);
    }
  }
  return (null, null);
}
