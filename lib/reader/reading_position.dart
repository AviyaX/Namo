import '../settings/reading_language.dart';
import 'reader_items.dart';

/// Which item is at the top of the reader and how far into it (0–1) the
/// page is. A verse and the language of its text are named rather than an
/// item's index, so the place survives a change of languages or layout.
class ReadingPosition {
  const ReadingPosition({
    required this.readingId,
    required this.sectionId,
    this.verseId,
    this.language,
    required this.fraction,
  });

  final String readingId, sectionId;

  /// Null when a section heading is at the top.
  final String? verseId;

  /// The language of the verse text at the top. Null when a heading is at
  /// the top, and in places saved before the language was stored.
  final ReadingLanguage? language;
  final double fraction;

  Map<String, dynamic> toJson() => {
    'readingId': readingId,
    'sectionId': sectionId,
    if (verseId != null) 'verseId': verseId,
    if (language != null) 'language': language!.code,
    'fraction': fraction,
  };

  /// Null unless both ids are strings; a damaged verse id or language is
  /// dropped and a damaged fraction is 0 (out-of-range ones are clamped).
  static ReadingPosition? fromJson(Object? json) {
    if (json is! Map) return null;
    final readingId = json['readingId'], sectionId = json['sectionId'];
    if (readingId is! String || sectionId is! String) return null;
    final verseId = json['verseId'];
    final language = json['language'];
    final fraction = json['fraction'];
    return ReadingPosition(
      readingId: readingId,
      sectionId: sectionId,
      verseId: verseId is String ? verseId : null,
      language: language is String ? ReadingLanguage.fromCode(language) : null,
      fraction: fraction is num && fraction.isFinite
          ? fraction.toDouble().clamp(0.0, 1.0)
          : 0,
    );
  }
}

/// The position at [scrollOffset]: the last item whose top is at or above
/// it. Null when [extents] do not describe [items] (not yet laid out).
ReadingPosition? capturePosition({
  required String readingId,
  required List<ReaderItem> items,
  required List<({double top, double height})> extents,
  required double scrollOffset,
}) {
  if (items.isEmpty || extents.length != items.length) return null;
  final index = extents.lastIndexWhere((e) => e.top <= scrollOffset);
  final i = index < 0 ? 0 : index;
  final e = extents[i];
  final fraction = e.height > 0
      ? ((scrollOffset - e.top) / e.height).clamp(0.0, 1.0)
      : 0.0;
  final item = items[i];
  return ReadingPosition(
    readingId: readingId,
    sectionId: item.sectionId,
    verseId: item.verseId,
    language: item is VerseTextItem ? item.language : null,
    fraction: fraction,
  );
}

/// The scroll offset that brings [position] back to the top: the text of
/// its verse in its language; else the first text of its verse; else its
/// section's heading (keeping the fraction only if the heading itself was
/// at the top); else 0. Clamped to the page.
double offsetForPosition({
  required ReadingPosition position,
  required List<ReaderItem> items,
  required List<({double top, double height})> extents,
  required double maxScrollExtent,
}) {
  if (extents.length != items.length) return 0;
  double at(int index, double fraction) =>
      extents[index].top + fraction * extents[index].height;

  var offset = 0.0;
  final verseId = position.verseId;
  final sameLanguage = verseId == null || position.language == null
      ? -1
      : items.indexWhere(
          (i) =>
              i is VerseTextItem &&
              i.verseId == verseId &&
              i.language == position.language,
        );
  final firstOfVerse = verseId == null
      ? -1
      : items.indexWhere((i) => i is VerseTextItem && i.verseId == verseId);
  final heading = items.indexWhere(
    (i) => i is HeadingItem && i.sectionId == position.sectionId,
  );
  if (sameLanguage >= 0) {
    offset = at(sameLanguage, position.fraction);
  } else if (firstOfVerse >= 0) {
    // An older save without a language, or the language is no longer
    // shown: the same share of the verse's first text.
    offset = at(firstOfVerse, position.fraction);
  } else if (heading >= 0) {
    offset = at(heading, verseId == null ? position.fraction : 0);
  }
  return offset.clamp(0.0, maxScrollExtent < 0 ? 0.0 : maxScrollExtent);
}

/// How far through the page [offset] is, 0–1; 0 for a page that does not
/// scroll.
double progressOf(double offset, double maxScrollExtent) {
  if (maxScrollExtent <= 0) return 0;
  return (offset / maxScrollExtent).clamp(0.0, 1.0);
}
