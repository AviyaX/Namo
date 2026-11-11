import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/marks.dart';
import 'package:buddhist_gatha/home/quick_access.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

const _block = ValueKey('home-quick-access');

Finder _card(String sectionId, {bool skipOffstage = true}) =>
    find.byKey(ValueKey('quick-$sectionId'), skipOffstage: skipOffstage);

Finder _inBlock(Finder f) => find.descendant(of: find.byKey(_block), matching: f);

String _location(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .routeInformationProvider
        .value
        .uri
        .toString();

Future<void> _tapVisible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Section _section(String id, int number) => Section(
  id: id,
  number: number,
  heading: 'Heading $id',
  verses: [Verse(id: '$id-v1', paliSi: 'pali', sinhala: 'sinhala')],
);

/// One topic whose one reading has s01, s02 and s04 but no s03.
Library _withoutS03() => Library(
  categories: [
    Category(
      id: 'c1',
      title: 'Category 1',
      subtitle: 'Subtitle 1',
      readings: [
        Reading(
          id: 'r1',
          title: 'Reading 1',
          sections: [_section('s01', 1), _section('s02', 2), _section('s04', 4)],
        ),
      ],
    ),
  ],
);

/// Every word of every text in the Quick Access cards fits the width its
/// paragraph was given (no word is broken across lines).
void _expectNoBrokenWords(WidgetTester t) {
  final paragraphs = find.descendant(
    of: find.byKey(_block),
    matching: find.byType(RichText),
  );
  expect(paragraphs, findsWidgets);
  for (final e in paragraphs.evaluate()) {
    final render = e.renderObject! as RenderParagraph;
    final span = render.text;
    for (final word in span.toPlainText().split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: span.style),
        textDirection: TextDirection.ltr,
        textScaler: render.textScaler,
      )..layout();
      expect(
        painter.width,
        lessThanOrEqualTo(render.size.width + 0.5),
        reason: '"$word" is wider than its line',
      );
      painter.dispose();
    }
  }
}

void main() {
  setUpAll(loadBundledFonts);

  test('the four entries, in order, with their sections and marks', () {
    expect(
      [for (final e in quickAccess) (e.label, e.sectionId, e.mark)],
      [
        ('Namaskara', 's01', NamoMark.palms),
        ('Tisarana', 's02', NamoMark.wheel),
        ('Pancha Sila', 's03', NamoMark.lotusBud),
        ('Buddha Guna', 's04', NamoMark.seated),
      ],
    );
  });

  testWidgets('bundled content: "Quick Access" over four cards, each with its '
      'label, mark and the heading of its section as stored', (t) async {
    await openReal(t, Routes.home, size: const Size(390, 3000));
    final reading = (await realLibrary(t)).categories.first.readings.first;
    expect(_inBlock(find.text('Quick Access')), findsOneWidget);
    for (final e in quickAccess) {
      final card = _card(e.sectionId);
      expect(card, findsOneWidget, reason: e.label);
      final heading = reading.sections
          .singleWhere((s) => s.id == e.sectionId)
          .heading;
      expect(find.descendant(of: card, matching: find.text(e.label)),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(heading)),
          findsOneWidget);
      final mark = t.widget<NamoMarkIcon>(
        find.descendant(of: card, matching: find.byType(NamoMarkIcon)),
      );
      expect(mark.mark, e.mark);
    }
  });

  testWidgets('each card is one button named by its label and heading', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await openReal(t, Routes.home, size: const Size(390, 3000));
    final reading = (await realLibrary(t)).categories.first.readings.first;
    for (final e in quickAccess) {
      final heading = reading.sections
          .singleWhere((s) => s.id == e.sectionId)
          .heading;
      final node = find.bySemanticsLabel('${e.label}, $heading');
      expect(node, findsOneWidget, reason: e.label);
      final data = t.getSemantics(node).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.rect.height, greaterThanOrEqualTo(48));
    }
    expect(
      t.getSemantics(_inBlock(find.text('Quick Access')))
          .getSemanticsData()
          .flagsCollection
          .isHeader,
      isTrue,
    );
    handle.dispose();
  });

  testWidgets('a card opens the reader at its section, from Home', (t) async {
    await openReal(t, Routes.home);
    final reading = (await realLibrary(t)).categories.first.readings.first;
    await _tapVisible(t, _card('s03'));
    expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
    expect(
      _location(t),
      Routes.reader(reading.id, sectionId: 's03', from: ReaderFrom.home),
    );
    expect(find.byKey(const ValueKey('heading-s03')), findsOneWidget);
  });

  testWidgets('"See all" opens the Library with the topic open', (t) async {
    await openReal(t, Routes.home);
    final c = (await realLibrary(t)).categories.first;
    await _tapVisible(t, _inBlock(find.text('See all')));
    expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
    expect(find.byKey(ValueKey('open-${c.id}')), findsOneWidget);
  });

  testWidgets('a reading without s03: three cards, no Pancha Sila', (t) async {
    await openReal(t, Routes.home, library: _withoutS03());
    for (final id in ['s01', 's02', 's04']) {
      expect(_card(id, skipOffstage: false), findsOneWidget, reason: id);
    }
    expect(_card('s03', skipOffstage: false), findsNothing);
    expect(find.text('Pancha Sila', skipOffstage: false), findsNothing);
    expect(find.text('Heading s04', skipOffstage: false), findsOneWidget);
  });

  testWidgets('a topic with no readings: no Quick Access at all', (t) async {
    await openReal(
      t,
      Routes.home,
      library: const Library(
        categories: [
          Category(id: 'c0', title: 'Empty', subtitle: 'Nothing', readings: []),
        ],
      ),
    );
    expect(find.byKey(_block, skipOffstage: false), findsNothing);
    expect(find.text('Quick Access', skipOffstage: false), findsNothing);
  });

  testWidgets('a reading with none of the four sections: no header, no block', (
    t,
  ) async {
    await openReal(t, Routes.home, library: severalCategories());
    expect(find.byKey(_block, skipOffstage: false), findsNothing);
    expect(find.text('Quick Access', skipOffstage: false), findsNothing);
  });

  testWidgets('320 px wide: two rows of two, each row as tall as its tallest '
      'card, no word broken, nothing overflows', (t) async {
    await openReal(t, Routes.home, size: const Size(320, 3000));
    final rects = {
      for (final e in quickAccess) e.sectionId: t.getRect(_card(e.sectionId)),
    };
    expect(rects['s01']!.top, rects['s02']!.top);
    expect(rects['s03']!.top, rects['s04']!.top);
    expect(rects['s03']!.top, greaterThan(rects['s01']!.bottom));
    expect(rects['s01']!.left, rects['s03']!.left);
    expect(rects['s02']!.left, greaterThan(rects['s01']!.right));
    expect(rects['s01']!.height, rects['s02']!.height);
    expect(rects['s03']!.height, rects['s04']!.height);
    expect(rects['s01']!.width, rects['s02']!.width);
    final block = t.getRect(find.byKey(_block));
    expect(rects['s02']!.right, lessThanOrEqualTo(block.right));
    _expectNoBrokenWords(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('320 px wide at text size 200%: the words do not fit two '
      'abreast, so one card per row, full width; no word broken, no '
      'overflow, every card at least 48 high', (t) async {
    await openReal(
      t,
      Routes.home,
      size: const Size(320, 3000),
      deviceTextScale: 2.0,
    );
    final block = t.getRect(find.byKey(_block));
    final rects = [for (final e in quickAccess) t.getRect(_card(e.sectionId))];
    for (var i = 0; i < rects.length; i++) {
      expect(rects[i].left, block.left);
      expect(rects[i].right, closeTo(block.right, 0.01));
      expect(rects[i].height, greaterThanOrEqualTo(48));
      if (i > 0) expect(rects[i].top, greaterThan(rects[i - 1].bottom));
    }
    _expectNoBrokenWords(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('1280 px wide: four in one row, equal widths and heights', (
    t,
  ) async {
    await openReal(t, Routes.home, size: const Size(1280, 3000));
    final rects = [for (final e in quickAccess) t.getRect(_card(e.sectionId))];
    for (final r in rects.skip(1)) {
      expect(r.top, rects.first.top);
      expect(r.height, rects.first.height);
      expect(r.width, closeTo(rects.first.width, 0.01));
    }
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].left, greaterThan(rects[i - 1].right));
    }
    final block = t.getRect(find.byKey(_block));
    expect(rects.first.left, block.left);
    expect(rects.last.right, closeTo(block.right, 0.01));
    _expectNoBrokenWords(t);
  });

  for (final (width, scale) in [(360.0, 1.0), (390.0, 1.0), (390.0, 1.5)]) {
    testWidgets('$width px wide at text $scale: no word broken, rows of equal '
        'height, nothing overflows', (t) async {
      await openReal(
        t,
        Routes.home,
        size: Size(width, 3000),
        deviceTextScale: scale,
      );
      final rects = [for (final e in quickAccess) t.getRect(_card(e.sectionId))];
      for (final a in rects) {
        for (final b in rects) {
          if (a.top == b.top) expect(a.height, b.height);
        }
      }
      _expectNoBrokenWords(t);
      expect(t.takeException(), isNull);
    });
  }
}
