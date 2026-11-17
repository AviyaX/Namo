import 'package:buddhist_gatha/books/book_contents_screen.dart';
import 'package:buddhist_gatha/books/book_screen.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import 'books_support.dart';

const _tall = Size(390, 2000);
Finder _row(int n) => find.byKey(ValueKey('book-row-$n'));
Finder _own(int n) => find.byKey(ValueKey('book-row-own-$n'));

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

  testWidgets("lists the page's own text first when it has text, then its "
      'children', (t) async {
    // Page 2 is "1": text of its own, and "1-1" (3) and "1-2" (4) under it.
    await _open(t, Routes.bookContents(tinyBookNestedId, 2));
    expect(find.byType(BookContentsScreen), findsOneWidget);
    expect(_own(2), findsOneWidget);
    expect(_row(3), findsOneWidget);
    expect(_row(4), findsOneWidget);
    expect(_row(2), findsNothing);
    expect(_top(t, _own(2)), lessThan(_top(t, _row(3))));
    expect(_top(t, _row(3)), lessThan(_top(t, _row(4))));
    // The header and the own row both carry the page's title.
    expect(find.text('Part one'), findsNWidgets(2));
    expect(
      find.descendant(of: _row(3), matching: find.text(tinyLongTitle)),
      findsOneWidget,
    );
    await t.tap(_own(2));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/read/2');

    await _open(t, Routes.bookContents(tinyBookNestedId, 2));
    await t.tap(_row(4));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/read/4');
    expect(t.takeException(), isNull);
  });

  testWidgets('a parent without text has no own row', (t) async {
    // Page 5 is "2": no text; "2-1" (6) under it, which has "2-1-1" (7).
    await _open(t, Routes.bookContents(tinyBookNestedId, 5));
    expect(_own(5), findsNothing);
    expect(_row(6), findsOneWidget);
    expect(
      find.descendant(of: _row(6), matching: find.text('1')),
      findsOneWidget,
    );
    await t.tap(_row(6));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/contents/6');
    expect(_own(6), findsOneWidget);
    expect(_row(7), findsOneWidget);
  });

  testWidgets('Back goes to the parent list or the book page', (t) async {
    await _open(t, Routes.bookContents(tinyBookNestedId, 6));
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/contents/5');
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested');
    expect(find.byType(BookScreen), findsOneWidget);
  });

  testWidgets('a childless n shows Not found', (t) async {
    for (final n in ['1', '3', '99', '0', 'x']) {
      await _open(t, '/library/book/tiny-nested/contents/$n');
      expect(
        find.text('This page could not be found.'),
        findsOneWidget,
        reason: n,
      );
    }
    await _open(t, Routes.bookContents('no-such-book', 2));
    expect(find.text('This page could not be found.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
