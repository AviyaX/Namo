import '../settings/reading_language.dart';

enum CheckStatus {
  unchecked,
  checkedAgainstSource,
  needsChecking;

  /// The strings are the ones `tools/build_content.py` writes.
  static CheckStatus parse(Object? s) => switch (s) {
    'checked against source' => checkedAgainstSource,
    'needs checking' => needsChecking,
    _ => unchecked,
  };
}

enum EnglishKind {
  translation,
  explanation;

  static EnglishKind? parse(Object? s) => switch (s) {
    'translation' => translation,
    'explanation' => explanation,
    _ => null,
  };
}

enum LanguageCover { all, part, none }

class SourceRecord {
  const SourceRecord({
    required this.name,
    required this.locator,
    required this.collected,
    required this.translator,
  });

  factory SourceRecord.fromJson(Map<String, dynamic> json) => SourceRecord(
    name: json['name'] as String? ?? '',
    locator: json['locator'] as String? ?? '',
    collected: json['collected'] as String? ?? '',
    translator: json['translator'] as String? ?? '',
  );

  final String name, locator, collected, translator;
}

class Correction {
  const Correction({
    required this.field,
    required this.from,
    required this.to,
    required this.reason,
    required this.count,
  });

  factory Correction.fromJson(Map<String, dynamic> json) => Correction(
    field: json['field'] as String? ?? '',
    from: json['from'] as String? ?? '',
    to: json['to'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
    count: json['count'] as int? ?? 1,
  );

  final String field, from, to, reason;
  final int count;
}

List<Correction> _corrections(Object? json) => [
  for (final c in (json as List?) ?? const [])
    Correction.fromJson(c as Map<String, dynamic>),
];

String? _text(Object? s) {
  if (s is! String || s.trim().isEmpty) return null;
  return s;
}

class Verse {
  const Verse({
    required this.id,
    this.paliSi,
    this.paliRoman,
    this.sinhala,
    this.english,
    this.englishSource,
    this.englishKind,
    this.check = CheckStatus.unchecked,
    this.notes = const [],
    this.corrections = const [],
  });

  factory Verse.fromJson(Map<String, dynamic> json) => Verse(
    id: json['id'] as String,
    paliSi: _text(json['pali_si']),
    paliRoman: _text(json['pali_roman']),
    sinhala: _text(json['sinhala']),
    english: _text(json['english']),
    englishSource: json['english_source'] == null
        ? null
        : SourceRecord.fromJson(json['english_source'] as Map<String, dynamic>),
    englishKind: EnglishKind.parse(json['english_kind']),
    check: CheckStatus.parse(json['check']),
    notes: [for (final n in (json['notes'] as List?) ?? const []) n as String],
    corrections: _corrections(json['corrections']),
  );

  final String id;
  final String? paliSi, paliRoman, sinhala, english;
  final SourceRecord? englishSource;
  final EnglishKind? englishKind;
  final CheckStatus check;
  final List<String> notes;
  final List<Correction> corrections;

  /// The text in [l], or null when it is missing or blank. "Pali" is the
  /// Sinhala-letter Pali; Roman Pali is stored but not shown.
  String? text(ReadingLanguage l) => switch (l) {
    ReadingLanguage.sinhala => sinhala,
    ReadingLanguage.english => english,
    ReadingLanguage.pali => paliSi,
  };
}

class RecordingInfo {
  const RecordingInfo({
    required this.asset,
    required this.label,
    this.sectionCues = const {},
  });

  final String asset, label;
  final Map<String, Duration> sectionCues;
}

class Section {
  const Section({
    required this.id,
    required this.number,
    required this.heading,
    this.source = const SourceRecord(
      name: '',
      locator: '',
      collected: '',
      translator: '',
    ),
    this.check = CheckStatus.unchecked,
    this.corrections = const [],
    this.verses = const [],
  });

  factory Section.fromJson(Map<String, dynamic> json) => Section(
    id: json['id'] as String,
    number: json['number'] as int,
    heading: json['heading'] as String,
    source: json['source'] == null
        ? const SourceRecord(
            name: '',
            locator: '',
            collected: '',
            translator: '',
          )
        : SourceRecord.fromJson(json['source'] as Map<String, dynamic>),
    check: CheckStatus.parse(json['check']),
    corrections: _corrections(json['corrections']),
    verses: [
      for (final v in (json['verses'] as List?) ?? const [])
        Verse.fromJson(v as Map<String, dynamic>),
    ],
  );

  final String id;
  final int number;
  final String heading;
  final SourceRecord source;
  final CheckStatus check;
  final List<Correction> corrections;
  final List<Verse> verses;

  LanguageCover coverOf(ReadingLanguage l) {
    final have = verses.where((v) => v.text(l) != null).length;
    if (have == 0) return LanguageCover.none;
    return have == verses.length ? LanguageCover.all : LanguageCover.part;
  }
}

class Reading {
  const Reading({
    required this.id,
    required this.title,
    required this.sections,
    this.audio,
  });

  factory Reading.fromJson(Map<String, dynamic> json) => Reading(
    id: json['id'] as String,
    title: json['title'] as String,
    sections: [
      for (final s in json['sections'] as List)
        Section.fromJson(s as Map<String, dynamic>),
    ],
  );

  final String id;
  final String title;
  final List<Section> sections;

  /// Null in this release.
  final RecordingInfo? audio;
}

class Category {
  const Category({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.readings,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    readings: [
      for (final r in json['readings'] as List)
        Reading.fromJson(r as Map<String, dynamic>),
    ],
  );

  final String id;
  final String title;
  final String subtitle;
  final List<Reading> readings;
}

class Library {
  const Library({required this.categories});

  factory Library.fromJson(Map<String, dynamic> json) => Library(
    categories: [
      for (final c in json['categories'] as List)
        Category.fromJson(c as Map<String, dynamic>),
    ],
  );

  final List<Category> categories;

  Reading? reading(String id) {
    for (final c in categories) {
      for (final r in c.readings) {
        if (r.id == id) return r;
      }
    }
    return null;
  }

  Category? categoryOf(String readingId) {
    for (final c in categories) {
      if (c.readings.any((r) => r.id == readingId)) return c;
    }
    return null;
  }

  Category? category(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}
