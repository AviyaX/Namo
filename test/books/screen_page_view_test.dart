import 'package:buddhist_gatha/books/book_blocks.dart';
import 'package:buddhist_gatha/books/book_model.dart';
import 'package:buddhist_gatha/books/pagination/book_paginator.dart';
import 'package:buddhist_gatha/books/pagination/screen_page_view.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BookPage _chapter(List<BookBlock> blocks) => BookPage(
  n: 1,
  key: '1',
  level: 1,
  title: 'A chapter',
  url: 'https://example.invalid/1.html',
  blocks: blocks,
);

String _words(int seed, int words) => [
  'Paragraph $seed',
  for (var w = 0; w < words; w++)
    const ['alpha', 'bravo', 'charlie', 'delta', 'echo', 'foxtrot'][(seed + w) %
        6],
].join(' ');

Widget _host(Widget child, {double width = 360, double textScale = 1}) => Theme(
  data: ThemeData(extensions: const [NamoPalette.light]),
  child: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

BookTextStyles _styles(double fontScale) => BookTextStyles.from(
  palette: NamoPalette.light,
  settings: AppSettings(fontScale: fontScale),
);

void main() {
  testWidgets('draws exactly the slices text', (t) async {
    const text = 'Alpha bravo charlie delta echo foxtrot golf hotel india.';
    final chapter = _chapter([const BookPara(text), BookPara(_words(2, 8))]);
    final pages = paginate(
      chapter,
      _styles(1),
      const PageBox(width: 360, height: 640),
    ).toList();
    await t.pumpWidget(
      _host(
        ScreenPageView(
          chapter: chapter,
          page: pages.first,
          styles: _styles(1),
          sheet: false,
        ),
      ),
    );
    expect(find.text('A chapter'), findsOneWidget);
    expect(find.text(text), findsOneWidget);
    expect(find.text(_words(2, 8)), findsOneWidget);
  });

  testWidgets('a sheet page draws on paper', (t) async {
    final chapter = _chapter([BookPara(_words(1, 8))]);
    final pages = paginate(
      chapter,
      _styles(1),
      const PageBox(width: 320, height: 600),
    ).toList();
    await t.pumpWidget(
      _host(
        ScreenPageView(
          chapter: chapter,
          page: pages.first,
          styles: _styles(1),
          sheet: true,
        ),
      ),
    );
    expect(find.byType(PageSheet), findsOneWidget);
  });

  testWidgets('no overflow at 320 wide with fontScale 1.6', (t) async {
    final chapter = _chapter([
      for (var i = 0; i < 12; i++) ...[
        if (i % 4 == 0) BookHeading('Heading $i'),
        BookPara(_words(i, 20 + i * 15)),
      ],
      const BookGatha(['A verse line one', 'A verse line two']),
      const BookList(
        marker: ListMarker.number,
        start: 1,
        items: ['One item', 'Another item'],
      ),
    ]);
    final styles = _styles(1.6);
    const box = PageBox(width: 320, height: 560);
    final pages = paginate(chapter, styles, box).toList();
    expect(pages.length, greaterThan(2));
    t.view.physicalSize = const Size(320, 560);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final page in pages) {
      await t.pumpWidget(
        _host(
          SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: ScreenPageView(
              chapter: chapter,
              page: page,
              styles: styles,
              sheet: false,
            ),
          ),
          width: 320,
        ),
      );
      expect(t.takeException(), isNull);
      final size = t.getSize(find.byType(ScreenPageView));
      expect(size.height, lessThanOrEqualTo(box.height + 0.01));
    }
  });

  testWidgets('the title is a header for screen readers', (t) async {
    final handle = t.ensureSemantics();
    final chapter = _chapter([BookPara(_words(1, 8))]);
    final pages = paginate(
      chapter,
      _styles(1),
      const PageBox(width: 360, height: 640),
    ).toList();
    await t.pumpWidget(
      _host(
        ScreenPageView(
          chapter: chapter,
          page: pages.first,
          styles: _styles(1),
          sheet: false,
        ),
      ),
    );
    expect(
      t.getSemantics(find.text('A chapter')),
      matchesSemantics(label: 'A chapter', isHeader: true),
    );
    handle.dispose();
  });
}
