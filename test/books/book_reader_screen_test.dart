import 'dart:convert';
import 'dart:typed_data';

import 'package:buddhist_gatha/books/book_places.dart';
import 'package:buddhist_gatha/books/book_reader_screen.dart';
import 'package:buddhist_gatha/books/book_screen.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../tipitaka/tipitaka_support.dart';
import 'books_support.dart';

const _tall = Size(390, 2000);
const _small = Size(390, 600);
final _prev = find.byKey(const ValueKey('book-prev'));
final _next = find.byKey(const ValueKey('book-next'));

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

String _location(WidgetTester t) => _container(
  t,
).read(routerProvider).routeInformationProvider.value.uri.toString();

String? _storedPlaces(WidgetTester t) =>
    _container(t).read(keyValueStoreProvider).read(bookPlacesKey);

double _top(WidgetTester t, Finder f) => t.getTopLeft(f).dy;

ScrollPosition _position(WidgetTester t) =>
    t.state<ScrollableState>(find.byType(Scrollable).first).position;

bool _enabled(WidgetTester t, Finder f) =>
    t.widget<NamoIconButton>(f).onPressed != null;

/// Opens the app afresh at [location] (a second [openReal] in one test
/// would keep the first app's router).
Future<void> _open(
  WidgetTester t,
  String location, {
  Size size = _tall,
  double deviceTextScale = 1.0,
  AppSettings settings = const AppSettings(),
  Map<String, String> storeExtras = const {},
  Map<String, Object>? books,
}) async {
  await t.pumpWidget(const SizedBox());
  await openReal(
    t,
    location,
    size: size,
    deviceTextScale: deviceTextScale,
    settings: settings,
    storeExtras: storeExtras,
    books: books == null ? null : fakeAssets(books),
  );
}

/// [tinyBooks] with the nested book's pages changed by [change].
Map<String, Object> _changed(void Function(List<Map> pages) change) {
  final all = tinyBooks();
  final path = tinyBookFile(tinyBookNestedId);
  final book = jsonDecode(jsonEncode(all[path])) as Map<String, dynamic>;
  change((book['pages'] as List).cast<Map>());
  all[path] = book.cast<String, Object>();
  return all;
}

/// Page "2-1" (n 6) with forty more paragraphs: a page that scrolls.
Map<String, Object> _longBooks() => _changed((pages) {
  final blocks = pages[5]['blocks'] as List;
  for (var i = 0; i < 40; i++) {
    blocks.add({'kind': 'para', 'text': 'Long paragraph $i.'});
  }
});

/// How many lines [text] is drawn on, near enough: its height over the
/// height of its first line.
double _lines(WidgetTester t, String text) {
  final paragraph = t.renderObject<RenderParagraph>(find.text(text));
  return paragraph.size.height /
      paragraph.getFullHeightForCaret(const TextPosition(offset: 0));
}

/// Each of [texts] sits below the one before it.
void _inOrder(WidgetTester t, List<String> texts) {
  for (var i = 1; i < texts.length; i++) {
    expect(
      _top(t, find.text(texts[i - 1])),
      lessThan(_top(t, find.text(texts[i]))),
      reason: texts[i],
    );
  }
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('renders every block kind in order', (t) async {
    // "2-1-1": a subhead, a bullet list, a table, a picture not bundled.
    await _open(t, Routes.bookReader(tinyBookNestedId, 7));
    expect(find.byType(BookReaderScreen), findsOneWidget);
    expect(find.text('Two one one'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('book-reader-top-bar')),
        matching: find.text('Nested book'),
      ),
      findsOneWidget,
    );
    expect(
      t.widget<Text>(find.text('A subhead')).style!.fontWeight,
      FontWeight.w600,
    );
    expect(find.text('•'), findsNWidgets(2));
    for (final cell in ['Name', 'Count', 'Apples', '3']) {
      expect(find.text(cell), findsOneWidget, reason: cell);
    }
    expect(find.byType(Table), findsOneWidget);
    expect(t.widget<Text>(find.text('Name')).style!.fontWeight, FontWeight.w600);
    expect(
      t.widget<Text>(find.text('Apples')).style!.fontWeight,
      isNot(FontWeight.w600),
    );
    expect(find.text('Picture: A made-up picture'), findsOneWidget);
    _inOrder(t, [
      'Two one one',
      'A subhead',
      'Bullet one',
      'Bullet two',
      'Name',
      'Apples',
      'Picture: A made-up picture',
    ]);
    // The bullets lead their items.
    expect(
      t.getTopLeft(find.text('•').first).dx,
      lessThan(t.getTopLeft(find.text('Bullet one')).dx),
    );

    // "1-1": a paragraph, a verse line by line, a heading, a paragraph.
    await _open(t, Routes.bookReader(tinyBookNestedId, 3));
    expect(find.text(tinyLongTitle), findsOneWidget);
    final para = t.widget<Text>(find.text('One one text.')).style!;
    final heading = t.widget<Text>(find.text('A heading')).style!;
    expect(heading.fontSize, closeTo(para.fontSize! * 1.25, 0.001));
    expect(heading.fontWeight, FontWeight.w600);
    _inOrder(t, [
      tinyLongTitle,
      'One one text.',
      'Verse line one',
      'Verse line two',
      'A heading',
      'After the heading.',
    ]);
    // The verse is set in from the paragraphs.
    expect(
      t.getTopLeft(find.text('Verse line one')).dx,
      greaterThan(t.getTopLeft(find.text('One one text.')).dx),
    );

    // "1-2": a list numbered from 3, a list with its own labels, footnotes.
    await _open(t, Routes.bookReader(tinyBookNestedId, 4));
    expect(find.text('3.'), findsOneWidget);
    expect(find.text('4.'), findsOneWidget);
    expect(find.text('Third item'), findsOneWidget);
    expect(find.text('Fourth item'), findsOneWidget);
    expect(find.text('(a) Lettered item'), findsOneWidget);
    expect(find.text('(b) Another'), findsOneWidget);
    expect(find.text('•'), findsNothing);
    // The labelled items start where the numbers do: no lead.
    expect(
      t.getTopLeft(find.text('(a) Lettered item')).dx,
      t.getTopLeft(find.text('3.')).dx,
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    _inOrder(t, ['3.', '4.', '(a) Lettered item', '(b) Another', '1', '2']);
    expect(_top(t, find.text('1')), _top(t, find.text('Note one.')));
    expect(_top(t, find.text('2')), _top(t, find.text('Note two.')));
    expect(t.takeException(), isNull);
  });

  testWidgets('a bundled picture is drawn and named', (t) async {
    final h = t.ensureSemantics();
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 7),
      books: _changed((pages) {
        final blocks = pages[6]['blocks'] as List;
        (blocks.last as Map)['asset'] = tinyBookCover;
      }),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('Picture'), findsNothing);
    expect(find.bySemanticsLabel('A made-up picture'), findsOneWidget);
    expect(t.takeException(), isNull);
    h.dispose();
  });

  testWidgets('the counter and the buttons step through reading pages only', (
    t,
  ) async {
    // Reading pages: 1, 2, 3, 4, 6, 7 (5 is "2", which has no text).
    await _open(t, Routes.bookReader(tinyBookNestedId, 4));
    expect(find.text('4 / 6'), findsOneWidget);
    expect(_enabled(t, _prev), isTrue);
    await t.tap(_next);
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/read/6');
    expect(find.text('5 / 6'), findsOneWidget);
    expect(find.text('Two one text.'), findsOneWidget);
    await t.tap(_next);
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/read/7');
    expect(find.text('6 / 6'), findsOneWidget);
    expect(_enabled(t, _next), isFalse);
    await t.tap(_prev);
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/read/6');
    await t.tap(_prev);
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/read/4');

    await _open(t, Routes.bookReader(tinyBookNestedId, 1));
    expect(find.text('1 / 6'), findsOneWidget);
    expect(_enabled(t, _prev), isFalse);
    expect(_enabled(t, _next), isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('a non-reading n redirects to the next reading page', (t) async {
    await _open(t, Routes.bookReader(tinyBookNestedId, 5));
    expect(_location(t), '/library/book/tiny-nested/read/6');
    expect(find.text('Two one text.'), findsOneWidget);
    await _open(t, Routes.bookReader(tinyBookNestedId, 0));
    expect(_location(t), '/library/book/tiny-nested/read/1');
    expect(t.takeException(), isNull);
  });

  testWidgets('an n past the end opens the last reading page', (t) async {
    await _open(t, Routes.bookReader(tinyBookNestedId, 99));
    expect(_location(t), '/library/book/tiny-nested/read/7');
    expect(find.text('6 / 6'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a book without text goes to the book page', (t) async {
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 2),
      books: _changed((pages) {
        for (final page in pages) {
          page['blocks'] = <Object>[];
        }
      }),
    );
    expect(_location(t), '/library/book/tiny-nested');
    expect(find.byType(BookScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('an unknown book or an n that is not a number shows Not found', (
    t,
  ) async {
    await _open(t, Routes.bookReader('no-such-book', 2));
    expect(find.text('This page could not be found.'), findsOneWidget);
    await _open(t, '/library/book/tiny-nested/read/two');
    expect(find.text('This page could not be found.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the place is saved on open and after scrolling, and restored', (
    t,
  ) async {
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 6),
      size: _small,
      books: _longBooks(),
    );
    expect(jsonDecode(_storedPlaces(t)!), {
      tinyBookNestedId: {'n': 6, 'key': '2-1', 'offset': 0},
    });
    await t.drag(find.text('Two one text.'), const Offset(0, -300));
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 500));
    final offset = _position(t).pixels;
    expect(offset, greaterThan(0));
    final saved = _storedPlaces(t)!;
    expect(jsonDecode(saved), {
      tinyBookNestedId: {'n': 6, 'key': '2-1', 'offset': offset},
    });

    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 6),
      size: _small,
      books: _longBooks(),
      storeExtras: {bookPlacesKey: saved},
    );
    expect(_position(t).pixels, offset);

    // Another page of the book opens at its top and is remembered there.
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 7),
      size: _small,
      books: _longBooks(),
      storeExtras: {bookPlacesKey: saved},
    );
    expect(_position(t).pixels, 0);
    expect(jsonDecode(_storedPlaces(t)!), {
      tinyBookNestedId: {'n': 7, 'key': '2-1-1', 'offset': 0},
    });
    expect(t.takeException(), isNull);
  });

  testWidgets('a saved place is found by its key when the numbers moved', (
    t,
  ) async {
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 6),
      size: _small,
      books: _longBooks(),
    );
    await t.drag(find.text('Two one text.'), const Offset(0, -300));
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 500));
    final offset = _position(t).pixels;
    expect(offset, greaterThan(0));
    // As if the book had been fetched again with a page more in front: the
    // saved n is now another page, the key still this one.
    final moved = jsonEncode({
      tinyBookNestedId: {'n': 3, 'key': '2-1', 'offset': offset},
    });
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 6),
      size: _small,
      books: _longBooks(),
      storeExtras: {bookPlacesKey: moved},
    );
    expect(_position(t).pixels, offset);
    // Page 3 is not the place, so it opens at its top and becomes the place.
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 3),
      size: _small,
      books: _longBooks(),
      storeExtras: {bookPlacesKey: moved},
    );
    expect(_position(t).pixels, 0);
    expect(jsonDecode(_storedPlaces(t)!), {
      tinyBookNestedId: {'n': 3, 'key': '1-1', 'offset': 0},
    });
    expect(t.takeException(), isNull);
  });

  testWidgets('numbers past 9 stay on one line beside their items', (
    t,
  ) async {
    for (final (scale, font) in [(1.0, 1.0), (2.0, 1.6)]) {
      await _open(
        t,
        Routes.bookReader(tinyBookNestedId, 8),
        size: const Size(320, 4000),
        deviceTextScale: scale,
        settings: AppSettings(fontScale: font),
        books: tinyBooksWithLongBlocks(),
      );
      expect(find.text(tinyLongBlocksTitle), findsOneWidget);
      final why = 'device $scale, Settings $font';
      for (var i = 1; i <= 12; i++) {
        for (final (label, item) in [('$i.', 'Item $i'), ('$i', 'Note $i')]) {
          expect(_lines(t, label), lessThan(1.5), reason: '$label, $why');
          // Drawn whole: its box is as wide as the label on one line.
          final paragraph = t.renderObject<RenderParagraph>(find.text(label));
          expect(
            paragraph.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(paragraph.size.width),
            reason: '$label, $why',
          );
          expect(
            t.getRect(find.text(label)).right,
            lessThanOrEqualTo(t.getRect(find.text(item)).left),
            reason: '$label, $why',
          );
          expect(
            _top(t, find.text(label)),
            _top(t, find.text(item)),
            reason: '$label, $why',
          );
        }
      }
      // Every item starts at the same place, the lead as wide as "12.".
      for (var i = 2; i <= 12; i++) {
        expect(
          t.getTopLeft(find.text('Item $i')).dx,
          t.getTopLeft(find.text('Item 1')).dx,
        );
      }
      expect(t.takeException(), isNull, reason: why);
    }
  });

  testWidgets('a table with a long cell fits the column and wraps it', (
    t,
  ) async {
    for (final scale in [1.0, 2.0]) {
      await _open(
        t,
        Routes.bookReader(tinyBookNestedId, 8),
        size: const Size(320, 4000),
        deviceTextScale: scale,
        books: tinyBooksWithLongBlocks(),
      );
      // The title fills the column of text: the table keeps within it.
      final column = t.getRect(find.text(tinyLongBlocksTitle));
      final table = t.getRect(find.byType(Table));
      expect(table.left, greaterThanOrEqualTo(column.left - 0.5));
      expect(table.right, lessThanOrEqualTo(column.right + 0.5));
      expect(_lines(t, tinyLongCell), greaterThan(1.5), reason: '$scale');
      expect(_lines(t, 'Short'), lessThan(1.5), reason: '$scale');
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('a grid of short cells keeps them whole and scrolls sideways', (
    t,
  ) async {
    const cells = ['Ka', 'Kaa', 'Ki', 'Kii', 'Ku', 'Kuu', 'Ke', 'Kee', 'Ko'];
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 7),
      size: const Size(320, 2000),
      deviceTextScale: 2.0,
      books: _changed((pages) {
        final blocks = pages[6]['blocks'] as List;
        final table = blocks.firstWhere((b) => (b as Map)['kind'] == 'table');
        (table as Map)['rows'] = [cells, cells.reversed.toList()];
      }),
    );
    final column = t.getRect(find.text('Two one one'));
    expect(t.getSize(find.byType(Table)).width, greaterThan(column.width));
    for (final cell in cells) {
      for (final e in find.text(cell).evaluate()) {
        final paragraph = e.renderObject! as RenderParagraph;
        expect(
          paragraph.size.height /
              paragraph.getFullHeightForCaret(const TextPosition(offset: 0)),
          lessThan(1.5),
          reason: cell,
        );
      }
    }
    // It is the sideways scroll that holds it.
    expect(
      find.ancestor(
        of: find.byType(Table),
        matching: find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
        ),
      ),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('a scroll not yet saved is saved on leaving', (t) async {
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 6),
      size: _small,
      books: _longBooks(),
    );
    await t.drag(find.text('Two one text.'), const Offset(0, -300));
    await t.pump();
    expect(_position(t).pixels, greaterThan(0));
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/contents/5');
    final place = jsonDecode(_storedPlaces(t)!)[tinyBookNestedId] as Map;
    expect(place['n'], 6);
    expect(place['offset'], greaterThan(0));
    expect(t.takeException(), isNull);
  });

  testWidgets('a page left while still moving does not take the place back', (
    t,
  ) async {
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 6),
      size: _small,
      books: _longBooks(),
    );
    await t.fling(find.text('Two one text.'), const Offset(0, -300), 3000);
    await t.pump();
    expect(_position(t).isScrollingNotifier.value, isTrue);
    await t.tap(_next);
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 500));
    expect(_location(t), '/library/book/tiny-nested/read/7');
    expect(jsonDecode(_storedPlaces(t)!), {
      tinyBookNestedId: {'n': 7, 'key': '2-1-1', 'offset': 0},
    });
    expect(t.takeException(), isNull);
  });

  testWidgets('Back goes to the parent contents list', (t) async {
    await _open(t, Routes.bookReader(tinyBookNestedId, 7));
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/contents/6');
    await _open(t, Routes.bookReader(tinyBookNestedId, 3));
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/contents/2');
    expect(t.takeException(), isNull);
  });

  testWidgets('Back goes to the book page for a top-level page', (t) async {
    await _open(t, Routes.bookReader(tinyBookNestedId, 2));
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested');
    expect(find.byType(BookScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('text size and line spacing follow Settings', (t) async {
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 2),
      settings: const AppSettings(fontScale: 1.4, lineSpacing: 2.0),
    );
    final style = t.widget<Text>(find.text('Part one text.')).style!;
    expect(style.fontSize, closeTo(18 * 1.4, 0.001));
    expect(style.height, 2.0);
    await t.tap(find.byTooltip('Reading settings'));
    await t.pumpAndSettle();
    expect(find.text('Back to the beginning'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a book that cannot be opened shows Try again', (t) async {
    var failing = true;
    final served = fakeAssets(tinyBooks());
    Future<Uint8List> load(String path) {
      if (failing && path == tinyBookFile(tinyBookNestedId)) {
        throw StateError('cannot read $path');
      }
      return served(path);
    }

    await t.pumpWidget(const SizedBox());
    await openReal(
      t,
      Routes.bookReader(tinyBookNestedId, 2),
      size: _tall,
      books: load,
    );
    expect(find.text('The book could not be opened.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(_next, findsNothing);
    failing = false;
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('The book could not be opened.'), findsNothing);
    expect(find.text('Part one text.'), findsOneWidget);
    expect(find.text('2 / 6'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
