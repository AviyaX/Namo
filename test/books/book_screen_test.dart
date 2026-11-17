import 'dart:typed_data';

import 'package:buddhist_gatha/books/book_places.dart';
import 'package:buddhist_gatha/books/book_widgets.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../tipitaka/tipitaka_support.dart';
import 'books_support.dart';

const _tall = Size(390, 2000);
final _continue = find.byKey(const ValueKey('book-continue'));
Finder _row(int n) => find.byKey(ValueKey('book-row-$n'));

String _location(WidgetTester t) => ProviderScope.containerOf(
  t.element(find.byType(MaterialApp)),
).read(routerProvider).routeInformationProvider.value.uri.toString();

double _top(WidgetTester t, Finder f) => t.getTopLeft(f).dy;

/// Opens the app afresh at [location] (a second [openReal] in one test
/// would keep the first app's router).
Future<void> _open(WidgetTester t, String location) async {
  await t.pumpWidget(const SizedBox());
  await openReal(t, location, size: _tall);
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('shows cover, title, chapter count, Start reading and the '
      'contents', (t) async {
    final h = t.ensureSemantics();
    await _open(t, Routes.book(tinyBookNestedId));
    expect(find.byType(BookCover), findsOneWidget);
    expect(t.getSize(find.byType(BookCover)).width, 160);
    expect(find.text('Nested book'), findsOneWidget);
    expect(find.text('A made-up subtitle'), findsOneWidget);
    expect(find.text('2 chapters'), findsOneWidget);
    expect(
      find.descendant(of: _continue, matching: find.text('Start reading')),
      findsOneWidget,
    );
    expect(find.text('Contents'), findsOneWidget);
    // The level-1 pages, the front matter first; deeper pages are not here.
    expect(_top(t, _row(1)), lessThan(_top(t, _row(2))));
    expect(_top(t, _row(2)), lessThan(_top(t, _row(5))));
    for (final n in [3, 4, 6, 7]) {
      expect(_row(n), findsNothing, reason: 'page $n');
    }
    expect(
      find.descendant(of: _row(1), matching: find.text('About this book')),
      findsOneWidget,
    );
    // A row with children shows how many.
    expect(
      find.descendant(of: _row(2), matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _row(5), matching: find.text('2')),
      findsOneWidget,
    );
    // Screen readers hear the count; a row without children is its title.
    expect(find.bySemanticsLabel('Part one, 2 texts'), findsOneWidget);
    expect(find.bySemanticsLabel('Part two, 2 texts'), findsOneWidget);
    expect(find.bySemanticsLabel('About this book'), findsOneWidget);
    expect(find.text('Text: pitaka.lk'), findsOneWidget);
    expect(
      find.text(
        'Published by the Sri Chandawimala Dhamma Treatises Preservation '
        'Board',
      ),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
    h.dispose();
  });

  testWidgets('one chapter is singular', (t) async {
    final assets = tinyBooks();
    final index = Map<String, Object?>.of(
      assets[tinyBooksIndexPath]! as Map<String, Object?>,
    );
    index['books'] = [
      for (final b in index['books']! as List)
        {...b as Map<String, Object?>, 'chapters': 1},
    ];
    assets[tinyBooksIndexPath] = index;
    await openReal(
      t,
      Routes.book(tinyBookFlatId),
      size: _tall,
      books: fakeAssets(assets),
    );
    expect(find.text('1 chapter'), findsOneWidget);
  });

  testWidgets('Continue reading when a place is saved', (t) async {
    await openReal(
      t,
      Routes.book(tinyBookNestedId),
      size: _tall,
      storeExtras: {bookPlacesKey: '{"tiny-nested": {"n": 3, "offset": 0}}'},
    );
    expect(
      find.descendant(of: _continue, matching: find.text('Continue reading')),
      findsOneWidget,
    );
    await t.tap(_continue);
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/read/3');
  });

  testWidgets('a saved place past the end reads as Start reading', (t) async {
    await openReal(
      t,
      Routes.book(tinyBookNestedId),
      size: _tall,
      storeExtras: {bookPlacesKey: '{"tiny-nested": {"n": 99, "offset": 0}}'},
    );
    expect(
      find.descendant(of: _continue, matching: find.text('Start reading')),
      findsOneWidget,
    );
    await t.tap(_continue);
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/read/1');
  });

  testWidgets('a row with children opens the contents list; a leaf opens '
      'the reader', (t) async {
    await _open(t, Routes.book(tinyBookNestedId));
    await t.tap(_row(2));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/contents/2');

    await _open(t, Routes.book(tinyBookNestedId));
    await t.tap(_row(5));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/contents/5');

    await _open(t, Routes.book(tinyBookNestedId));
    await t.tap(_row(1));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/read/1');

    await _open(t, Routes.book(tinyBookFlatId));
    await t.tap(_row(3));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-flat/read/3');
  });

  testWidgets('Back goes to the Library', (t) async {
    await _open(t, Routes.book(tinyBookFlatId));
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(_location(t), Routes.library);
    expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
  });

  testWidgets('an unknown id shows Not found', (t) async {
    await openReal(t, Routes.book('no-such-book'), size: _tall);
    expect(find.text('This page could not be found.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a book that cannot be opened shows Try again', (t) async {
    var failing = true;
    final served = fakeAssets(tinyBooks());
    Future<Uint8List> load(String path) {
      if (failing && path == tinyBookFile(tinyBookFlatId)) {
        throw StateError('cannot read $path');
      }
      return served(path);
    }
    await openReal(t, Routes.book(tinyBookFlatId), size: _tall, books: load);
    expect(find.text('The book could not be opened.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(_continue, findsNothing);
    failing = false;
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('The book could not be opened.'), findsNothing);
    expect(_continue, findsOneWidget);
    expect(_row(2), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
