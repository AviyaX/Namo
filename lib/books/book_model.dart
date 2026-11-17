/// The bundled books: the index (`assets/books/index.json`) and one book's
/// pages (`assets/books/<id>.json.gz`). See `tools/sync_books.py` for the
/// file shapes. The contents tree is not stored; it is derived from the
/// pages' levels.
library;

import 'package:flutter/foundation.dart';

Never _bad(String what) => throw FormatException('books: $what');

String _string(Map json, String key, String where) {
  final v = json[key];
  if (v is! String) _bad('$where: "$key" is not text');
  return v;
}

String? _optionalString(Map json, String key, String where) {
  final v = json[key];
  if (v != null && v is! String) _bad('$where: "$key" is not text');
  return v as String?;
}

int _int(Map json, String key, String where) {
  final v = json[key];
  if (v is! int) _bad('$where: "$key" is not a whole number');
  return v;
}

List<String> _strings(Object? json, String where) {
  if (json is! List || json.any((e) => e is! String)) {
    _bad('$where: not a list of text');
  }
  return List.unmodifiable(json.cast<String>());
}

/// One book as the index lists it.
@immutable
class BookSummary {
  const BookSummary({
    required this.id,
    required this.title,
    this.subtitle,
    required this.chapters,
    required this.pages,
    required this.file,
    required this.cover,
  });

  final String id, title;
  final String? subtitle;

  /// Level-1 pages, the front matter not counted.
  final int chapters;

  /// Reading pages (pages with text).
  final int pages;

  /// The book's asset path.
  final String file;

  /// The cover's asset path.
  final String cover;

  /// Throws [FormatException] if [json] is not a book summary.
  static BookSummary parse(Object? json) {
    if (json is! Map) _bad('index book: not an object');
    const where = 'index book';
    return BookSummary(
      id: _string(json, 'id', where),
      title: _string(json, 'title', where),
      subtitle: _optionalString(json, 'subtitle', where),
      chapters: _int(json, 'chapters', where),
      pages: _int(json, 'pages', where),
      file: _string(json, 'file', where),
      cover: _string(json, 'cover', where),
    );
  }
}

@immutable
class BooksIndex {
  const BooksIndex({required this.books, required this.fetched});

  /// In shelf order.
  final List<BookSummary> books;

  /// The day the text was fetched (yyyy-mm-dd).
  final String fetched;

  BookSummary? byId(String id) {
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Throws [FormatException] if [json] is not the books index.
  static BooksIndex parse(Object? json) {
    if (json is! Map) _bad('index: not an object');
    final source = json['source'], books = json['books'];
    if (source is! Map) _bad('index: no source');
    if (books is! List) _bad('index: "books" is not a list');
    return BooksIndex(
      books: List.unmodifiable(books.map(BookSummary.parse)),
      fetched: _string(source, 'fetched', 'index source'),
    );
  }
}

/// One block of a page's text.
@immutable
sealed class BookBlock {
  const BookBlock();

  /// Throws [FormatException] on an unknown `kind` or a bad shape.
  static BookBlock parse(Object? json) {
    if (json is! Map) _bad('block: not an object');
    final kind = json['kind'];
    final where = 'block "$kind"';
    return switch (kind) {
      'heading' => BookHeading(_string(json, 'text', where)),
      'subhead' => BookSubhead(_string(json, 'text', where)),
      'para' => BookPara(_string(json, 'text', where)),
      'gatha' => BookGatha(_strings(json['lines'], where)),
      'list' => BookList(
        marker: _marker(json['marker']),
        start: _int(json, 'start', where),
        items: _strings(json['items'], where),
      ),
      'footnotes' => BookFootnotes(_strings(json['items'], where)),
      'table' => BookTable(
        header: json['header'] is bool
            ? json['header'] as bool
            : _bad('$where: "header" is not true or false'),
        rows: json['rows'] is List
            ? List.unmodifiable([
                for (final r in json['rows'] as List) _strings(r, where),
              ])
            : _bad('$where: "rows" is not a list'),
      ),
      'image' => BookImage(
        src: _string(json, 'src', where),
        alt: _string(json, 'alt', where),
        asset: _optionalString(json, 'asset', where),
      ),
      _ => _bad('block: unknown kind "$kind"'),
    };
  }

  static ListMarker _marker(Object? json) {
    for (final m in ListMarker.values) {
      if (m.name == json) return m;
    }
    _bad('list: unknown marker "$json"');
  }
}

/// A heading inside the text (the page's own title is not repeated).
class BookHeading extends BookBlock {
  const BookHeading(this.text);
  final String text;
}

class BookSubhead extends BookBlock {
  const BookSubhead(this.text);
  final String text;
}

class BookPara extends BookBlock {
  const BookPara(this.text);
  final String text;
}

/// A verse, kept line by line.
class BookGatha extends BookBlock {
  const BookGatha(this.lines);
  final List<String> lines;
}

/// [none]: the labels are already in the item text.
enum ListMarker { number, bullet, none }

class BookList extends BookBlock {
  const BookList({
    required this.marker,
    required this.start,
    required this.items,
  });

  final ListMarker marker;

  /// The first item's number (for [ListMarker.number]).
  final int start;

  /// The item numbers are not in the text; the reader draws them.
  final List<String> items;
}

/// Drawn numbered from 1 at the foot of the page.
class BookFootnotes extends BookBlock {
  const BookFootnotes(this.items);
  final List<String> items;
}

class BookTable extends BookBlock {
  const BookTable({required this.header, required this.rows});

  /// Whether the first row is a header row.
  final bool header;
  final List<List<String>> rows;
}

class BookImage extends BookBlock {
  const BookImage({required this.src, required this.alt, this.asset});

  /// The picture's address on the website.
  final String src;
  final String alt;

  /// The bundled copy's asset path; null when the picture is not bundled
  /// (then the reader shows a caption naming it).
  final String? asset;
}

@immutable
class BookPage {
  const BookPage({
    required this.n,
    required this.key,
    required this.level,
    required this.title,
    required this.url,
    required this.blocks,
  });

  /// 1-based position in reading order.
  final int n;

  /// "front", or the website's page name ("3-2-1").
  final String key;

  /// 1 for the front matter and the chapters.
  final int level;
  final String title, url;
  final List<BookBlock> blocks;

  /// A page without text is a contents node only.
  bool get hasText => blocks.isNotEmpty;

  static BookPage _parse(Object? json, int expectedN) {
    if (json is! Map) _bad('page $expectedN: not an object');
    final where = 'page $expectedN';
    final n = _int(json, 'n', where);
    if (n != expectedN) _bad('$where: "n" is $n (out of order)');
    final level = _int(json, 'level', where);
    if (level < 1) _bad('$where: level $level');
    final blocks = json['blocks'];
    if (blocks is! List) _bad('$where: "blocks" is not a list');
    return BookPage(
      n: n,
      key: _string(json, 'key', where),
      level: level,
      title: _string(json, 'title', where),
      url: _string(json, 'url', where),
      blocks: List.unmodifiable(blocks.map(BookBlock.parse)),
    );
  }
}

class Book {
  const Book({
    required this.id,
    required this.title,
    this.subtitle,
    required this.pages,
  });

  final String id, title;
  final String? subtitle;

  /// In reading order; `pages[i].n == i + 1`.
  final List<BookPage> pages;

  /// Null when [n] is not a page.
  BookPage? page(int n) => n < 1 || n > pages.length ? null : pages[n - 1];

  /// The level-1 pages, the front matter included.
  List<BookPage> get topLevel => [
    for (final p in pages)
      if (p.level == 1) p,
  ];

  /// The pages after [n] one level deeper, up to the next page at [n]'s
  /// level or shallower.
  List<BookPage> childrenOf(int n) {
    final parent = page(n);
    if (parent == null) return const [];
    final children = <BookPage>[];
    for (final p in pages.skip(n)) {
      if (p.level <= parent.level) break;
      if (p.level == parent.level + 1) children.add(p);
    }
    return children;
  }

  /// The nearest earlier page one level up; null at level 1.
  BookPage? parentOf(int n) {
    final child = page(n);
    if (child == null) return null;
    for (var i = n - 2; i >= 0; i--) {
      final p = pages[i];
      if (p.level < child.level) {
        return p.level == child.level - 1 ? p : null;
      }
    }
    return null;
  }

  /// The pages with text, in order.
  List<BookPage> get readingPages => [
    for (final p in pages)
      if (p.hasText) p,
  ];

  /// 1-based position among [readingPages]; 0 when [n] is not one.
  int readingIndexOf(int n) {
    if (!(page(n)?.hasText ?? false)) return 0;
    var i = 0;
    for (final p in pages.take(n)) {
      if (p.hasText) i++;
    }
    return i;
  }

  /// The first reading page after [n], or null.
  int? nextReading(int n) {
    for (final p in pages.skip(n < 0 ? 0 : n)) {
      if (p.hasText) return p.n;
    }
    return null;
  }

  /// The last reading page before [n], or null.
  int? previousReading(int n) {
    final before = (n - 1).clamp(0, pages.length);
    for (var i = before - 1; i >= 0; i--) {
      if (pages[i].hasText) return pages[i].n;
    }
    return null;
  }

  /// [n] when it is a reading page, else the next one, else the previous.
  int? firstReadingFrom(int n) {
    if (page(n)?.hasText ?? false) return n;
    return nextReading(n) ?? previousReading(n);
  }

  /// Throws [FormatException] if [json] is not a book.
  static Book parse(Object? json) {
    if (json is! Map) _bad('book: not an object');
    final pages = json['pages'];
    if (pages is! List) _bad('book: "pages" is not a list');
    return Book(
      id: _string(json, 'id', 'book'),
      title: _string(json, 'title', 'book'),
      subtitle: _optionalString(json, 'subtitle', 'book'),
      pages: List.unmodifiable([
        for (var i = 0; i < pages.length; i++) BookPage._parse(pages[i], i + 1),
      ]),
    );
  }
}
