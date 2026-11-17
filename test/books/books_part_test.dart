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
    await openReal(t, Routes.library, size: _tall);
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
    // In shelf order, side by side.
    expect(
      t.getTopLeft(_card(tinyBookFlatId)).dx,
      lessThan(t.getTopLeft(_card(tinyBookNestedId)).dx),
    );
    expect(t.takeException(), isNull);
    h.dispose();
  });

  testWidgets('a tap opens the book page', (t) async {
    await openReal(t, Routes.library, size: _tall);
    await t.tap(_card(tinyBookFlatId));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-flat');
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
    await openReal(t, Routes.library, size: _tall, books: fakeAssets(assets));
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

  testWidgets('no books, no shelf', (t) async {
    await openReal(t, Routes.library, books: fakeAssets(noBooks()));
    expect(_shelf, findsOneWidget);
    expect(t.getSize(_shelf).height, 0);
    expect(find.text('පොත්'), findsNothing);
  });

  testWidgets('the Library tab stays selected on the book page', (t) async {
    final h = t.ensureSemantics();
    await openReal(t, Routes.library, size: _tall);
    await t.tap(_card(tinyBookNestedId));
    await t.pumpAndSettle();
    expect(find.byType(BookScreen), findsOneWidget);
    final tab = find.byKey(const ValueKey('nav-library'));
    expect(tab, findsOneWidget);
    expect(
      t.getSemantics(tab).getSemanticsData().flagsCollection.isSelected
          .toBoolOrNull(),
      isTrue,
    );
    h.dispose();
  });
}
