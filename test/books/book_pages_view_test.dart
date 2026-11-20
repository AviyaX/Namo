import 'dart:convert';

import 'package:buddhist_gatha/books/book_blocks.dart';
import 'package:buddhist_gatha/books/book_model.dart';
import 'package:buddhist_gatha/books/book_pages_view.dart';
import 'package:buddhist_gatha/books/book_places.dart';
import 'package:buddhist_gatha/books/book_reader_screen.dart';
import 'package:buddhist_gatha/books/books_repository.dart';
import 'package:buddhist_gatha/books/pagination/book_paginator.dart';
import 'package:buddhist_gatha/books/pagination/screen_page_view.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../tipitaka/tipitaka_support.dart';
import 'books_support.dart';

// The app's largest text on a short phone: "3" (n 8) is three pages.
const _phone = Size(390, 700);
const _large = AppSettings(fontScale: 1.6);
final _prev = find.byKey(const ValueKey('book-page-prev'));
final _next = find.byKey(const ValueKey('book-page-next'));
final _count = find.byKey(const ValueKey('book-page-count'));
const _nextPage = CustomSemanticsAction(label: 'Next page');

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

String _location(WidgetTester t) =>
    _container(t)
        .read(routerProvider)
        .routeInformationProvider
        .value
        .uri
        .toString();

bool _enabled(WidgetTester t, Finder f) =>
    t.widget<NamoIconButton>(f).onPressed != null;

String _countText(WidgetTester t) => t.widget<Text>(_count).data!;

/// The page shown and the chapter's page count, from "i of n".
(int, int) _shown(WidgetTester t) {
  final m = RegExp(r'^(\d+) of (\d+)$').firstMatch(_countText(t));
  expect(m, isNotNull, reason: _countText(t));
  return (int.parse(m!.group(1)!), int.parse(m.group(2)!));
}

BookPagesViewState _view(WidgetTester t) =>
    t.state<BookPagesViewState>(find.byType(BookPagesView));

Book _book(WidgetTester t) =>
    _container(t).read(bookProvider(tinyBookNestedId)).value!;

/// The saved place of the nested book, as stored.
Map<String, Object?> _stored(WidgetTester t) {
  final all = jsonDecode(
    _container(t).read(keyValueStoreProvider).read(bookPlacesKey)!,
  ) as Map<String, Object?>;
  return all[tinyBookNestedId]! as Map<String, Object?>;
}

/// Opens the app afresh at [location] with the long-blocks books.
Future<void> _open(
  WidgetTester t,
  String location, {
  Size size = _phone,
  AppSettings settings = _large,
  Map<String, String> storeExtras = const {},
  double deviceTextScale = 1.0,
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
    books: fakeAssets(books ?? tinyBooksWithLongBlocks()),
  );
  // The chapters around are cut a few pages a frame.
  await t.pumpAndSettle();
}

/// The long-blocks books with forty more paragraphs in "2-1-1" (n 7), so
/// the chapter before "3" (n 8) is several pages.
Map<String, Object> _longSeven() {
  final books = tinyBooksWithLongBlocks();
  final path = tinyBookFile(tinyBookNestedId);
  final book = jsonDecode(jsonEncode(books[path])) as Map<String, dynamic>;
  final blocks = (book['pages'] as List)[6]['blocks'] as List;
  for (var i = 0; i < 40; i++) {
    blocks.insert(0, {'kind': 'para', 'text': 'Long paragraph $i.'});
  }
  books[path] = book.cast<String, Object>();
  return books;
}

/// Taps [arrow] and pumps the turn frame by frame, checking that one
/// reader, and never a second, is on screen throughout: no route
/// transition.
Future<void> _turnWithoutTransition(WidgetTester t, Finder arrow) async {
  await t.tap(arrow);
  for (var f = 0; f < 40; f++) {
    await t.pump(const Duration(milliseconds: 20));
    expect(find.byType(BookReaderScreen), findsOneWidget, reason: 'frame $f');
  }
  await t.pumpAndSettle();
}

Future<void> _tapNext(WidgetTester t) async {
  await t.tap(_next);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('Pages is the default: page arrows and "1 of N"', (t) async {
    await _open(t, Routes.bookReader(tinyBookNestedId, 8));
    expect(find.byType(BookPagesView), findsOneWidget);
    final (i, n) = _shown(t);
    expect(i, 1);
    expect(n, greaterThan(1));
    expect(find.text(tinyLongBlocksTitle), findsOneWidget);
    // The chapter before is a page back; the book goes on after.
    expect(_enabled(t, _prev), isTrue);
    expect(_enabled(t, _next), isTrue);
    expect(find.byKey(const ValueKey('book-prev')), findsNothing);
    expect(find.byKey(const ValueKey('book-next')), findsNothing);
    expect(find.byTooltip('Next page'), findsOneWidget);
    expect(find.byTooltip('Previous page'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('next page arrow turns and the count moves', (t) async {
    await _open(t, Routes.bookReader(tinyBookNestedId, 8));
    final (_, n) = _shown(t);
    final first = _view(t).spot!;
    await _tapNext(t);
    expect(_shown(t), (2, n));
    expect(_view(t).spot!.compareTo(first), greaterThan(0));
    expect(_location(t), '/library/book/tiny-nested/read/8');
    // The last page of the book's last chapter: no next page.
    for (var i = 2; i < n; i++) {
      await _tapNext(t);
    }
    expect(_shown(t), (n, n));
    expect(_enabled(t, _next), isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'turning past the chapter end shows the next chapter with no route '
    'transition and updates the address',
    (t) async {
      // "2-1-1" (n 7) is followed by "3" (n 8).
      await _open(t, Routes.bookReader(tinyBookNestedId, 7));
      final screen = t.state(find.byType(BookReaderScreen));
      var (i, n) = _shown(t);
      while (i < n) {
        await _tapNext(t);
        (i, n) = _shown(t);
      }
      await t.tap(_next);
      // Every frame of the turn shows one reader, the same one: no route
      // transition.
      for (var f = 0; f < 30; f++) {
        await t.pump(const Duration(milliseconds: 20));
        expect(find.byType(BookReaderScreen), findsOneWidget);
      }
      await t.pumpAndSettle();
      expect(t.state(find.byType(BookReaderScreen)), same(screen));
      expect(_location(t), '/library/book/tiny-nested/read/8');
      expect(_shown(t).$1, 1);
      expect(find.text(tinyLongBlocksTitle), findsOneWidget);
      // And back across into the last page of "2-1-1".
      await t.tap(_prev);
      await t.pumpAndSettle();
      expect(_location(t), '/library/book/tiny-nested/read/7');
      expect(_shown(t), (n, n));
      expect(t.state(find.byType(BookReaderScreen)), same(screen));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets("back after crossing goes to the new chapter's parent", (
    t,
  ) async {
    // "2-1-1" sits under "2-1"; "3" is top level, under the book.
    await _open(t, Routes.bookReader(tinyBookNestedId, 7));
    var (i, n) = _shown(t);
    while (i < n) {
      await _tapNext(t);
      (i, n) = _shown(t);
    }
    await _tapNext(t);
    expect(_location(t), '/library/book/tiny-nested/read/8');
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(_location(t), Routes.book(tinyBookNestedId));
    expect(t.takeException(), isNull);
  });

  testWidgets('another chapter asked for by address opens at its start', (
    t,
  ) async {
    await _open(t, Routes.bookReader(tinyBookNestedId, 8));
    await _tapNext(t);
    final screen = t.state(find.byType(BookReaderScreen));
    _container(t)
        .read(routerProvider)
        .go(Routes.bookReader(tinyBookNestedId, 3));
    await t.pumpAndSettle();
    expect(t.state(find.byType(BookReaderScreen)), same(screen));
    expect(find.text(tinyLongTitle), findsOneWidget);
    expect(_shown(t).$1, 1);
    expect(_view(t).spot, BookSpot.title);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'switched from Scroll to Pages in the reader, a crossing back has no '
    "route transition and opens the previous chapter's last page",
    (t) async {
      await _open(
        t,
        Routes.bookReader(tinyBookNestedId, 8),
        settings: _large.copyWith(bookReadingMode: BookReadingMode.scroll),
        books: _longSeven(),
      );
      expect(find.byType(BookPagesView), findsNothing);
      _container(t)
          .read(settingsProvider.notifier)
          .setBookReadingMode(BookReadingMode.pages);
      await t.pumpAndSettle();
      expect(_shown(t).$1, 1);
      await _turnWithoutTransition(t, _prev);
      expect(_location(t), '/library/book/tiny-nested/read/7');
      final (i, n) = _shown(t);
      expect(n, greaterThan(1));
      expect(i, n);
      // And forward again, in place.
      final screen = t.state(find.byType(BookReaderScreen));
      await _turnWithoutTransition(t, _next);
      expect(_location(t), '/library/book/tiny-nested/read/8');
      expect(_shown(t).$1, 1);
      expect(t.state(find.byType(BookReaderScreen)), same(screen));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'a crossing replaces the history entry, and device Back then goes to '
    "the new chapter's parent",
    (t) async {
      await _open(t, Routes.bookReader(tinyBookNestedId, 7));
      final reports = <Map<Object?, Object?>>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        (call) async {
          if (call.method == 'routeInformationUpdated') {
            reports.add(call.arguments as Map<Object?, Object?>);
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.navigation,
          null,
        ),
      );
      var (i, n) = _shown(t);
      while (i < n) {
        await _tapNext(t);
        (i, n) = _shown(t);
      }
      await _tapNext(t);
      expect(_location(t), '/library/book/tiny-nested/read/8');
      final toEight = reports.where(
        (r) => '${r['uri'] ?? r['location']}'.endsWith('/read/8'),
      );
      expect(toEight, isNotEmpty);
      expect(toEight.every((r) => r['replace'] == true), isTrue);
      // Device Back (the system's pop) leaves for the contents of "3", which
      // is top level: the book's page.
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(_location(t), Routes.book(tinyBookNestedId));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('with animations off the arrow turns with no curl', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _open(t, Routes.bookReader(tinyBookNestedId, 8));
    final (_, n) = _shown(t);
    await t.tap(_next);
    await t.pump();
    expect(_shown(t), (2, n));
    for (var f = 0; f < 20; f++) {
      expect(find.byKey(const ValueKey('page-curl-paint')), findsNothing);
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(_shown(t), (2, n));
    expect(t.takeException(), isNull);
  });

  testWidgets('Right arrow key and Page Down turn forward', (t) async {
    await _open(t, Routes.bookReader(tinyBookNestedId, 8));
    final (_, n) = _shown(t);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    expect(_shown(t), (2, n));
    await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await t.pumpAndSettle();
    expect(_shown(t), (3, n));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pumpAndSettle();
    expect(_shown(t), (2, n));
    await t.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await t.pumpAndSettle();
    expect(_shown(t), (1, n));
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'screen reader: Next page action turns and "Page 2 of N" is announced',
    (t) async {
      final h = t.ensureSemantics();
      await _open(t, Routes.bookReader(tinyBookNestedId, 8));
      final (_, n) = _shown(t);
      final area = t.getSemantics(find.byKey(const ValueKey('book-page-area')));
      final actions = {
        for (final id
            in area.getSemanticsData().customSemanticsActionIds ?? <int>[])
          CustomSemanticsAction.getAction(id)!.label,
      };
      expect(actions, {'Next page', 'Previous page'});
      t.takeAnnouncements();
      t.semantics.customAction(
        find.semantics.byPredicate((node) => node.id == area.id),
        _nextPage,
      );
      await t.pumpAndSettle();
      expect(_shown(t), (2, n));
      expect(
        t.takeAnnouncements().map((a) => a.message),
        contains('Page 2 of $n'),
      );
      h.dispose();
    },
  );

  testWidgets('the place is saved by spot and reopens on the same page', (
    t,
  ) async {
    await _open(t, Routes.bookReader(tinyBookNestedId, 8));
    final (_, n) = _shown(t);
    await _tapNext(t);
    await _tapNext(t);
    expect(_shown(t), (3, n));
    final spot = _view(t).spot!;
    await t.pump(const Duration(milliseconds: 500));
    final place = _stored(t);
    expect(place['n'], 8);
    expect(place['key'], '3');
    expect(place['spot'], [spot.block, spot.char]);

    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 8),
      storeExtras: {
        bookPlacesKey: jsonEncode({tinyBookNestedId: place}),
      },
    );
    expect(_shown(t), (3, n));
    expect(_view(t).spot, spot);
    expect(t.takeException(), isNull);
  });

  testWidgets('an offset-only place opens on the page holding that offset', (
    t,
  ) async {
    const offset = 700.0;
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 8),
      storeExtras: {
        bookPlacesKey: jsonEncode({
          tinyBookNestedId: {'n': 8, 'key': '3', 'offset': offset},
        }),
      },
    );
    // The line at that offset in the scroll column (350 wide on a 390
    // phone) is on the page shown, not before it and not after.
    final context = t.element(find.byType(BookPagesView));
    final styles = BookTextStyles.of(
      context,
      _container(t).read(settingsProvider),
    );
    final wanted = spotAtOffset(_book(t).page(8)!, styles, 350, offset);
    final (i, n) = _shown(t);
    expect(i, greaterThan(1));
    expect(_view(t).spot!.compareTo(wanted), lessThanOrEqualTo(0));
    expect(i, lessThan(n));
    await _tapNext(t);
    expect(_view(t).spot!.compareTo(wanted), greaterThan(0));
    // Saved again by its spot.
    await t.pump(const Duration(milliseconds: 500));
    expect(_stored(t)['spot'], isNotNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('bigger text keeps the same passage on screen', (t) async {
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 8),
      settings: const AppSettings(fontScale: 1.2),
    );
    await _tapNext(t);
    await _tapNext(t);
    final before = _view(t).spot!;
    final (_, smallCount) = _shown(t);
    _container(t).read(settingsProvider.notifier).setFontScale(1.6);
    await t.pumpAndSettle();
    final (i, bigCount) = _shown(t);
    expect(bigCount, greaterThan(smallCount));
    // The page shown holds the passage that was at the top.
    final after = _view(t).spot!;
    expect(after.compareTo(before), lessThanOrEqualTo(0));
    expect(i, lessThan(bigCount));
    await _tapNext(t);
    expect(_view(t).spot!.compareTo(before), greaterThan(0));
    expect(t.takeException(), isNull);
  });

  testWidgets("Scroll mode keeps today's bar and keys", (t) async {
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 8),
      settings: _large.copyWith(bookReadingMode: BookReadingMode.scroll),
    );
    expect(find.byType(BookPagesView), findsNothing);
    expect(find.byKey(const ValueKey('book-prev')), findsOneWidget);
    expect(find.byKey(const ValueKey('book-next')), findsOneWidget);
    expect(find.text('7 / 7'), findsOneWidget);
    expect(_next, findsNothing);
    expect(_count, findsNothing);
    expect(find.byType(Scrollable), findsWidgets);
    // A chapter step is still a new page of its own.
    final screen = t.state(find.byType(BookReaderScreen));
    await t.tap(find.byKey(const ValueKey('book-prev')));
    await t.pumpAndSettle();
    expect(_location(t), '/library/book/tiny-nested/read/7');
    expect(t.state(find.byType(BookReaderScreen)), isNot(same(screen)));
    expect(t.takeException(), isNull);
  });

  testWidgets('a wide window draws the page as a sheet in the reading column', (
    t,
  ) async {
    const size = Size(1280, 900);
    await _open(t, Routes.bookReader(tinyBookNestedId, 8), size: size);
    final sheet = find.byKey(const ValueKey('book-page-sheet'));
    expect(sheet, findsOneWidget);
    expect(t.getSize(sheet).width, NamoSizes.readingColumn);
    expect(t.getTopLeft(sheet).dx, (size.width - NamoSizes.readingColumn) / 2);
    expect(find.byType(PageSheet), findsWidgets);
    // The curl's edges are the sheet's.
    expect(
      t.getRect(find.byKey(const ValueKey('book-page-curl'))),
      t.getRect(sheet),
    );
    // A tap in the sheet's outer right fifth turns.
    final rect = t.getRect(sheet);
    final (_, n) = _shown(t);
    await t.tapAt(Offset(rect.right - 20, rect.center.dy));
    await t.pumpAndSettle();
    expect(_shown(t), (2, n));
    expect(t.takeException(), isNull);
  });

  testWidgets('a picture is cut and drawn at its own shape', (t) async {
    // "2-1-1" with its picture bundled: the square app icon.
    final books = tinyBooksWithLongBlocks();
    final path = tinyBookFile(tinyBookNestedId);
    final book = jsonDecode(jsonEncode(books[path])) as Map<String, dynamic>;
    final blocks = (book['pages'] as List)[6]['blocks'] as List;
    (blocks.last as Map)['asset'] = tinyBookCover;
    books[path] = book.cast<String, Object>();
    await _open(
      t,
      Routes.bookReader(tinyBookNestedId, 7),
      size: const Size(390, 2000),
      settings: const AppSettings(),
      books: books,
    );
    final picture = find.byType(BookPicture);
    expect(picture, findsOneWidget);
    // 350 wide at 1:1, not 4:3.
    expect(t.getSize(picture), const Size(350, 350));
    expect(t.takeException(), isNull);
  });

  test('pngSize reads a PNG header and nothing else', () {
    final png = ByteData(24)
      ..setUint32(0, 0x89504E47)
      ..setUint32(4, 0x0D0A1A0A)
      ..setUint32(16, 640)
      ..setUint32(20, 480);
    expect(pngSize(png), const Size(640, 480));
    expect(pngSize(ByteData(24)), isNull);
    expect(pngSize(ByteData(8)), isNull);
  });
}
