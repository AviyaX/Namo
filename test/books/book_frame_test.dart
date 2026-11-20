import 'package:buddhist_gatha/books/book_frame.dart';
import 'package:buddhist_gatha/books/book_pages_view.dart';
import 'package:buddhist_gatha/books/pagination/justified_lines.dart';
import 'package:buddhist_gatha/books/pagination/screen_page_view.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../tipitaka/tipitaka_support.dart';
import 'books_support.dart';

// The app's largest text on a short phone: "3" (n 8) is three pages.
const _phone = Size(390, 700);
const _large = AppSettings(fontScale: 1.6);
final _cover = find.byKey(const ValueKey('book-cover'));
final _paper = find.byKey(const ValueKey('book-paper'));
final _number = find.byKey(const ValueKey('book-page-number'));
final _corner = find.byKey(const ValueKey('book-corner'));
final _count = find.byKey(const ValueKey('book-page-count'));
final _next = find.byKey(const ValueKey('book-page-next'));

Finder _onPage(Finder f) => find.descendant(
  of: find.byKey(const ValueKey('page-curl-current')),
  matching: f,
);

Future<void> _open(
  WidgetTester t, {
  AppSettings settings = _large,
  bool dark = true,
}) async {
  await openReal(
    t,
    Routes.bookReader(tinyBookNestedId, 8),
    size: _phone,
    dark: dark,
    settings: settings,
    books: fakeAssets(tinyBooksWithLongBlocks()),
  );
  await t.pumpAndSettle();
}

String _numberText(WidgetTester t) => t
    .widget<Text>(find.descendant(of: _number, matching: find.byType(Text)))
    .data!;

/// The colours the text in [scope] is drawn in: the page's title and its
/// justified lines.
Set<Color?> _ink(WidgetTester t, Finder scope) => {
  for (final text in t.widgetList<Text>(
    find.descendant(of: scope, matching: find.text(tinyLongBlocksTitle)),
  ))
    text.style?.color,
  for (final lines in t.widgetList<JustifiedLines>(
    find.descendant(of: scope, matching: find.byType(JustifiedLines)),
  ))
    lines.style.color,
};

NamoPalette _palette(WidgetTester t) =>
    NamoPalette.of(t.element(find.byType(BookFrame)));

Color _paperColour(WidgetTester t) =>
    (t.widget<DecoratedBox>(_paper).decoration as BoxDecoration).color!;

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('Pages mode draws cover, paper, number and corner', (t) async {
    await _open(t);
    expect(_cover, findsOneWidget);
    expect(_paper, findsOneWidget);
    expect(_number, findsOneWidget);
    expect(_corner, findsOneWidget);
    expect(_numberText(t), '1');
    expect(t.widget<Text>(_count).data, '1 of 3');
    // The paper sits inside the cover; the page turns inside the rule.
    final cover = t.getRect(_cover), paper = t.getRect(_paper);
    expect(paper, cover.deflate(bookCoverInset));
    final inside = paper.deflate(bookRuleWidth);
    expect(t.getRect(find.byKey(const ValueKey('book-page-curl'))), inside);
    // The number at the foot, the corner at the bottom right.
    final number = t.getRect(_number), corner = t.getRect(_corner);
    expect(number.center.dx, moreOrLessEquals(paper.center.dx, epsilon: 1));
    expect(number.bottom, lessThan(paper.bottom));
    expect(number.top, greaterThan(paper.center.dy));
    expect(corner.bottomRight, inside.bottomRight);
    // The text keeps clear of the number and the spine.
    final text = t.getRect(_onPage(find.byType(ScreenPageView)));
    expect(text.bottom, lessThanOrEqualTo(number.top));
    expect(text.left, greaterThan(inside.left + bookPaperPadding));

    await t.tap(_next);
    await t.pumpAndSettle();
    expect(t.widget<Text>(_count).data, '2 of 3');
    expect(_numberText(t), '2');
    expect(t.takeException(), isNull);
  });

  testWidgets('the page number is not read out a second time', (t) async {
    final handle = t.ensureSemantics();
    await _open(t);
    expect(find.bySemanticsLabel(RegExp(r'^1$')), findsNothing);
    handle.dispose();
  });

  testWidgets('Scroll mode draws cover and paper without number or corner', (
    t,
  ) async {
    await _open(
      t,
      settings: _large.copyWith(bookReadingMode: BookReadingMode.scroll),
    );
    expect(find.byType(BookPagesView), findsNothing);
    expect(_cover, findsOneWidget);
    expect(_paper, findsOneWidget);
    expect(_number, findsNothing);
    expect(_corner, findsNothing);
    // The text scrolls on the paper, as wide as the reader measures it.
    final paper = t.getRect(_paper);
    final title = t.getRect(find.text(tinyLongBlocksTitle));
    expect(title.left, paper.left + bookRuleWidth + bookPaperPadding);
    expect(
      paper.width - 2 * (bookRuleWidth + bookPaperPadding),
      bookScrollTextWidth(_phone.width),
    );
    expect(t.takeException(), isNull);
  });

  group('ink follows the paper, not the theme', () {
    testWidgets('cream paper in the dark theme', (t) async {
      await _open(t, dark: true);
      final p = _palette(t);
      expect(_paperColour(t), p.bookPaper);
      expect(_ink(t, _onPage(find.byType(ScreenPageView))), {p.bookInk});
      final number = t.widget<Text>(
        find.descendant(of: _number, matching: find.byType(Text)),
      );
      expect(number.style!.color, p.bookInkSoft);
    });

    testWidgets('dark paper in the light theme', (t) async {
      await _open(
        t,
        dark: false,
        settings: _large.copyWith(bookPaper: BookPaper.dark),
      );
      final p = _palette(t);
      expect(_paperColour(t), p.bookPaperDark);
      expect(_ink(t, _onPage(find.byType(ScreenPageView))), {p.bookInkDark});
    });

    testWidgets('in Scroll mode too', (t) async {
      await _open(
        t,
        dark: true,
        settings: _large.copyWith(bookReadingMode: BookReadingMode.scroll),
      );
      final p = _palette(t);
      expect(_paperColour(t), p.bookPaper);
      expect(_ink(t, _paper), {p.bookInk});
    });
  });

  testWidgets('switching paper keeps the page', (t) async {
    await _open(t);
    await t.tap(_next);
    await t.pumpAndSettle();
    final view = t.state<BookPagesViewState>(find.byType(BookPagesView));
    final spot = view.spot;
    final page = t
        .widget<ScreenPageView>(_onPage(find.byType(ScreenPageView)))
        .page;
    expect(t.widget<Text>(_count).data, '2 of 3');

    ProviderScope.containerOf(t.element(find.byType(BookPagesView)))
        .read(settingsProvider.notifier)
        .setBookPaper(BookPaper.dark);
    await t.pumpAndSettle();

    final p = _palette(t);
    expect(_paperColour(t), p.bookPaperDark);
    expect(_ink(t, _onPage(find.byType(ScreenPageView))), {p.bookInkDark});
    expect(t.widget<Text>(_count).data, '2 of 3');
    expect(_numberText(t), '2');
    expect(view.spot, spot);
    // Not cut again: the very page that was shown.
    expect(
      t.widget<ScreenPageView>(_onPage(find.byType(ScreenPageView))).page,
      same(page),
    );
    expect(t.takeException(), isNull);
  });

  group('BookFrame', () {
    Widget host(Widget child) => Theme(
      data: ThemeData(extensions: const [NamoPalette.dark]),
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SizedBox(width: 300, height: 400, child: child)),
        ),
      ),
    );

    testWidgets('the child fills the paper inside the rule', (t) async {
      await t.pumpWidget(
        host(
          const BookFrame(
            paper: BookPaper.cream,
            pageMarks: true,
            pageNumber: 7,
            child: SizedBox.expand(key: ValueKey('child')),
          ),
        ),
      );
      final child = t.getRect(find.byKey(const ValueKey('child')));
      expect(child, t.getRect(_cover).deflate(bookCoverInset + bookRuleWidth));
      expect(_numberText(t), '7');
      expect(_corner, findsOneWidget);
      expect(find.byKey(const ValueKey('book-spine')), findsOneWidget);
    });

    testWidgets('without page marks: no spine, number or corner', (t) async {
      await t.pumpWidget(
        host(
          const BookFrame(
            paper: BookPaper.dark,
            pageMarks: false,
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(_number, findsNothing);
      expect(_corner, findsNothing);
      expect(find.byKey(const ValueKey('book-spine')), findsNothing);
    });

    testWidgets('with page marks the text keeps off the spine and the foot', (
      t,
    ) async {
      late EdgeInsets marks, plain;
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) {
              marks = bookTextInsets(context, pageMarks: true);
              plain = bookTextInsets(context, pageMarks: false);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(plain, const EdgeInsets.all(bookPaperPadding));
      expect(marks.left, greaterThan(plain.left));
      expect(marks.left, greaterThanOrEqualTo(bookSpineWidth));
      expect(marks.right, plain.right);
      expect(marks.top, plain.top);
      expect(marks.bottom, greaterThan(plain.bottom));
    });
  });
}
