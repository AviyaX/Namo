import 'package:buddhist_gatha/books/book_blocks.dart';
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

String _numberText(WidgetTester t) => t.widget<Text>(_number).data!;

String _runningTitle(WidgetTester t) =>
    t.widget<Text>(find.byKey(const ValueKey('book-running-title'))).data!;

/// The colours the text in [scope] is drawn in: its justified lines, its
/// paragraphs and its list and footnote items (the title has its own brown).
Set<Color?> _ink(WidgetTester t, Finder scope) => {
  for (final text in t.widgetList<Text>(
    find.descendant(of: scope, matching: find.byType(Text)),
  ))
    if (text.data != null &&
        (text.data!.startsWith(bookParaLead) ||
            text.data!.startsWith('Item ') ||
            text.data!.startsWith('Note ')))
      text.style?.color,
  for (final lines in t.widgetList<JustifiedLines>(
    find.descendant(of: scope, matching: find.byType(JustifiedLines)),
  ))
    lines.style.color,
};

/// Checks the text in [scope] is drawn in [paper]'s ink: its text ink, and
/// for captions and footnotes its secondary ink, nothing else.
void _expectInk(WidgetTester t, Finder scope, BookPaper paper) {
  final c = bookColours(_palette(t), paper);
  final ink = _ink(t, scope);
  expect(ink, contains(c.ink));
  expect(ink.difference({c.ink, c.inkSecondary}), isEmpty);
}

/// The colour of the chapter's title in [scope].
Color? _titleInk(WidgetTester t, Finder scope) => t
    .widget<Text>(
      find.descendant(of: scope, matching: find.text(tinyLongBlocksTitle)),
    )
    .style
    ?.color;

NamoPalette _palette(WidgetTester t) =>
    NamoPalette.of(t.element(find.byType(BookFrame)));

Color _paperColour(WidgetTester t) =>
    (t.widget<DecoratedBox>(_paper).decoration as BoxDecoration).color!;

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('Pages mode draws cover, paper, running head and corner', (
    t,
  ) async {
    await _open(t);
    expect(_cover, findsOneWidget);
    expect(_paper, findsOneWidget);
    expect(_number, findsOneWidget);
    expect(_corner, findsOneWidget);
    expect(_numberText(t), '1');
    final count = t.widget<Text>(_count).data!;
    expect(count, startsWith('1 of '));
    // The paper sits inside the cover; the page turns inside the rule.
    final cover = t.getRect(_cover), paper = t.getRect(_paper);
    expect(paper, cover.deflate(bookCoverInset));
    final inside = paper.deflate(bookRuleWidth);
    expect(t.getRect(find.byKey(const ValueKey('book-page-curl'))), inside);
    // Page 1 is a right-hand page: the number in the top right corner, the
    // chapter's title in the running head, the spine on the left.
    final number = t.getRect(_number), corner = t.getRect(_corner);
    expect(number.top, lessThan(paper.center.dy));
    expect(number.right, greaterThan(paper.center.dx));
    expect(_runningTitle(t), tinyLongBlocksTitle);
    expect(corner.bottomRight, inside.bottomRight);
    final spine = t.getRect(find.byKey(const ValueKey('book-spine')));
    expect(spine.left, inside.left);
    // The text keeps below the running head and clear of the spine.
    final text = t.getRect(_onPage(find.byType(ScreenPageView)));
    expect(text.top, greaterThanOrEqualTo(number.bottom));
    expect(text.left, greaterThan(inside.left + bookPaperPadding));
    expect(
      inside.right - text.right,
      lessThan(text.left - inside.left),
      reason: 'the wider margin is on the spine side',
    );

    await t.tap(_next);
    await t.pumpAndSettle();
    expect(t.widget<Text>(_count).data, startsWith('2 of '));
    // Page 2 is a left-hand page: the number on the left, the book's title,
    // the spine on the right.
    expect(_numberText(t), '2');
    expect(t.getRect(_number).left, lessThan(paper.center.dx));
    expect(_runningTitle(t), 'Nested book');
    expect(
      t.getRect(find.byKey(const ValueKey('book-spine'))).right,
      inside.right,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('the chapter opens with its title in brown and a flourish', (
    t,
  ) async {
    await _open(t, dark: false);
    final page = _onPage(find.byType(ScreenPageView));
    final p = _palette(t);
    expect(_titleInk(t, page), bookColours(p, BookPaper.cream).title);
    expect(
      find.descendant(
        of: page,
        matching: find.byKey(const ValueKey('book-flourish')),
      ),
      findsOneWidget,
    );
    // Centred, a little way down the page.
    final title = t.widget<Text>(
      find.descendant(of: page, matching: find.text(tinyLongBlocksTitle)),
    );
    expect(title.textAlign, TextAlign.center);
    expect(
      t
              .getRect(
                find.descendant(
                  of: page,
                  matching: find.text(tinyLongBlocksTitle),
                ),
              )
              .top -
          t.getRect(page).top,
      greaterThanOrEqualTo(bookTitleSink),
    );
  });

  testWidgets('sideways the book lies open: two pages, turned two at a time', (
    t,
  ) async {
    await openReal(
      t,
      Routes.bookReader(tinyBookNestedId, 8),
      size: const Size(1000, 600),
      settings: _large,
      books: fakeAssets(tinyBooksWithLongBlocks()),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('book-spread')), findsOneWidget);
    final left = t.getRect(find.byKey(const ValueKey('book-paper-left')));
    final right = t.getRect(_paper);
    expect(left.right, lessThanOrEqualTo(right.left));
    expect(left.width, moreOrLessEquals(right.width, epsilon: 1));
    expect(t.widget<Text>(_count).data, startsWith('1–2 of '));
    final numbers = [for (final n in t.widgetList<Text>(_number)) n.data];
    expect(numbers, ['1', '2']);
    await t.tap(_next);
    await t.pumpAndSettle();
    expect(t.widget<Text>(_count).data, startsWith('3'));
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
    // A little way down the paper, as a chapter opens in Pages mode.
    expect(
      title.top,
      paper.top + bookRuleWidth + bookPaperPadding + bookTitleSink,
    );
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
      _expectInk(t, _onPage(find.byType(ScreenPageView)), BookPaper.cream);
      final number = t.widget<Text>(_number);
      expect(number.style!.color, p.bookInkSoft);
      // Captions and footnotes take the darker secondary ink, which reads
      // at 4.5:1 on cream; the soft ink is the page number's only.
      final styles = BookTextStyles.onPaper(
        t.element(find.byType(BookFrame)),
        _large,
      );
      expect(styles.caption.color, p.bookInkSecondary);
    });

    testWidgets('dark paper in the light theme', (t) async {
      await _open(
        t,
        dark: false,
        settings: _large.copyWith(bookPaper: BookPaper.dark),
      );
      final p = _palette(t);
      expect(_paperColour(t), p.bookPaperDark);
      _expectInk(t, _onPage(find.byType(ScreenPageView)), BookPaper.dark);
    });

    testWidgets('in Scroll mode too', (t) async {
      await _open(
        t,
        dark: true,
        settings: _large.copyWith(bookReadingMode: BookReadingMode.scroll),
      );
      final p = _palette(t);
      expect(_paperColour(t), p.bookPaper);
      _expectInk(t, _paper, BookPaper.cream);
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
    final count = t.widget<Text>(_count).data;
    expect(count, startsWith('2 of '));

    ProviderScope.containerOf(t.element(find.byType(BookPagesView)))
        .read(settingsProvider.notifier)
        .setBookPaper(BookPaper.dark);
    await t.pumpAndSettle();

    final p = _palette(t);
    expect(_paperColour(t), p.bookPaperDark);
    _expectInk(t, _onPage(find.byType(ScreenPageView)), BookPaper.dark);
    expect(t.widget<Text>(_count).data, count);
    expect(_numberText(t), '2');
    expect(view.spot, spot);
    // Not cut again: the very page that was shown.
    expect(
      t.widget<ScreenPageView>(_onPage(find.byType(ScreenPageView))).page,
      same(page),
    );
    expect(t.takeException(), isNull);
  });

  group('a page held while the text is cut again is drawn in the new ink', () {
    SettingsController settings(WidgetTester t) =>
        ProviderScope.containerOf(t.element(find.byType(BookPagesView)))
            .read(settingsProvider.notifier);

    ScreenPageView shown(WidgetTester t) =>
        t.widget<ScreenPageView>(_onPage(find.byType(ScreenPageView)));

    testWidgets('paper switched, then the text size', (t) async {
      await _open(t);
      await t.tap(_next);
      await t.pumpAndSettle();
      final page = shown(t).page;
      settings(t).setBookPaper(BookPaper.dark);
      await t.pump();
      settings(t).setFontScale(1.2);
      await t.pump();
      // Still the page as it was cut, held until its passage is cut again.
      expect(shown(t).page, same(page));
      _expectInk(t, _onPage(find.byType(ScreenPageView)), BookPaper.dark);
      await t.pumpAndSettle();
      _expectInk(t, _onPage(find.byType(ScreenPageView)), BookPaper.dark);
      expect(t.takeException(), isNull);
    });

    testWidgets('paper and text size changed at once', (t) async {
      await _open(t);
      await t.tap(_next);
      await t.pumpAndSettle();
      final page = shown(t).page;
      // The page is held with the styles it was cut with: the old ink.
      settings(t).setFontScale(1.2);
      settings(t).setBookPaper(BookPaper.dark);
      await t.pump();
      expect(shown(t).page, same(page));
      _expectInk(t, _onPage(find.byType(ScreenPageView)), BookPaper.dark);
      await t.pumpAndSettle();
      _expectInk(t, _onPage(find.byType(ScreenPageView)), BookPaper.dark);
      expect(t.takeException(), isNull);
    });
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

    testWidgets('with page marks the text keeps off the spine and the head', (
      t,
    ) async {
      late EdgeInsets right, left, plain;
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) {
              right = bookTextInsets(context, pageMarks: true);
              left = bookTextInsets(
                context,
                pageMarks: true,
                side: BookSide.left,
              );
              plain = bookTextInsets(context, pageMarks: false);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(plain, const EdgeInsets.all(bookPaperPadding));
      // A right-hand page's spine is on its left; a left-hand page's on its
      // right; the text is as wide on either.
      expect(right.left, greaterThan(plain.left));
      expect(right.left, greaterThanOrEqualTo(bookSpineWidth));
      expect(right.right, plain.right);
      expect(left.right, right.left);
      expect(left.left, right.right);
      // Room at the top for the running head; none at the foot.
      expect(right.top, greaterThan(plain.top));
      expect(right.bottom, plain.bottom);
    });

    test('odd page numbers are right-hand pages', () {
      expect(BookSide.ofNumber(1), BookSide.right);
      expect(BookSide.ofNumber(2), BookSide.left);
      expect(BookSide.ofNumber(15), BookSide.right);
    });
  });
}
