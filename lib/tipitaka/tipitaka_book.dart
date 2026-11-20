/// A Tripitaka book file and the readings cut from it (see the design's
/// "Reading spans, exactly"). The text is kept exactly as the source gives it.
library;

import 'tipitaka_tree.dart';

enum EntryType { centered, heading, paragraph, gatha, unindented }

EntryType _entryType(Object? name) => switch (name) {
  'centered' => EntryType.centered,
  'heading' => EntryType.heading,
  'gatha' => EntryType.gatha,
  'unindented' => EntryType.unindented,
  _ => EntryType.paragraph,
};

class TipitakaEntry {
  const TipitakaEntry({
    required this.type,
    required this.text,
    required this.level,
    required this.page,
  });

  final EntryType type;
  final String text;
  final int? level;

  /// Index of the page in the book's `pages` list.
  final int page;
}

class TipitakaBook {
  TipitakaBook._(this.file, this.pali, this.sinhala, this._pageStarts,
      this._paliNotes, this._sinhalaNotes);

  /// [json] is a decoded book file. Throws [FormatException] if it is not
  /// one.
  factory TipitakaBook.parse(String file, Object? json) {
    if (json is! Map) throw FormatException('$file: not a book');
    final pages = json['pages'];
    if (pages is! List) throw FormatException('$file: no pages');
    final pali = <TipitakaEntry>[];
    final sinhala = <TipitakaEntry?>[];
    final starts = <int>[];
    final paliNotes = <List<String>>[];
    final sinhalaNotes = <List<String>>[];
    for (var p = 0; p < pages.length; p++) {
      final page = pages[p];
      if (page is! Map) throw FormatException('$file: page $p is not an object');
      final paliSide = page['pali'];
      if (paliSide is! Map) throw FormatException('$file: page $p has no pali');
      final sinhSide = page['sinh'];
      final paliEntries = _entries(file, p, paliSide['entries']);
      final sinhEntries = sinhSide is Map && sinhSide['entries'] != null
          ? _entries(file, p, sinhSide['entries'])
          : const <TipitakaEntry>[];
      starts.add(pali.length);
      pali.addAll(paliEntries);
      final paired = sinhEntries.length == paliEntries.length;
      for (var i = 0; i < paliEntries.length; i++) {
        final s = paired ? sinhEntries[i] : null;
        sinhala.add(s == null || s.text.trim().isEmpty ? null : s);
      }
      paliNotes.add(_notes(paliSide['footnotes']));
      sinhalaNotes.add(
          sinhSide is Map ? _notes(sinhSide['footnotes']) : const <String>[]);
    }
    return TipitakaBook._(file, List.unmodifiable(pali),
        List.unmodifiable(sinhala), starts, paliNotes, sinhalaNotes);
  }

  final String file;

  /// All pages, flattened in page order.
  final List<TipitakaEntry> pali;

  /// Same length as [pali]; null where the page's two lists differ in length
  /// or the Sinhala text is blank.
  final List<TipitakaEntry?> sinhala;

  final List<int> _pageStarts;
  final List<List<String>> _paliNotes;
  final List<List<String>> _sinhalaNotes;

  /// The footnote texts of a page, in the source's order.
  List<String> footnotes(int page, {required bool pali}) {
    final notes = pali ? _paliNotes : _sinhalaNotes;
    if (page < 0 || page >= notes.length) return const [];
    return List.unmodifiable(notes[page]);
  }

  /// Index into [pali] of [entry] on [page]; -1 if there is no such entry.
  int flatIndex(int page, int entry) {
    if (page < 0 || page >= _pageStarts.length || entry < 0) return -1;
    final end = page + 1 < _pageStarts.length
        ? _pageStarts[page + 1]
        : pali.length;
    final index = _pageStarts[page] + entry;
    return index < end ? index : -1;
  }

  static List<TipitakaEntry> _entries(String file, int page, Object? list) {
    if (list is! List) {
      throw FormatException('$file: page $page has no entry list');
    }
    return [
      for (final e in list)
        if (e is Map && e['text'] is String)
          TipitakaEntry(
            type: _entryType(e['type']),
            text: e['text'] as String,
            level: e['level'] is int ? e['level'] as int : null,
            page: page,
          )
        else
          throw FormatException('$file: page $page has a broken entry'),
    ];
  }

  static List<String> _notes(Object? list) {
    if (list is! List) return const [];
    return [
      for (final n in list)
        if (n is String)
          n
        else if (n is Map && n['text'] is String)
          n['text'] as String
        else
          '', // keeps the numbering of the notes after it
    ];
  }
}

class TipitakaReading {
  const TipitakaReading({
    required this.key,
    required this.pali,
    required this.sinhala,
    required this.book,
  });

  final String key;
  final List<TipitakaEntry> pali;
  final List<TipitakaEntry?> sinhala;
  final TipitakaBook book;

  /// True when any entry has Sinhala.
  bool get hasSinhala => sinhala.any((e) => e != null);
}

/// The spec's display range: from the end of the previous reading's own span
/// in the file (or 0) to the start of the next node after [key] (or the end).
/// Null if [key] is not a reading or names another file.
TipitakaReading? readingOf(TipitakaTree tree, TipitakaBook book, String key) {
  final target = tree.node(key);
  if (target == null || !tree.isReading(key) || target.file != book.file) {
    return null;
  }
  final placed = <(String, int)>[];
  for (final n in tree.nodesInFile(book.file)) {
    final at = book.flatIndex(n.page, n.entry);
    if (at >= 0) placed.add((n.key, at));
  }
  var previousEnd = 0;
  for (var i = 0; i < placed.length; i++) {
    final (nodeKey, _) = placed[i];
    if (!tree.isReading(nodeKey)) continue;
    final end = i + 1 < placed.length ? placed[i + 1].$2 : book.pali.length;
    if (nodeKey == key) {
      final start = previousEnd <= end ? previousEnd : end;
      return TipitakaReading(
        key: key,
        pali: book.pali.sublist(start, end),
        sinhala: book.sinhala.sublist(start, end),
        book: book,
      );
    }
    previousEnd = end;
  }
  return null; // the node points past the end of the book
}
