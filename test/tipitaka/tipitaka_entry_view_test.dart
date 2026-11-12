import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_book.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_entry_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Made-up letters only (no real text): ka, hal, ya.
const _hal = '්';
const _zwj = '‍';
const _joinable = 'ක$_hal' 'ය';

TipitakaEntry _entry(EntryType type, String text, {int? level}) =>
    TipitakaEntry(type: type, text: text, level: level, page: 0);

Future<void> _pump(
  WidgetTester t,
  List<TipitakaEntryView> views, {
  Size size = const Size(400, 900),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: namoTheme(Brightness.light),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < views.length; i++)
                KeyedSubtree(key: ValueKey('view-$i'), child: views[i]),
            ],
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

/// The main text of view [view] (its first text block).
RichText _rich(WidgetTester t, [int view = 0]) => t.widget<RichText>(
  find
      .descendant(
        of: find.byKey(ValueKey('view-$view')),
        matching: find.byType(RichText),
      )
      .first,
);

Finder _richFinder([int view = 0]) => find
    .descendant(
      of: find.byKey(ValueKey('view-$view')),
      matching: find.byType(RichText),
    )
    .first;

String _plain(WidgetTester t, [int view = 0]) =>
    _rich(t, view).text.toPlainText(includePlaceholders: false);

/// The effective style of the first text span holding [needle] in [span].
TextStyle? _styleOf(InlineSpan span, String needle, [TextStyle? outer]) {
  if (span is! TextSpan) return null;
  final style = outer == null ? span.style : outer.merge(span.style);
  if (span.text != null && span.text!.contains(needle)) return style;
  for (final c in span.children ?? const <InlineSpan>[]) {
    final s = _styleOf(c, needle, style);
    if (s != null) return s;
  }
  return null;
}

void main() {
  testWidgets('centered is centred', (t) async {
    await _pump(t, [
      TipitakaEntryView(entry: _entry(EntryType.centered, 'aaa'), pali: true),
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, 'bbb'),
        pali: true,
      ),
    ]);
    expect(_rich(t).textAlign, TextAlign.center);
    expect(_rich(t, 1).textAlign, isNot(TextAlign.center));
  });

  testWidgets('heading is larger and bolder than a paragraph and steps with '
      'its level, three sizes at most', (t) async {
    await _pump(t, [
      TipitakaEntryView(entry: _entry(EntryType.paragraph, 'para'), pali: true),
      TipitakaEntryView(
        entry: _entry(EntryType.heading, 'hone', level: 1),
        pali: true,
      ),
      TipitakaEntryView(
        entry: _entry(EntryType.heading, 'htwo', level: 2),
        pali: true,
      ),
      TipitakaEntryView(
        entry: _entry(EntryType.heading, 'hthree', level: 3),
        pali: true,
      ),
      TipitakaEntryView(
        entry: _entry(EntryType.heading, 'hnine', level: 9),
        pali: true,
      ),
    ]);
    double size(int i, String n) => _styleOf(_rich(t, i).text, n)!.fontSize!;
    final para = _styleOf(_rich(t).text, 'para')!;
    final one = _styleOf(_rich(t, 1).text, 'hone')!;
    expect(one.fontSize!, greaterThan(para.fontSize!));
    expect(one.fontWeight!.value, greaterThan(para.fontWeight!.value));
    expect(size(2, 'htwo'), greaterThan(size(1, 'hone')));
    expect(size(3, 'hthree'), greaterThan(size(2, 'htwo')));
    expect(size(4, 'hnine'), size(3, 'hthree'));
  });

  testWidgets('paragraph has a first-line indent; unindented has none',
      (t) async {
    await _pump(t, [
      TipitakaEntryView(entry: _entry(EntryType.paragraph, 'para'), pali: true),
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, 'flat'),
        pali: true,
      ),
    ]);
    // The indent is a leading placeholder; the text itself is unchanged.
    expect(_rich(t).text.toPlainText(), startsWith('￼'));
    expect(_plain(t), 'para');
    expect(_rich(t, 1).text.toPlainText(), 'flat');
  });

  testWidgets('gatha keeps its line breaks, has no indent and is set in from '
      'the left; unindented is flush left', (t) async {
    await _pump(t, [
      TipitakaEntryView(
        entry: _entry(EntryType.gatha, 'line a\nline b'),
        pali: true,
      ),
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, 'flat'),
        pali: true,
      ),
    ]);
    expect(_rich(t).text.toPlainText(), 'line a\nline b');
    final gathaLeft = t.getTopLeft(_richFinder()).dx;
    final flatLeft = t.getTopLeft(_richFinder(1)).dx;
    expect(gathaLeft, greaterThan(flatLeft));
    expect(_rich(t, 1).textAlign, TextAlign.start);
  });

  testWidgets('bold span is bold', (t) async {
    await _pump(t, [
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, 'plain **strong** end'),
        pali: true,
      ),
    ]);
    final plain = _styleOf(_rich(t).text, 'plain')!;
    final strong = _styleOf(_rich(t).text, 'strong')!;
    expect(strong.fontWeight, FontWeight.w700);
    expect(plain.fontWeight, isNot(FontWeight.w700));
  });

  testWidgets('raw markers are not shown; each span has its look', (t) async {
    await _pump(t, [
      TipitakaEntryView(
        entry: _entry(
          EntryType.unindented,
          r'o __u__ ~~s~~ ##h## $$e$$ <b>x</b> a&amp;b',
        ),
        pali: true,
      ),
    ]);
    expect(_plain(t), 'o u s h e x a&b');
    final root = _rich(t).text;
    final o = _styleOf(root, 'o ')!;
    expect(_styleOf(root, 'u')!.decoration, TextDecoration.underline);
    expect(_styleOf(root, 's')!.decoration, TextDecoration.lineThrough);
    expect(_styleOf(root, 'h')!.backgroundColor, isNotNull);
    expect(o.backgroundColor, isNull);
    expect(_styleOf(root, 'e')!.color, isNot(o.color));
  });

  testWidgets('unbalanced markers show literally', (t) async {
    await _pump(t, [
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, 'x **y {z'),
        pali: true,
      ),
    ]);
    expect(_plain(t), 'x **y {z');
  });

  testWidgets('a rule is a thin divider between the text around it',
      (t) async {
    await _pump(t, [
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, 'above<hr/>below'),
        pali: true,
      ),
    ]);
    expect(find.byKey(const ValueKey('tipitaka-rule')), findsOneWidget);
    expect(find.text('above'), findsOneWidget);
    expect(find.text('below'), findsOneWidget);
  });

  testWidgets('footnote mark opens the sheet with that footnote marked',
      (t) async {
    await _pump(t, [
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, 'word{2} more'),
        pali: true,
        footnotes: const ['1. first note', '2. second note'],
      ),
    ]);
    expect(find.bySemanticsLabel('Footnote 2'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Footnote 2'));
    await t.pumpAndSettle();
    expect(find.text('Footnotes'), findsOneWidget);
    expect(find.textContaining('first note'), findsOneWidget);
    final marked = find.byKey(const ValueKey('tipitaka-footnote-marked'));
    expect(marked, findsOneWidget);
    expect(
      find.descendant(of: marked, matching: find.textContaining('second note')),
      findsOneWidget,
    );
  });

  testWidgets('the mark answers a tap a little way off it (44 px target)',
      (t) async {
    await _pump(t, [
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, 'word word{1} more more'),
        pali: true,
        footnotes: const ['1. first note'],
      ),
    ]);
    final mark = find.byKey(const ValueKey('tipitaka-footnote-mark-1'));
    final size = t.getSize(mark);
    expect(size.width, lessThan(44));
    // 20 px to the right of the mark's centre: outside the drawn mark,
    // inside its 44 px target.
    await t.tapAt(t.getCenter(mark) + Offset(size.width / 2 + 12, 0));
    await t.pumpAndSettle();
    expect(find.text('Footnotes'), findsOneWidget);
  });

  testWidgets('unmatched mark opens the list', (t) async {
    await _pump(t, [
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, 'word{9}'),
        pali: false,
        footnotes: const ['1. first note', 'loose note'],
      ),
    ]);
    await t.tap(find.bySemanticsLabel('Footnote 9'));
    await t.pumpAndSettle();
    expect(find.text('Footnotes'), findsOneWidget);
    expect(find.textContaining('first note'), findsOneWidget);
    expect(find.textContaining('loose note'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tipitaka-footnote-marked')),
      findsNothing,
    );
  });

  testWidgets('mark is not a button when the page has no footnotes',
      (t) async {
    await _pump(t, [
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, 'word{1}'),
        pali: true,
      ),
    ]);
    expect(find.byKey(const ValueKey('tipitaka-footnote-mark-1')),
        findsOneWidget);
    expect(find.bySemanticsLabel('Footnote 1'), findsNothing);
    await t.tap(find.byKey(const ValueKey('tipitaka-footnote-mark-1')),
        warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.text('Footnotes'), findsNothing);
  });

  testWidgets('Pali text gains joiners, Sinhala text is byte-identical to the '
      'stored text', (t) async {
    const stored = 'a $_joinable b';
    await _pump(t, [
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, stored),
        pali: true,
      ),
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, stored),
        pali: false,
      ),
    ]);
    expect(_plain(t), 'a ක$_hal$_zwjය b');
    expect(_plain(t, 1), stored);
    expect(_plain(t, 1).codeUnits, stored.codeUnits);
  });

  testWidgets('an entry containing U+05F4 draws a plain quote mark',
      (t) async {
    const stored = 'say ״hi״';
    await _pump(t, [
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, stored),
        pali: true,
      ),
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, stored),
        pali: false,
      ),
    ]);
    expect(_plain(t), 'say "hi"');
    expect(_plain(t, 1), 'say "hi"');
  });

  testWidgets('text size and line spacing set the style', (t) async {
    await _pump(t, [
      TipitakaEntryView(
        entry: _entry(EntryType.unindented, 'abc'),
        pali: true,
        fontScale: 1.5,
        lineSpacing: 2.0,
      ),
      TipitakaEntryView(entry: _entry(EntryType.unindented, 'def'), pali: true),
    ]);
    final big = _styleOf(_rich(t).text, 'abc')!;
    final normal = _styleOf(_rich(t, 1).text, 'def')!;
    expect(big.fontSize, closeTo(normal.fontSize! * 1.5, 0.01));
    expect(big.height, 2.0);
  });
}
