import 'dart:async';
import 'dart:typed_data';

import 'package:buddhist_gatha/books/book_screen.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../tipitaka/tipitaka_support.dart';
import 'books_support.dart';

const _tall = Size(390, 2400);
final _shelf = find.byKey(const ValueKey('books-shelf'));
Finder _card(String id) => find.byKey(ValueKey('book-$id'));

String _location(WidgetTester t) => ProviderScope.containerOf(
  t.element(find.byType(MaterialApp)),
).read(routerProvider).routeInformationProvider.value.uri.toString();

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('the shelf shows every book with its title', (t) async {
    final h = t.ensureSemantics();
    await openReal(t, Routes.tipitaka, size: _tall);
    expect(_shelf, findsOneWidget);
    expect(
      find.descendant(of: _shelf, matching: find.text('පොත්')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _shelf,
        matching: find.text('රේරුකානේ චන්දවිමල හිමියන්ගේ පොත්'),
      ),
      findsOneWidget,
    );
    for (final (id, title) in [
      (tinyBookFlatId, 'Flat book'),
      (tinyBookNestedId, 'Nested book'),
    ]) {
      expect(_card(id), findsOneWidget);
      expect(
        find.descendant(of: _card(id), matching: find.text(title)),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('$title, book'), findsOneWidget);
      final size = t.getSize(_card(id));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    // In shelf order, side by side in one row.
    expect(
      t.getTopLeft(_card(tinyBookFlatId)).dx,
      lessThan(t.getTopLeft(_card(tinyBookNestedId)).dx),
    );
    expect(
      t.getTopLeft(_card(tinyBookFlatId)).dy,
      t.getTopLeft(_card(tinyBookNestedId)).dy,
    );
    expect(t.takeException(), isNull);
    h.dispose();
  });

  testWidgets('the shelf comes after the Tripitaka', (t) async {
    await openReal(t, Routes.tipitaka, size: _tall);
    expect(
      t.getTopLeft(_shelf).dy,
      greaterThan(
        t.getTopLeft(find.byKey(const ValueKey('tipitaka-search'))).dy,
      ),
    );
    expect(
      t.getTopLeft(_shelf).dy,
      greaterThan(
        t.getTopLeft(find.byKey(const ValueKey('tipitaka-pitaka-vp'))).dy,
      ),
    );
  });

  testWidgets('a tap opens the book page', (t) async {
    await openReal(t, Routes.tipitaka, size: _tall);
    await t.tap(_card(tinyBookFlatId));
    await t.pumpAndSettle();
    expect(_location(t), '/tipitaka/book/tiny-flat');
    expect(find.byType(BookScreen), findsOneWidget);
  });

  testWidgets('a cover that fails to load shows the placeholder', (t) async {
    final assets = tinyBooks();
    final index = Map<String, Object?>.of(
      assets[tinyBooksIndexPath]! as Map<String, Object?>,
    );
    index['books'] = [
      for (final b in index['books']! as List)
        {...b as Map<String, Object?>, 'cover': 'assets/books/covers/none.jpg'},
    ];
    assets[tinyBooksIndexPath] = index;
    await openReal(t, Routes.tipitaka, size: _tall, books: fakeAssets(assets));
    // The asset bundle answers outside the test's fake clock.
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await t.pumpAndSettle();
    expect(
      find.descendant(of: _card(tinyBookFlatId), matching: find.text('F')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _card(tinyBookNestedId), matching: find.text('N')),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('a long shelf is one row that scrolls sideways', (t) async {
    final assets = tinyBooks();
    final index = Map<String, Object?>.of(
      assets[tinyBooksIndexPath]! as Map<String, Object?>,
    );
    final first = (index['books']! as List).first as Map<String, Object?>;
    index['books'] = [
      for (var i = 1; i <= 8; i++)
        {...first, 'id': 'book-$i', 'title': 'Book number $i'},
    ];
    assets[tinyBooksIndexPath] = index;
    await openReal(t, Routes.tipitaka, size: _tall, books: fakeAssets(assets));
    final row = find.descendant(of: _shelf, matching: find.byType(Scrollable));
    // The row's right edge is the viewport edge: the page margin (20 px at
    // 390 px) is inside the screen.
    final edge = t.getRect(row).right;
    expect(edge, lessThan(t.view.physicalSize.width));
    // One row: every card at the same height.
    final top = t.getTopLeft(_card('book-1')).dy;
    expect(t.getTopLeft(_card('book-2')).dy, top);
    // A card is cut by the row's right edge, so the row is seen to scroll.
    final cut = [
      for (var i = 1; i <= 8; i++)
        if (_card('book-$i').evaluate().isNotEmpty &&
            t.getTopLeft(_card('book-$i')).dx < edge &&
            t.getTopRight(_card('book-$i')).dx > edge)
          i,
    ];
    expect(cut, hasLength(1));
    // The last card is reached by scrolling the row, and opens its book.
    await t.scrollUntilVisible(_card('book-8'), 200, scrollable: row);
    await t.pumpAndSettle();
    expect(t.getTopLeft(_card('book-8')).dy, top);
    await t.tap(_card('book-8'));
    await t.pumpAndSettle();
    expect(_location(t), '/tipitaka/book/book-8');
    expect(t.takeException(), isNull);
  });

  testWidgets('the row fits at 320 wide with large text', (t) async {
    await openReal(
      t,
      Routes.tipitaka,
      size: const Size(320, 2000),
      deviceTextScale: 2.0,
    );
    for (final id in [tinyBookFlatId, tinyBookNestedId]) {
      expect(t.getSize(_card(id)).height, greaterThanOrEqualTo(48));
      expect(t.getSize(_card(id)).width, greaterThanOrEqualTo(48));
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('the shelf is as tall while the books load as after', (
    t,
  ) async {
    for (final scale in [1.0, 2.0]) {
      await t.pumpWidget(const SizedBox());
      final gate = Completer<void>();
      final served = fakeAssets(tinyBooks());
      Future<Uint8List> load(String path) async {
        await gate.future;
        return served(path);
      }

      await openReal(
        t,
        Routes.tipitaka,
        size: _tall,
        deviceTextScale: scale,
        books: load,
        settle: false,
      );
      await t.pump();
      final placeholder = find.byKey(const ValueKey('books-shelf-loading'));
      expect(placeholder, findsOneWidget);
      expect(_card(tinyBookFlatId), findsNothing);
      final loading = t.getSize(_shelf).height;
      expect(loading, greaterThan(0));
      final below = t.getRect(_shelf).bottom;

      gate.complete();
      await t.pumpAndSettle();
      expect(placeholder, findsNothing);
      expect(_card(tinyBookFlatId), findsOneWidget);
      expect(t.getSize(_shelf).height, loading, reason: '$scale');
      expect(t.getRect(_shelf).bottom, below, reason: '$scale');
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('no books, no shelf', (t) async {
    await openReal(t, Routes.tipitaka, books: fakeAssets(noBooks()));
    expect(_shelf, findsOneWidget);
    expect(t.getSize(_shelf).height, 0);
    expect(find.text('පොත්'), findsNothing);
  });

  testWidgets('the Library tab (Tripitaka & Books) stays selected on the book page', (t) async {
    final h = t.ensureSemantics();
    await openReal(t, Routes.tipitaka, size: _tall);
    await t.tap(_card(tinyBookNestedId));
    await t.pumpAndSettle();
    expect(find.byType(BookScreen), findsOneWidget);
    final tab = find.byKey(const ValueKey('nav-tripitaka'));
    expect(tab, findsOneWidget);
    expect(
      t.getSemantics(tab).getSemanticsData().flagsCollection.isSelected
          .toBoolOrNull(),
      isTrue,
    );
    h.dispose();
  });
}
