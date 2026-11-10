import 'reader_items.dart';

/// Which item is at the top of the reader and how far into it (0–1) the
/// page is. A verse is named rather than one language's text of it, so the
/// place survives a change of languages or layout.
class ReadingPosition {
  const ReadingPosition({
    required this.readingId,
    required this.sectionId,
    this.verseId,
    required this.fraction,
  });

  final String readingId, sectionId;

  /// Null when a section heading is at the top.
  final String? verseId;
  final double fraction;

  Map<String, dynamic> toJson() => {
    'readingId': readingId,
    'sectionId': sectionId,
    if (verseId != null) 'verseId': verseId,
    'fraction': fraction,
  };

  /// Null unless both ids are strings; a damaged verse id is dropped and a
  /// damaged fraction is 0 (out-of-range ones are clamped).
  static ReadingPosition? fromJson(Object? json) {
    if (json is! Map) return null;
    final readingId = json['readingId'], sectionId = json['sectionId'];
    if (readingId is! String || sectionId is! String) return null;
    final verseId = json['verseId'];
    final fraction = json['fraction'];
    return ReadingPosition(
      readingId: readingId,
      sectionId: sectionId,
      verseId: verseId is String ? verseId : null,
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
  return ReadingPosition(
    readingId: readingId,
    sectionId: items[i].sectionId,
    verseId: items[i].verseId,
    fraction: fraction,
  );
}

/// The scroll offset that brings [position] back to the top: the first text
/// of its verse; else its section's heading; else 0. Clamped to the page.
double offsetForPosition({
  required ReadingPosition position,
  required List<ReaderItem> items,
  required List<({double top, double height})> extents,
  required double maxScrollExtent,
}) {
  if (extents.length != items.length) return 0;
  var offset = 0.0;
  final verse = position.verseId == null
      ? -1
      : items.indexWhere(
          (i) => i is VerseTextItem && i.verseId == position.verseId,
        );
  if (verse >= 0) {
    offset = extents[verse].top + position.fraction * extents[verse].height;
  } else {
    final heading = items.indexWhere(
      (i) => i is HeadingItem && i.sectionId == position.sectionId,
    );
    if (heading >= 0) offset = extents[heading].top;
  }
  return offset.clamp(0.0, maxScrollExtent < 0 ? 0.0 : maxScrollExtent);
}

/// How far through the page [offset] is, 0–1; 0 for a page that does not
/// scroll.
double progressOf(double offset, double maxScrollExtent) {
  if (maxScrollExtent <= 0) return 0;
  return (offset / maxScrollExtent).clamp(0.0, 1.0);
}
