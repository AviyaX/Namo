import 'dart:ui' as ui;

import 'package:buddhist_gatha/books/book_blocks.dart';
import 'package:buddhist_gatha/books/book_model.dart';
import 'package:buddhist_gatha/books/pagination/justified_lines.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

const _width = 300.0;
const _ink = Color(0xFF000000);
const _paper = Color(0xFFFFFFFF);
const _style = TextStyle(fontFamily: 'Lora', fontSize: 18, color: _ink);

/// A made-up paragraph of [words] words of mixed lengths.
String _words(int words) => [
  for (var w = 0; w < words; w++)
    const ['alpha', 'to', 'charlie', 'a', 'foxtrot', 'in', 'hotel'][w % 7],
].join(' ');

/// The full text laid out as the paginator measures it: each line's start
/// and height.
({List<int> starts, List<double> heights}) _measured(String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: _style),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: _width);
  final starts = <int>[], heights = <double>[];
  for (final line in painter.computeLineMetrics()) {
    final at = painter.getPositionForOffset(Offset(0, line.baseline));
    starts.add(painter.getLineBoundary(at).start);
    heights.add(line.height);
  }
  painter.dispose();
  return (starts: starts, heights: heights);
}

Widget _host(Widget child) => MediaQuery(
  data: const MediaQueryData(),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: _width, child: child),
    ),
  ),
);

JustifiedLines _slice(String text, int charStart, int charEnd) =>
    JustifiedLines(
      text: text,
      style: _style,
      scaler: TextScaler.noScaling,
      direction: TextDirection.ltr,
      charStart: charStart,
      charEnd: charEnd,
    );

RenderJustifiedLines _render(WidgetTester t) =>
    t.renderObject<RenderJustifiedLines>(find.byType(JustifiedLines));

/// How far right the glyphs of [text] `from` to `to` (trailing spaces
/// left out) reach in [painter]'s layout.
double _rightEdge(TextPainter painter, String text, int from, int to) {
  final end = from + text.substring(from, to).trimRight().length;
  final boxes = painter.getBoxesForSelection(
    TextSelection(baseOffset: from, extentOffset: end),
  );
  return boxes.map((b) => b.right).reduce((a, b) => a > b ? a : b);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  final text = _words(80);

  testWidgets('a slice shows only its own lines', (t) async {
    final lines = _measured(text);
    expect(lines.starts.length, greaterThan(8));
    // Lines 3 to 6 of the paragraph.
    final from = lines.starts[3], to = lines.starts[6];
    final ownHeight = lines.heights.sublist(3, 6).reduce((a, b) => a + b);
    const margin = 20.0;
    final boundary = GlobalKey();
    t.view.physicalSize = const Size(_width, 600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _host(
        RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: _paper,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: margin),
                _slice(text, from, to),
                const SizedBox(height: margin),
              ],
            ),
          ),
        ),
      ),
    );
    final size = t.getSize(find.byType(JustifiedLines));
    expect(size.width, _width);
    expect(size.height, moreOrLessEquals(ownHeight, epsilon: 0.01));

    final image = await t.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final picture = await render.toImage();
      final bytes = await picture.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final out = (picture.width, picture.height, bytes!);
      picture.dispose();
      return out;
    });
    final (w, h, bytes) = image!;
    bool inkInRows(int top, int bottom) {
      for (var y = top; y < bottom; y++) {
        for (var x = 0; x < w; x++) {
          if (bytes.getUint8((y * w + x) * 4) < 200) return true;
        }
      }
      return false;
    }

    final sliceTop = margin.toInt();
    final sliceBottom = (margin + ownHeight).ceil();
    expect(inkInRows(0, sliceTop), isFalse, reason: 'above the slice');
    expect(inkInRows(sliceTop, sliceBottom), isTrue, reason: 'the slice');
    expect(inkInRows(sliceBottom, h), isFalse, reason: 'below the slice');
  });

  testWidgets("a slice's last line is justified when the paragraph goes on", (
    t,
  ) async {
    final lines = _measured(text);
    final from = lines.starts[2], to = lines.starts[5];
    await t.pumpWidget(_host(_slice(text, from, to)));
    final render = _render(t);
    expect(render.lineRange, (2, 5));
    expect(
      _rightEdge(render.painter, text, lines.starts[4], to),
      greaterThanOrEqualTo(_width - 1),
    );
  });

  testWidgets("the paragraph's own last line stays ragged", (t) async {
    // Ends with a short last line.
    final short = '${_words(60)} end.';
    final lines = _measured(short);
    final last = lines.starts.length - 1;
    final from = lines.starts[last - 2];
    await t.pumpWidget(_host(_slice(short, from, short.length)));
    final render = _render(t);
    expect(render.lineRange, (last - 2, last + 1));
    expect(
      _rightEdge(render.painter, short, lines.starts[last], short.length),
      lessThan(_width - 20),
    );
    // The line before it is justified.
    expect(
      _rightEdge(
        render.painter,
        short,
        lines.starts[last - 1],
        lines.starts[last],
      ),
      greaterThanOrEqualTo(_width - 1),
    );
  });

  testWidgets('a slice ending at a hard line break leaves it out', (t) async {
    const broken = 'One two three four\nFive six seven';
    await t.pumpWidget(_host(_slice(broken, 0, 18)));
    expect(_render(t).lineRange, (0, 1));
    await t.pumpWidget(_host(_slice(broken, 19, broken.length)));
    expect(_render(t).lineRange, (1, 2));
  });

  testWidgets('glyphs reaching past the sides are not cut off', (t) async {
    final lines = _measured(text);
    await t.pumpWidget(_host(_slice(text, lines.starts[1], lines.starts[3])));
    final height = t.getSize(find.byType(JustifiedLines)).height;
    // Sideways the clip leaves room for an overhanging glyph; up and down
    // it is exactly the slice's lines.
    expect(
      _render(t),
      paints..clipRect(
        rect: Rect.fromLTRB(
          -justifiedOverhang,
          0,
          _width + justifiedOverhang,
          height,
        ),
      ),
    );
  });

  testWidgets('a slice reads as its own text', (t) async {
    final handle = t.ensureSemantics();
    final lines = _measured(text);
    final from = lines.starts[1], to = lines.starts[3];
    await t.pumpWidget(_host(_slice(text, from, to)));
    expect(
      t.getSemantics(find.byType(JustifiedLines)),
      matchesSemantics(
        label: text.substring(from, to),
        textDirection: TextDirection.ltr,
      ),
    );
    handle.dispose();
  });

  group('Scroll mode', () {
    final styles = BookTextStyles.from(
      palette: NamoPalette.light,
      settings: const AppSettings(),
    );

    Widget block(BookBlock b) => Theme(
      data: ThemeData(extensions: const [NamoPalette.light]),
      child: _host(BookBlockView(block: b, styles: styles)),
    );

    testWidgets('book paragraphs are justified', (t) async {
      await t.pumpWidget(block(BookPara(_words(30))));
      expect(t.widget<Text>(find.byType(Text)).textAlign, TextAlign.justify);
    });

    testWidgets('list and footnote item text is justified, not the labels', (
      t,
    ) async {
      final items = [_words(20), _words(25)];
      for (final b in [
        BookList(marker: ListMarker.number, start: 1, items: items),
        BookFootnotes(items),
      ]) {
        await t.pumpWidget(block(b));
        for (final item in items) {
          expect(t.widget<Text>(find.text(item)).textAlign, TextAlign.justify);
        }
        expect(
          t.widget<Text>(find.text(b is BookList ? '1.' : '1')).textAlign,
          isNot(TextAlign.justify),
        );
      }
    });

    testWidgets('headings, subheads and verses are not justified', (t) async {
      for (final b in <BookBlock>[
        const BookHeading('A heading'),
        const BookSubhead('A subhead'),
        const BookGatha(['A verse line', 'Another verse line']),
      ]) {
        await t.pumpWidget(block(b));
        for (final w in t.widgetList<Text>(find.byType(Text))) {
          expect(w.textAlign, isNot(TextAlign.justify), reason: '$b');
        }
      }
    });
  });
}
