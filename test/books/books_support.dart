/// A made-up pair of books for tests, so no test reads the real bundle.
/// All text is made-up ASCII, not Dhamma text.
library;

const tinyBookFlatId = 'tiny-flat';
const tinyBookNestedId = 'tiny-nested';
const tinyBooksIndexPath = 'assets/books/index.json';
const tinyBookCover = 'assets/branding/namo_icon_square.png';
String tinyBookFile(String id) => 'assets/books/$id.json.gz';

/// The nested book's 60-character title, for two-line ellipsis tests.
const tinyLongTitle =
    'A rather longer made-up page title that wraps over two lines';

Map<String, Object?> _page(
  int n,
  String key,
  int level,
  String title,
  List<Map<String, Object?>> blocks,
) => {
  'n': n,
  'key': key,
  'level': level,
  'title': title,
  'url': 'https://example.invalid/book/$key.html',
  'blocks': blocks,
};

Map<String, Object?> _para(String text) => {'kind': 'para', 'text': text};

Map<String, Object?> _book(
  String id,
  String title,
  String? subtitle,
  List<Map<String, Object?>> pages,
) => {
  'id': id,
  'title': title,
  'subtitle': subtitle,
  'source': {
    'url': 'https://example.invalid/book/index.html',
    'fetched': '2026-01-02',
  },
  'pages': pages,
};

/// Three pages, all with text: front, "1", "2".
Map<String, Object?> tinyBookFlat() =>
    _book(tinyBookFlatId, 'Flat book', null, [
      _page(1, 'front', 1, 'About this book', [_para('Front text.')]),
      _page(2, '1', 1, 'Flat one', [_para('Flat one text.')]),
      _page(3, '2', 1, 'Flat two', [_para('Flat two text.')]),
    ]);

/// front; "1" (text) with "1-1" and "1-2"; "2" (no text) with "2-1", which
/// has "2-1-1" at level 3. Every block kind appears once or more.
Map<String, Object?> tinyBookNested() =>
    _book(tinyBookNestedId, 'Nested book', 'A made-up subtitle', [
      _page(1, 'front', 1, 'About this book', [_para('Nested front text.')]),
      _page(2, '1', 1, 'Part one', [_para('Part one text.')]),
      _page(3, '1-1', 2, tinyLongTitle, [
        _para('One one text.'),
        {
          'kind': 'gatha',
          'lines': ['Verse line one', 'Verse line two'],
        },
        {'kind': 'heading', 'text': 'A heading'},
        _para('After the heading.'),
      ]),
      _page(4, '1-2', 2, 'One two', [
        {
          'kind': 'list',
          'marker': 'number',
          'start': 3,
          'items': ['Third item', 'Fourth item'],
        },
        {
          'kind': 'list',
          'marker': 'none',
          'start': 1,
          'items': ['(a) Lettered item', '(b) Another'],
        },
        {
          'kind': 'footnotes',
          'items': ['Note one.', 'Note two.'],
        },
      ]),
      _page(5, '2', 1, 'Part two', []),
      _page(6, '2-1', 2, 'Two one', [_para('Two one text.')]),
      _page(7, '2-1-1', 3, 'Two one one', [
        {'kind': 'subhead', 'text': 'A subhead'},
        {
          'kind': 'list',
          'marker': 'bullet',
          'start': 1,
          'items': ['Bullet one', 'Bullet two'],
        },
        {
          'kind': 'table',
          'header': true,
          'rows': [
            ['Name', 'Count'],
            ['Apples', '3'],
          ],
        },
        {
          'kind': 'image',
          'src': 'https://example.invalid/picture.png',
          'alt': 'A made-up picture',
        },
      ]),
    ]);

Map<String, Object?> _summary(
  String id,
  String title,
  String? subtitle,
  int chapters,
  int pages,
) => {
  'id': id,
  'title': title,
  'subtitle': subtitle,
  'chapters': chapters,
  'pages': pages,
  'file': tinyBookFile(id),
  'bytes': 100,
  'sha256': '0' * 64,
  'cover': tinyBookCover,
  'cover_source': 'https://example.invalid/cover.png',
};

/// A 140-character made-up sentence: a table cell that must wrap.
const tinyLongCell =
    'A made-up table cell with one long sentence in it, long enough that it '
    'has to wrap over more than one line in the reading column at any size';

/// The title of the extra page [tinyBooksWithLongBlocks] adds.
const tinyLongBlocksTitle = 'Long lists';

/// [tinyBooks] with one more page at the end of the nested book: "3" (n 8),
/// a list numbered 1 to 12 ("Item 1" ...), twelve footnotes ("Note 1" ...)
/// and a two-column table whose second cell is [tinyLongCell].
Map<String, Object> tinyBooksWithLongBlocks() {
  final all = tinyBooks();
  final nested = tinyBookNested();
  nested['pages'] = [
    ...nested['pages']! as List,
    _page(8, '3', 1, tinyLongBlocksTitle, [
      {
        'kind': 'list',
        'marker': 'number',
        'start': 1,
        'items': [for (var i = 1; i <= 12; i++) 'Item $i'],
      },
      {
        'kind': 'footnotes',
        'items': [for (var i = 1; i <= 12; i++) 'Note $i'],
      },
      {
        'kind': 'table',
        'header': false,
        'rows': [
          ['Short', tinyLongCell],
        ],
      },
    ]),
  ];
  all[tinyBookFile(tinyBookNestedId)] = nested;
  final index = Map<String, Object?>.of(
    all[tinyBooksIndexPath]! as Map<String, Object?>,
  );
  index['books'] = [
    _summary(tinyBookFlatId, 'Flat book', null, 2, 3),
    _summary(tinyBookNestedId, 'Nested book', 'A made-up subtitle', 3, 7),
  ];
  all[tinyBooksIndexPath] = index;
  return all;
}

/// An index with no books: a Library without a shelf.
Map<String, Object> noBooks() => {
  tinyBooksIndexPath: {
    'schema': 1,
    'source': {
      'name': 'example',
      'url': 'https://example.invalid/books/',
      'fetched': '2026-01-02',
    },
    'books': <Object>[],
  },
};

/// The index and the two books, by asset path.
Map<String, Object> tinyBooks() => {
  tinyBooksIndexPath: {
    'schema': 1,
    'author': {'si': 'Made-up author', 'en': 'Made-up author'},
    'publisher': {'si': 'Made-up publisher', 'en': 'Made-up publisher'},
    'source': {
      'name': 'example',
      'url': 'https://example.invalid/books/',
      'fetched': '2026-01-02',
    },
    'books': [
      _summary(tinyBookFlatId, 'Flat book', null, 2, 3),
      _summary(tinyBookNestedId, 'Nested book', 'A made-up subtitle', 2, 6),
    ],
  },
  tinyBookFile(tinyBookFlatId): tinyBookFlat(),
  tinyBookFile(tinyBookNestedId): tinyBookNested(),
};
