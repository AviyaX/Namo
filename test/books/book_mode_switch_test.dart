import 'dart:convert';

import 'package:buddhist_gatha/books/book_blocks.dart';
import 'package:buddhist_gatha/books/book_frame.dart';
import 'package:buddhist_gatha/books/book_model.dart';
import 'package:buddhist_gatha/books/book_pages_view.dart';
import 'package:buddhist_gatha/books/book_places.dart';
import 'package:buddhist_gatha/books/book_reader_screen.dart';
import 'package:buddhist_gatha/books/books_repository.dart';
import 'package:buddhist_gatha/books/pagination/book_paginator.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../tipitaka/tipitaka_support.dart';
import 'books_support.dart';

// The app's largest text on a short phone: "3" (n 8) is three pages, and
// its scroll column (the text on the book's paper) several screens.
const _phone = Size(390, 700);
const _large = AppSettings(fontScale: 1.6);
final _width = bookScrollTextWidth(_phone.width);
final _next = find.byKey(const ValueKey('book-page-next'));
final _column = find.byWidgetPredicate(
  (w) => w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
);

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

BookPage _chapter(WidgetTester t) =>
    _container(t).read(bookProvider(tinyBookNestedId)).value!.page(8)!;

BookTextStyles _styles(WidgetTester t) => BookTextStyles.onPaper(
  t.element(find.byType(BookReaderScreen)),
  _container(t).read(settingsProvider),
);

BookSpot? _pagesSpot(WidgetTester t) =>
    t.state<BookPagesViewState>(find.byType(BookPagesView)).spot;

bool _nextEnabled(WidgetTester t) =>
    t.widget<NamoIconButton>(_next).onPressed != null;

ScrollController _scroll(WidgetTester t) =>
    t.widget<SingleChildScrollView>(_column).controller!;

/// The first line at or below the top of the scroll column.
BookSpot _scrollSpot(WidgetTester t) =>
    spotAtOffset(_chapter(t), _styles(t), _width, _scroll(t).offset);

Map<String, Object?> _stored(WidgetTester t) {
  final all = jsonDecode(
    _container(t).read(keyValueStoreProvider).read(bookPlacesKey)!,
  ) as Map<String, Object?>;
  return all[tinyBookNestedId]! as Map<String, Object?>;
}

Future<void> _switchTo(WidgetTester t, BookReadingMode mode) async {
  _container(t).read(settingsProvider.notifier).setBookReadingMode(mode);
  await t.pumpAndSettle();
}

Future<void> _open(
  WidgetTester t,
  BookReadingMode mode, {
  Size size = _phone,
}) async {
  await openReal(
    t,
    Routes.bookReader(tinyBookNestedId, 8),
    size: size,
    settings: _large.copyWith(bookReadingMode: mode),
    books: fakeAssets(tinyBooksWithLongBlocks()),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadBundledFonts);

  for (final waited in [false, true]) {
    testWidgets('Scroll → Pages opens the page holding the first visible line'
        '${waited ? ' (place already saved)' : ' (switched at once)'}', (
      t,
    ) async {
      await _open(t, BookReadingMode.scroll);
      await t.drag(_column, const Offset(0, -500));
      await t.pumpAndSettle();
      if (waited) await t.pump(const Duration(milliseconds: 500));
      final wanted = _scrollSpot(t);
      expect(wanted.compareTo(BookSpot.start), greaterThan(0));
      final screen = t.state(find.byType(BookReaderScreen));

      await _switchTo(t, BookReadingMode.pages);
      expect(t.state(find.byType(BookReaderScreen)), same(screen));
      // The page shown holds the line: it starts at or before it, and
      // the next page starts after it.
      final shown = _pagesSpot(t)!;
      expect(shown.compareTo(wanted), lessThanOrEqualTo(0));
      expect(shown, isNot(BookSpot.title));
      await t.tap(_next);
      await t.pumpAndSettle();
      expect(_pagesSpot(t)!.compareTo(wanted), greaterThan(0));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('a scrolled place is saved with its first line', (t) async {
    await _open(t, BookReadingMode.scroll);
    await t.drag(_column, const Offset(0, -900));
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 500));
    final place = _stored(t);
    final spot = _scrollSpot(t);
    expect(place['offset'], _scroll(t).offset);
    expect(place['spot'], [spot.block, spot.char]);
    expect(t.takeException(), isNull);
  });

  for (final waited in [false, true]) {
    testWidgets("Pages → Scroll scrolls to the shown page's first line"
        '${waited ? ' (place already saved)' : ' (switched at once)'}', (
      t,
    ) async {
      await _open(t, BookReadingMode.pages);
      await t.tap(_next);
      await t.pumpAndSettle();
      if (waited) await t.pump(const Duration(milliseconds: 500));
      final shown = _pagesSpot(t)!;
      expect(shown.block, greaterThanOrEqualTo(0));

      await _switchTo(t, BookReadingMode.scroll);
      expect(find.byType(BookPagesView), findsNothing);
      expect(_scroll(t).offset, greaterThan(0));
      expect(_scrollSpot(t), shown);
      expect(
        _scroll(t).offset,
        offsetOfSpot(_chapter(t), _styles(t), _width, shown),
      );

      // And back: the same page.
      await _switchTo(t, BookReadingMode.pages);
      expect(_pagesSpot(t), shown);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
    "the last page's first line below the column's end: Scroll goes to the "
    'end, and back in Pages the same page shows',
    (t) async {
      // A taller phone: "3" is two pages, and the second starts less than
      // a screen from the scroll column's end.
      await _open(t, BookReadingMode.pages, size: const Size(390, 1000));
      await t.tap(_next);
      await t.pumpAndSettle();
      expect(_nextEnabled(t), isFalse);
      final shown = _pagesSpot(t)!;
      final offset = offsetOfSpot(_chapter(t), _styles(t), _width, shown);

      await _switchTo(t, BookReadingMode.scroll);
      final end = _scroll(t).position.maxScrollExtent;
      expect(offset, greaterThan(end));
      expect(_scroll(t).offset, end);

      await _switchTo(t, BookReadingMode.pages);
      expect(_pagesSpot(t), shown);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Scroll → Pages → Scroll comes back at the first line of the page',
    (t) async {
      await _open(t, BookReadingMode.scroll);
      await t.drag(_column, const Offset(0, -900));
      await t.pumpAndSettle();
      await _switchTo(t, BookReadingMode.pages);
      final page = _pagesSpot(t)!;
      expect(page, isNot(BookSpot.title));
      await _switchTo(t, BookReadingMode.scroll);
      // At the line the pages opened at: the first line of their page.
      expect(_scrollSpot(t), page);
      expect(t.takeException(), isNull);
    },
  );
}
