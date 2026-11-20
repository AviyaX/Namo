import 'package:buddhist_gatha/books/book_blocks.dart';
import 'package:buddhist_gatha/books/book_model.dart';
import 'package:buddhist_gatha/books/book_places.dart';
import 'package:buddhist_gatha/books/pagination/book_paginator.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

const _box = PageBox(width: 360, height: 640);

BookTextStyles _styles({double fontScale = 1.0}) => BookTextStyles.from(
  palette: NamoPalette.light,
  settings: AppSettings(fontScale: fontScale),
);

/// A made-up paragraph of about [words] words.
String _words(int seed, int words) => [
  'Paragraph $seed',
  for (var w = 0; w < words; w++)
    const ['alpha', 'bravo', 'charlie', 'delta', 'echo', 'foxtrot'][(seed + w) %
        6],
].join(' ');

BookPage _chapter(List<BookBlock> blocks, {String title = 'A chapter'}) =>
    BookPage(
      n: 1,
      key: '1',
      level: 1,
      title: title,
      url: 'https://example.invalid/1.html',
      blocks: blocks,
    );

/// Thirty paragraphs of 5 to 150 words.
List<BookBlock> _thirtyParagraphs() => [
  for (var i = 0; i < 30; i++) BookPara(_words(i, 5 + (i * 37) % 146)),
];

/// Paragraphs with headings and subheads between them.
List<BookBlock> _withHeadings() => [
  for (var i = 0; i < 24; i++) ...[
    if (i % 3 == 0) BookHeading('Heading $i'),
    if (i % 4 == 1) BookSubhead('Subhead $i'),
    BookPara(_words(i, 10 + (i * 29) % 90)),
  ],
];

/// How many lines [text] takes at [width] in [style].
int _lineCount(String text, TextStyle style, double width) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return lines;
}

/// The drawing of [slice], as Task 4's page will draw it, to measure it
/// independently of the paginator.
Widget _draw(BookPage page, PageSlice slice, BookTextStyles s) {
  switch (slice) {
    case TitleSlice():
      return Text(page.title, style: s.title);
    case BlockSlice(:final block):
      return BookBlockView(
        block: page.blocks[block],
        styles: s,
        fitTables: true,
      );
    case LinesSlice(
      :final block,
      :final item,
      :final charStart,
      :final charEnd,
    ):
      final b = page.blocks[block];
      final whole = switch (b) {
        BookPara(:final text) => (text, s.prose),
        BookHeading(:final text) => (text, s.heading),
        BookSubhead(:final text) => (text, s.strong),
        _ => null,
      };
      if (whole case (final text, final style)) {
        return Text(text.substring(charStart, charEnd), style: style);
      }
      final (labels, items, style, minLead) = switch (b) {
        final BookList l => (listLabels(l), l.items, s.prose, listMinLead),
        final BookFootnotes f => (
          footnoteLabels(f),
          f.items,
          s.caption,
          footnoteMinLead,
        ),
        _ => throw StateError('lines of $b'),
      };
      final lead = leadWidth(labels, style, minLead, s.scaler, s.direction);
      final label = labels[item];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (b is BookFootnotes && item == 0 && charStart == 0)
            FootnoteRule(color: s.border),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null)
                SizedBox(
                  width: lead,
                  child: charStart == 0
                      ? Text(label, style: style, softWrap: false)
                      : null,
                ),
              Expanded(
                child: Text(
                  items[item].substring(charStart, charEnd),
                  style: style,
                ),
              ),
            ],
          ),
        ],
      );
    case GathaSlice(:final block, :final fromLine, :final toLine):
      final g = page.blocks[block] as BookGatha;
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: gathaIndent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in g.lines.sublist(fromLine, toLine))
              Text(line, style: s.prose),
          ],
        ),
      );
    case TableSlice(
      :final block,
      :final fromRow,
      :final toRow,
      :final repeatHeader,
    ):
      final t = page.blocks[block] as BookTable;
      return BookTableView(
        rows: t.rows,
        border: s.border,
        styleOf: (r) => s.tableRow(t, r),
        fitWidth: true,
        repeatHeader: repeatHeader,
        fromRow: fromRow,
        toRow: toRow,
      );
    case ImageSlice(:final height):
      return SizedBox(height: height);
  }
}

/// Draws each of [pages] with real widgets and checks every slice is as
/// tall as the paginator measured, sits where it said, and the page fits.
Future<void> _expectDrawnAsMeasured(
  WidgetTester t,
  BookPage page,
  List<ScreenPage> pages,
  BookTextStyles s,
  PageBox box,
) async {
  t.view.physicalSize = Size(box.width + 40, box.height + 200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  for (var i = 0; i < pages.length; i++) {
    final slices = pages[i].slices;
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: box.width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < slices.length; j++) ...[
                    SizedBox(
                      height: gapBefore(
                        j == 0 ? null : slices[j - 1],
                        slices[j],
                      ),
                    ),
                    KeyedSubtree(
                      key: ValueKey('slice-$j'),
                      child: _draw(page, slices[j], s),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    var bottom = 0.0;
    for (var j = 0; j < slices.length; j++) {
      final rect = t.getRect(find.byKey(ValueKey('slice-$j')));
      expect(
        rect.top,
        moreOrLessEquals(slices[j].top, epsilon: 0.01),
        reason: 'page $i slice $j top',
      );
      expect(
        rect.height,
        moreOrLessEquals(slices[j].height, epsilon: 0.01),
        reason: 'page $i slice $j ${slices[j]}',
      );
      bottom = rect.bottom;
    }
    expect(bottom, lessThanOrEqualTo(box.height + 0.01), reason: 'page $i');
  }
}

/// The text of each block as the slices give it, joined in order.
Map<int, String> _textBySlices(BookPage page, List<ScreenPage> pages) {
  final out = <int, StringBuffer>{};
  for (final p in pages) {
    for (final s in p.slices) {
      switch (s) {
        case BlockSlice(:final block):
          out
              .putIfAbsent(block, StringBuffer.new)
              .write((page.blocks[block] as BookPara).text);
        case LinesSlice(:final block, :final charStart, :final charEnd):
          out
              .putIfAbsent(block, StringBuffer.new)
              .write(
                (page.blocks[block] as BookPara).text.substring(
                  charStart,
                  charEnd,
                ),
              );
        default:
      }
    }
  }
  return {for (final e in out.entries) e.key: e.value.toString()};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  test('a short chapter is one page starting with its title', () {
    final page = _chapter([const BookPara('A short paragraph.')]);
    final pages = paginate(page, _styles(), _box).toList();
    expect(pages, hasLength(1));
    expect(pages[0].slices.first, isA<TitleSlice>());
    expect(pages[0].start, BookSpot.title);
    expect(pages[0].slices[1], isA<BlockSlice>());
    expect(pages[0].slices[1].top, greaterThan(NamoSpace.lg));
  });

  test('no text lost or repeated', () {
    final page = _chapter(_thirtyParagraphs());
    final pages = paginate(page, _styles(fontScale: 1.6), _box).toList();
    expect(pages.length, greaterThan(5));
    final joined = _textBySlices(page, pages);
    expect(joined.keys.toList(), [for (var i = 0; i < 30; i++) i]);
    for (var i = 0; i < 30; i++) {
      expect(joined[i], (page.blocks[i] as BookPara).text, reason: 'block $i');
    }
  });

  test('the slices run in reading order', () {
    final page = _chapter(_withHeadings());
    final pages = paginate(page, _styles(fontScale: 1.3), _box).toList();
    final spots = [
      for (final p in pages)
        for (final s in p.slices) s.spot,
    ];
    for (var i = 1; i < spots.length; i++) {
      expect(spots[i].compareTo(spots[i - 1]), greaterThan(0));
    }
  });

  testWidgets('no page is taller than the box', (t) async {
    for (final scale in [1.0, 1.6]) {
      final s = _styles(fontScale: scale);
      final page = _chapter([
        ..._withHeadings().take(12),
        const BookGatha(['Verse line one', 'Verse line two', 'Line three']),
        BookList(
          marker: ListMarker.number,
          start: 1,
          items: [for (var i = 0; i < 9; i++) _words(i, 4 + i * 9)],
        ),
        BookTable(
          header: true,
          rows: [
            ['Name', 'Count'],
            for (var r = 1; r < 25; r++) ['Row $r', '$r'],
          ],
        ),
        ..._thirtyParagraphs().take(6),
        BookFootnotes([for (var i = 0; i < 10; i++) _words(i, 3 + i * 7)]),
      ]);
      final pages = paginate(page, s, _box).toList();
      await _expectDrawnAsMeasured(t, page, pages, s, _box);
      // Lists and footnotes were cut between their items.
      final all = [for (final p in pages) ...p.slices];
      expect(
        all.where(
          (slice) =>
              slice is LinesSlice && page.blocks[slice.block] is! BookPara,
        ),
        isNotEmpty,
        reason: 'at font scale $scale',
      );
      expect(all.whereType<TableSlice>(), isNotEmpty);
    }
  });

  test('no single orphan or widow line', () {
    final s = _styles(fontScale: 1.6);
    final page = _chapter(_thirtyParagraphs());
    for (final height in [640.0, 500.0, 433.0]) {
      final pages = paginate(
        page,
        s,
        PageBox(width: _box.width, height: height),
      ).toList();
      final pieces = <int, List<int>>{};
      for (final p in pages) {
        for (final slice in p.slices) {
          if (slice case LinesSlice(
            :final block,
            :final charStart,
            :final charEnd,
          )) {
            final text = (page.blocks[block] as BookPara).text;
            pieces
                .putIfAbsent(block, () => [])
                .add(
                  _lineCount(
                    text.substring(charStart, charEnd),
                    s.prose,
                    _box.width,
                  ),
                );
          }
        }
      }
      expect(pieces, isNotEmpty);
      for (final MapEntry(key: block, value: lines) in pieces.entries) {
        final total = lines.fold(0, (a, b) => a + b);
        if (total < 4) continue;
        expect(
          lines.every((l) => l >= 2),
          isTrue,
          reason: 'block $block split as $lines at height $height',
        );
      }
    }
  });

  test('a heading never ends a page', () {
    final page = _chapter(_withHeadings());
    for (var height = 300.0; height <= 640; height += 23) {
      final pages = paginate(
        page,
        _styles(fontScale: 1.3),
        PageBox(width: _box.width, height: height),
      ).toList();
      for (final p in pages.take(pages.length - 1)) {
        final last = p.slices.last;
        expect(
          last is BlockSlice && page.blocks[last.block] is BookHeading ||
              last is BlockSlice && page.blocks[last.block] is BookSubhead,
          isFalse,
          reason: 'height $height page starting ${p.start}',
        );
      }
    }
  });

  testWidgets('a subhead taller than a page breaks by lines', (t) async {
    final s = _styles(fontScale: 1.6);
    const box = PageBox(width: 360, height: 240);
    final subhead = BookSubhead(_words(7, 60));
    final page = _chapter([const BookPara('Before.'), subhead]);
    final pages = paginate(page, s, box).toList();
    final pieces = [
      for (final p in pages)
        for (final slice in p.slices)
          if (slice is LinesSlice) slice,
    ];
    expect(pieces.length, greaterThan(1));
    expect(
      pieces.map((p) => subhead.text.substring(p.charStart, p.charEnd)).join(),
      subhead.text,
    );
    await _expectDrawnAsMeasured(t, page, pages, s, box);
  });

  test('a gatha that fits stays whole', () {
    const gatha = BookGatha([
      'Verse line one',
      'Verse line two',
      'Verse line three',
      'Verse line four',
      'Verse line five',
      'Verse line six',
    ]);
    final page = _chapter([..._thirtyParagraphs().take(4), gatha]);
    for (var height = 300.0; height <= 640; height += 17) {
      final pages = paginate(
        page,
        _styles(fontScale: 1.6),
        PageBox(width: _box.width, height: height),
      ).toList();
      final slices = [
        for (final p in pages)
          for (final s in p.slices)
            if (s.block == 4) s,
      ];
      expect(slices, hasLength(1), reason: 'height $height');
      expect(slices.single, isA<BlockSlice>());
    }
  });

  testWidgets('a tall table breaks between rows and repeats its header', (
    t,
  ) async {
    final s = _styles();
    final page = _chapter([
      const BookPara('Before the table.'),
      BookTable(
        header: true,
        rows: [
          ['Name', 'Count', 'Note'],
          for (var r = 1; r < 40; r++) ['Row $r', '$r', 'A note'],
        ],
      ),
    ]);
    final pages = paginate(page, s, _box).toList();
    final tables = [
      for (final p in pages)
        for (final slice in p.slices)
          if (slice is TableSlice) slice,
    ];
    expect(tables.length, greaterThan(1));
    expect(tables.first.fromRow, 0);
    expect(tables.first.repeatHeader, isFalse);
    final covered = <int>[];
    for (final (i, slice) in tables.indexed) {
      if (i > 0) expect(slice.repeatHeader, isTrue);
      for (var r = slice.fromRow; r < slice.toRow; r++) {
        if (r > 0) covered.add(r);
      }
    }
    expect(covered, [for (var r = 1; r < 40; r++) r]);
    await _expectDrawnAsMeasured(t, page, pages, s, _box);
  });

  testWidgets('a wide table is shrunk to the width', (t) async {
    final s = _styles(fontScale: 1.6);
    final page = _chapter([
      BookTable(
        header: false,
        rows: [
          [for (var c = 0; c < 9; c++) 'Wide$c'],
          [for (var c = 0; c < 9; c++) 'Cell$c'],
        ],
      ),
    ]);
    final pages = paginate(page, s, _box).toList();
    expect(pages, hasLength(1));
    await _expectDrawnAsMeasured(t, page, pages, s, _box);
    final table = t.getRect(find.byType(Table));
    expect(table.width, lessThanOrEqualTo(_box.width + 0.01));
  });

  test('a picture taller than the page is scaled to fit', () {
    final page = _chapter([
      const BookPara('Before the picture.'),
      const BookImage(
        src: 'https://example.invalid/tall.png',
        alt: 'A tall picture',
        asset: 'assets/branding/namo_icon_square.png',
      ),
    ]);
    final pages = paginate(
      page,
      _styles(),
      _box,
      imageSize: (_) => const Size(100, 400),
    ).toList();
    final image = [
      for (final p in pages)
        for (final s in p.slices)
          if (s is ImageSlice) s,
    ].single;
    expect(image.scale, lessThan(1));
    expect(image.height, lessThanOrEqualTo(_box.height));
    expect(image.height, moreOrLessEquals(_box.height));
    expect(image.top, 0, reason: 'on a page of its own');
  });

  test('a picture that fits is drawn at full size', () {
    final page = _chapter([
      const BookImage(
        src: 'https://example.invalid/square.png',
        alt: 'A picture',
        asset: 'assets/branding/namo_icon_square.png',
      ),
    ]);
    final image =
        paginate(page, _styles(), _box).single.slices.last as ImageSlice;
    expect(image.scale, 1);
    expect(image.height, _box.width * 3 / 4);
  });

  test('pageIndexOf finds the page holding a spot', () {
    final page = _chapter(_thirtyParagraphs());
    final pages = paginate(page, _styles(fontScale: 1.6), _box).toList();
    expect(pageIndexOf(pages, BookSpot.title), 0);
    expect(pageIndexOf(pages, BookSpot.start), 0);
    for (var i = 0; i < pages.length; i++) {
      expect(pageIndexOf(pages, pages[i].start), i);
      expect(pageIndexOf(pages, pages[i].slices.last.spot), i);
    }
    expect(pageIndexOf(pages, const BookSpot(999, 0)), pages.length - 1);
  });

  test('spotAtOffset 0 is the title; past the end is the last line', () {
    final s = _styles(fontScale: 1.6);
    final page = _chapter(_thirtyParagraphs());
    expect(spotAtOffset(page, s, _box.width, 0), BookSpot.title);
    final last = (page.blocks.last as BookPara).text;
    final painter = TextPainter(
      text: TextSpan(text: last, style: s.prose),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _box.width);
    final lastLine = painter.computeLineMetrics().last;
    final lastStart = painter
        .getLineBoundary(
          painter.getPositionForOffset(Offset(0, lastLine.baseline)),
        )
        .start;
    expect(spotAtOffset(page, s, _box.width, 1e9), BookSpot(29, lastStart));
    // Further down is never earlier in the text.
    var previous = BookSpot.title;
    for (var offset = 0.0; offset < 20000; offset += 97) {
      final spot = spotAtOffset(page, s, _box.width, offset);
      expect(spot.compareTo(previous), greaterThanOrEqualTo(0));
      previous = spot;
    }
    // The page holding the spot at an offset is a real page.
    final pages = paginate(page, s, _box).toList();
    expect(
      pageIndexOf(pages, spotAtOffset(page, s, _box.width, 3000)),
      inInclusiveRange(1, pages.length - 1),
    );
  });
}
