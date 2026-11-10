import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_repository.dart';
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

/// A language's folded text and original text of a verse.
typedef _Field = (
  ReadingLanguage,
  String? Function(_FoldedVerse),
  String? Function(Verse),
);

_Field _fieldsOf(ReadingLanguage l, int i) => switch (l) {
  ReadingLanguage.sinhala => (l, (f) => f.sinhala, (v) => v.sinhala),
  ReadingLanguage.english => (l, (f) => f.english, (v) => v.english),
  ReadingLanguage.pali =>
    i == 0
        ? (l, (f) => f.paliSi, (v) => v.paliSi)
        : (l, (f) => f.paliRoman, (v) => v.paliRoman),
};

/// The languages in search order: chosen ones in chosen order, then Pali,
/// Sinhala, English.
List<ReadingLanguage> _languageOrder(LanguageSelection selection) => [
  ...selection.languages,
  for (final l in [
    ReadingLanguage.pali,
    ReadingLanguage.sinhala,
    ReadingLanguage.english,
  ])
    if (!selection.has(l)) l,
];

/// The text fields to look in, in order; Pali is the Sinhala-letter text
/// then Roman.
List<_Field> _fieldOrder(LanguageSelection selection) => [
  for (final l in _languageOrder(selection))
    if (l == ReadingLanguage.pali) ...[
      _fieldsOf(l, 0),
      _fieldsOf(l, 1),
    ] else
      _fieldsOf(l, 0),
];

/// A verse with its searchable texts folded once.
class _FoldedVerse {
  _FoldedVerse(Verse v)
    : paliSi = _foldOrNull(v.paliSi),
      paliRoman = _foldOrNull(v.paliRoman),
      sinhala = _foldOrNull(v.sinhala),
      english = _foldOrNull(v.english);

  final String? paliSi, paliRoman, sinhala, english;
}

/// A phrase with its three texts folded once.
class _FoldedPhrase {
  _FoldedPhrase(Phrase p)
    : pali = foldForSearch(p.pali),
      sinhala = foldForSearch(p.sinhala),
      english = foldForSearch(p.english);

  final String pali, sinhala, english;

  String of(ReadingLanguage l) => switch (l) {
    ReadingLanguage.sinhala => sinhala,
    ReadingLanguage.english => english,
    ReadingLanguage.pali => pali,
  };
}

String? _foldOrNull(String? s) => s == null ? null : foldForSearch(s);

class _FoldedSection {
  _FoldedSection(this.section)
    : heading = foldForSearch(section.heading),
      verses = [for (final v in section.verses) _FoldedVerse(v)];

  final Section section;
  final String heading;
  final List<_FoldedVerse> verses;
}

class _FoldedReading {
  _FoldedReading(this.reading)
    : title = foldForSearch(reading.title),
      titleRoman = _foldOrNull(reading.titleRoman),
      phrased = reading.isPhrased,
      sections = [for (final s in reading.sections) _FoldedSection(s)],
      phrases = [
        for (final s in reading.sections)
          for (final v in s.verses)
            for (final p in v.phrases) (p, _FoldedPhrase(p)),
      ];

  final Reading reading;
  final String title;
  final String? titleRoman;
  final bool phrased;
  final List<_FoldedSection> sections;
  final List<(Phrase, _FoldedPhrase)> phrases;
}

class _FoldedCategory {
  _FoldedCategory(this.category)
    : title = foldForSearch(category.title),
      subtitle = foldForSearch(category.subtitle),
      readings = [for (final r in category.readings) _FoldedReading(r)];

  final Category category;
  final String title, subtitle;
  final List<_FoldedReading> readings;
}

/// The library's searchable text, folded once when this is built, so that
/// each search only looks for the folded query in ready text.
class SearchIndex {
  SearchIndex(Library library)
    : _categories = [for (final c in library.categories) _FoldedCategory(c)] {
    builds++;
  }

  /// How many indexes were built; for tests.
  @visibleForTesting
  static int builds = 0;

  final List<_FoldedCategory> _categories;

  /// One hit per matching section, in content order; for a pirith, one hit
  /// per pirith. Plain "contains" on folded text; the query is never used as
  /// a pattern.
  List<SearchHit> search(String query, LanguageSelection selection) {
    final q = foldForSearch(query);
    if (q.runes.length < searchMinLength) return const [];
    final order = _languageOrder(selection);
    final fields = _fieldOrder(selection);
    final hits = <SearchHit>[];
    for (final c in _categories) {
      final categoryMatch = c.title.contains(q) || c.subtitle.contains(q);
      for (final r in c.readings) {
        if (r.phrased) {
          final hit = _pirithHit(c, r, q, order, selection, categoryMatch);
          if (hit != null) hits.add(hit);
          continue;
        }
        final readingMatch = categoryMatch || r.title.contains(q);
        for (final s in r.sections) {
          final (line, language) = _verseLine(s, q, fields);
          if (!readingMatch && !s.heading.contains(q) && line == null) {
            continue;
          }
          hits.add(
            SearchHit(
              category: c.category,
              reading: r.reading,
              section: s.section,
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

  SearchHit? _pirithHit(
    _FoldedCategory c,
    _FoldedReading r,
    String q,
    List<ReadingLanguage> order,
    LanguageSelection selection,
    bool categoryMatch,
  ) {
    String? line;
    ReadingLanguage? language;
    outer:
    for (final l in order) {
      for (final (phrase, folded) in r.phrases) {
        if (!folded.of(l).contains(q)) continue;
        language = l;
        final text = phrase.text(l);
        final lines = text.split('\n');
        line = (lines.firstWhere(
          (x) => foldForSearch(x).contains(q),
          orElse: () => lines.first,
        )).trim();
        break outer;
      }
    }
    final named =
        categoryMatch ||
        r.title.contains(q) ||
        (r.titleRoman?.contains(q) ?? false);
    if (!named && line == null) return null;
    return SearchHit(
      category: c.category,
      reading: r.reading,
      section: r.reading.sections.first,
      line: line,
      lineLanguage: language,
      lineLanguageChosen: language != null && selection.has(language),
    );
  }

  (String?, ReadingLanguage?) _verseLine(
    _FoldedSection s,
    String q,
    List<_Field> fields,
  ) {
    for (final (language, folded, original) in fields) {
      for (var i = 0; i < s.verses.length; i++) {
        final f = folded(s.verses[i]);
        if (f == null || !f.contains(q)) continue;
        final text = original(s.section.verses[i])!;
        final lines = text.split('\n');
        for (final l in lines) {
          if (foldForSearch(l).contains(q)) return (l.trim(), language);
        }
        return (lines.first.trim(), language);
      }
    }
    return (null, null);
  }
}

/// One hit per matching section, in content order. A thin wrapper that builds
/// an index for one search; the Library screen keeps one in a provider.
List<SearchHit> searchLibrary(
  Library library,
  String query,
  LanguageSelection selection,
) => SearchIndex(library).search(query, selection);

/// The index of the loaded library; null until it has loaded.
final searchIndexProvider = Provider<SearchIndex?>((ref) {
  final library = ref.watch(libraryProvider).value;
  return library == null ? null : SearchIndex(library);
});
