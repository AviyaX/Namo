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

/// One phrase of a phrased verse: the three languages side by side.
class Phrase {
  const Phrase({
    required this.pali,
    required this.sinhala,
    required this.english,
  });

  factory Phrase.fromJson(Map<String, dynamic> json) => Phrase(
    pali: json['pali'] as String? ?? '',
    sinhala: json['sinhala'] as String? ?? '',
    english: json['english'] as String? ?? '',
  );

  final String pali, sinhala, english;

  String text(ReadingLanguage l) => switch (l) {
    ReadingLanguage.sinhala => sinhala,
    ReadingLanguage.english => english,
    ReadingLanguage.pali => pali,
  };
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
    this.phrases = const [],
    this.keepLines = false,
    this.alwaysShown = false,
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
    phrases: [
      for (final p in (json['phrases'] as List?) ?? const [])
        Phrase.fromJson(p as Map<String, dynamic>),
    ],
    keepLines: json['keep_lines'] == true,
    alwaysShown: json['always_shown'] == true,
  );

  final String id;
  final String? paliSi, paliRoman, sinhala, english;
  final SourceRecord? englishSource;
  final EnglishKind? englishKind;
  final CheckStatus check;
  final List<String> notes;
  final List<Correction> corrections;

  /// The phrases of a pirith block; empty for an ordinary verse, whose text
  /// is in the single fields above.
  final List<Phrase> phrases;

  /// True when each line of the text is shown on a line of its own.
  final bool keepLines;

  /// True when the verse is shown whichever languages are chosen.
  final bool alwaysShown;

  bool get isPhrased => phrases.isNotEmpty;

  /// This verse under [id]; every other field is the identical object.
  Verse withId(String id) => Verse(
    id: id,
    paliSi: paliSi,
    paliRoman: paliRoman,
    sinhala: sinhala,
    english: english,
    englishSource: englishSource,
    englishKind: englishKind,
    check: check,
    notes: notes,
    corrections: corrections,
    phrases: phrases,
    keepLines: keepLines,
    alwaysShown: alwaysShown,
  );

  /// The text in [l], or null when it is missing or blank. "Pali" is the
  /// Sinhala-letter Pali; Roman Pali is stored but not shown.
  String? text(ReadingLanguage l) => switch (l) {
    ReadingLanguage.sinhala => sinhala,
    ReadingLanguage.english => english,
    ReadingLanguage.pali => paliSi,
  };
}

/// When one block of a pirith is chanted in its recording.
class BlockTime {
  const BlockTime(this.start, this.end);

  final Duration start, end;

  @override
  bool operator ==(Object other) =>
      other is BlockTime && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'BlockTime($start, $end)';
}

Duration _seconds(num s) => Duration(microseconds: (s * 1000000).round());

class RecordingInfo {
  const RecordingInfo({
    required this.asset,
    required this.label,
    this.sectionCues = const {},
    this.blockTimes = const [],
    this.lineTimes = const [],
    this.duration,
  });

  factory RecordingInfo.fromJson(Map<String, dynamic> json) => RecordingInfo(
    asset: json['asset'] as String,
    label: json['label'] as String? ?? '',
    duration: json['duration_ms'] == null
        ? null
        : Duration(microseconds: ((json['duration_ms'] as num) * 1000).round()),
    blockTimes: [
      for (final t in (json['block_times'] as List?) ?? const [])
        t == null
            ? null
            : BlockTime(
                _seconds((t as List)[0] as num),
                _seconds(t[1] as num),
              ),
    ],
    lineTimes: [
      for (final block in (json['line_times'] as List?) ?? const [])
        [
          for (final t in (block as List))
            t == null ? null : _seconds(t as num),
        ],
    ],
  );

  final String asset, label;
  final Map<String, Duration> sectionCues;

  /// One entry per block of the reading; null where the block has no time.
  final List<BlockTime?> blockTimes;

  /// One list per block, one start per line of the block; null where a line
  /// has no time. Empty when the recording is timed by block only.
  final List<List<Duration?>> lineTimes;
  final Duration? duration;
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
    final have = verses.where((v) => v.isPhrased || v.text(l) != null).length;
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
    this.titleRoman,
  });

  factory Reading.fromJson(Map<String, dynamic> json) => Reading(
    id: json['id'] as String,
    title: json['title'] as String,
    titleRoman: json['title_roman'] as String?,
    audio: json['audio'] == null
        ? null
        : RecordingInfo.fromJson(json['audio'] as Map<String, dynamic>),
    sections: [
      for (final s in json['sections'] as List)
        Section.fromJson(s as Map<String, dynamic>),
    ],
  );

  final String id;
  final String title;
  final List<Section> sections;

  /// The Roman Pali name, for pirith.
  final String? titleRoman;

  /// Null when the reading has no recording.
  final RecordingInfo? audio;

  /// True when every verse of every section is phrased (and there is one).
  bool get isPhrased {
    final verses = [for (final s in sections) ...s.verses];
    return verses.isNotEmpty && verses.every((v) => v.isPhrased);
  }
}

class Category {
  const Category({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.readings,
    this.shortTitle,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    shortTitle: json['short_title'] as String?,
    readings: [
      for (final r in json['readings'] as List)
        Reading.fromJson(r as Map<String, dynamic>),
    ],
  );

  final String id;
  final String title;
  final String subtitle;

  /// A shorter name for narrow places such as a chip; null when the title is short enough.
  final String? shortTitle;
  final List<Reading> readings;

  /// The 1-based position of the reading in this category; 0 if absent.
  int numberOf(String readingId) =>
      readings.indexWhere((r) => r.id == readingId) + 1;
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
