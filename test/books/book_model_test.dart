import 'package:buddhist_gatha/books/book_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'books_support.dart';

Book _nested() => Book.parse(tinyBooks()[tinyBookFile(tinyBookNestedId)]);

void main() {
  test('parses the index and every block kind', () {
    final index = BooksIndex.parse(tinyBooks()[tinyBooksIndexPath]);
    expect(index.fetched, '2026-01-02');
    expect(index.books.map((b) => b.id), [tinyBookFlatId, tinyBookNestedId]);
    final nested = index.byId(tinyBookNestedId)!;
    expect(nested.title, 'Nested book');
    expect(nested.subtitle, 'A made-up subtitle');
    expect(nested.chapters, 2);
    expect(nested.pages, 6);
    expect(nested.file, tinyBookFile(tinyBookNestedId));
    expect(nested.cover, tinyBookCover);
    expect(index.byId(tinyBookFlatId)!.subtitle, isNull);
    expect(index.byId('nope'), isNull);

    final book = _nested();
    expect(book.id, tinyBookNestedId);
    expect(book.title, 'Nested book');
    expect(book.subtitle, 'A made-up subtitle');
    expect(book.pages.length, 7);
    final front = book.page(1)!;
    expect(front.key, 'front');
    expect(front.level, 1);
    expect(front.title, 'About this book');
    expect(front.url, 'https://example.invalid/book/front.html');
    expect((front.blocks.single as BookPara).text, 'Nested front text.');

    final oneOne = book.page(3)!.blocks;
    expect(book.page(3)!.title.length, 60);
    expect((oneOne[1] as BookGatha).lines, [
      'Verse line one',
      'Verse line two',
    ]);
    expect((oneOne[2] as BookHeading).text, 'A heading');

    final oneTwo = book.page(4)!.blocks;
    final numbered = oneTwo[0] as BookList;
    expect(numbered.marker, ListMarker.number);
    expect(numbered.start, 3);
    expect(numbered.items, ['Third item', 'Fourth item']);
    expect((oneTwo[1] as BookList).marker, ListMarker.none);
    expect((oneTwo[2] as BookFootnotes).items, ['Note one.', 'Note two.']);

    final deep = book.page(7)!.blocks;
    expect((deep[0] as BookSubhead).text, 'A subhead');
    expect((deep[1] as BookList).marker, ListMarker.bullet);
    final table = deep[2] as BookTable;
    expect(table.header, isTrue);
    expect(table.rows, [
      ['Name', 'Count'],
      ['Apples', '3'],
    ]);
    final image = deep[3] as BookImage;
    expect(image.src, 'https://example.invalid/picture.png');
    expect(image.alt, 'A made-up picture');
    expect(image.asset, isNull);
    expect(
      (BookBlock.parse({
        'kind': 'image',
        'src': 's',
        'alt': 'a',
        'asset': 'assets/books/pictures/x.png',
      }) as BookImage).asset,
      'assets/books/pictures/x.png',
    );

    expect(book.page(0), isNull);
    expect(book.page(8), isNull);
  });

  test('the tree is derived from levels', () {
    final book = _nested();
    int n(String key) => book.pages.firstWhere((p) => p.key == key).n;
    List<String> keys(List<BookPage> pages) => [for (final p in pages) p.key];

    expect(keys(book.topLevel), ['front', '1', '2']);
    expect(keys(book.childrenOf(n('1'))), ['1-1', '1-2']);
    expect(keys(book.childrenOf(n('2'))), ['2-1']);
    expect(keys(book.childrenOf(n('2-1'))), ['2-1-1']);
    expect(book.childrenOf(n('1-1')), isEmpty);
    expect(book.childrenOf(n('front')), isEmpty);
    expect(book.childrenOf(99), isEmpty);
    expect(book.parentOf(n('2-1-1'))!.key, '2-1');
    expect(book.parentOf(n('1-2'))!.key, '1');
    expect(book.parentOf(n('2')), isNull);
    expect(book.parentOf(99), isNull);
  });

  test('reading navigation skips pages without text', () {
    final book = _nested();
    int n(String key) => book.pages.firstWhere((p) => p.key == key).n;

    expect(book.page(n('2'))!.hasText, isFalse);
    expect(book.page(n('2-1'))!.hasText, isTrue);
    expect(
      [for (final p in book.readingPages) p.key],
      ['front', '1', '1-1', '1-2', '2-1', '2-1-1'],
    );
    expect(book.nextReading(n('1-2')), n('2-1'));
    expect(book.previousReading(n('2-1')), n('1-2'));
    expect(book.nextReading(n('2-1-1')), isNull);
    expect(book.previousReading(n('front')), isNull);
    expect(book.firstReadingFrom(n('2')), n('2-1'));
    expect(book.firstReadingFrom(n('1-1')), n('1-1'));
    expect(book.readingIndexOf(n('front')), 1);
    expect(book.readingIndexOf(n('2-1')), 5);
    expect(book.readingIndexOf(n('2-1-1')), 6);
    expect(book.readingIndexOf(n('2')), 0);

    // A trailing page without text falls back to the one before it.
    final json = tinyBookNested();
    (json['pages']! as List).add({
      'n': 8,
      'key': '3',
      'level': 1,
      'title': 'Empty end',
      'url': 'https://example.invalid/book/3.html',
      'blocks': <Object>[],
    });
    expect(Book.parse(json).firstReadingFrom(8), n('2-1-1'));
  });

  test('bad shapes throw FormatException', () {
    Map<String, Object?> book() => tinyBookNested();

    expect(() => Book.parse('nope'), throwsFormatException);
    expect(() => Book.parse(book()..['pages'] = 'nope'), throwsFormatException);
    final unknownKind = book();
    ((unknownKind['pages']! as List)[0] as Map)['blocks'] = [
      {'kind': 'mystery', 'text': 'x'},
    ];
    expect(() => Book.parse(unknownKind), throwsFormatException);
    final outOfOrder = book();
    ((outOfOrder['pages']! as List)[2] as Map)['n'] = 9;
    expect(() => Book.parse(outOfOrder), throwsFormatException);

    expect(() => BooksIndex.parse([1]), throwsFormatException);
    expect(
      () => BooksIndex.parse({
        'source': {'fetched': 'x'},
        'books': [
          {'id': 'a'},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => BookBlock.parse({
        'kind': 'list',
        'marker': 'roman',
        'start': 1,
        'items': [],
      }),
      throwsFormatException,
    );
  });
}
