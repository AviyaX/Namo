import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/flows/flow_reading.dart';
import 'package:buddhist_gatha/flows/flows.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/reader/reader_items.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import 'flow_test_support.dart';

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

Future<void> _go(WidgetTester t, String location) async {
  _container(t).read(routerProvider).go(location);
  await t.pumpAndSettle();
}

Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(BottomSheet), matching: f);

/// The headings the reader is showing, in order: id, number and heading.
List<(String, int, String)> _readerHeadings(WidgetTester t) => [
  for (final h in t
      .widget<ReaderBody>(find.byType(ReaderBody))
      .items
      .whereType<HeadingItem>())
    (h.section.id, h.section.number, h.section.heading),
];

/// The editor's rows from top to bottom, read while scrolling the page
/// through (the list builds only what is on screen); left at the top.
Future<List<String>> _editorRows(WidgetTester t) async {
  final seen = <String>[];
  void collect() {
    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('flow-row-'),
    );
    final shown = rows.evaluate().toList()
      ..sort(
        (a, b) => t
            .getTopLeft(find.byElementPredicate((e) => e == a))
            .dy
            .compareTo(t.getTopLeft(find.byElementPredicate((e) => e == b)).dy),
      );
    for (final e in shown) {
      final id = (e.widget.key! as ValueKey<String>).value.substring(
        'flow-row-'.length,
      );
      if (!seen.contains(id)) seen.add(id);
    }
  }

  final position = t
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  position.jumpTo(0);
  await t.pump();
  collect();
  while (position.pixels < position.maxScrollExtent) {
    position.jumpTo(
      (position.pixels + position.viewportDimension / 2).clamp(
        0.0,
        position.maxScrollExtent,
      ),
    );
    await t.pump();
    collect();
  }
  position.jumpTo(0);
  await t.pumpAndSettle();
  return seen;
}

Future<void> _scrollPageTo(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
}

/// From the Library: a new flow from Buddha Wandanawa, its second section
/// removed, its first moved down one, and [pirith] added; then chanted, and
/// Back twice to the Library. Returns the flow's sections as made.
Future<List<FlowRef>> _journey(
  WidgetTester t,
  Reading buddha,
  Reading pirith,
) async {
  final c = _container(t);
  await _go(t, Routes.library);

  // New flow, from Buddha Wandanawa.
  await t.ensureVisible(find.byKey(const ValueKey('new-flow')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('new-flow')));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const ValueKey('flow-name-field')), 'Evening');
  await t.pump();
  final from = find.byKey(ValueKey('start-from-${buddha.id}'));
  await t.scrollUntilVisible(
    from,
    100,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('new-flow-choices')),
      matching: find.byType(Scrollable),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(from);
  await t.pumpAndSettle();
  await t.ensureVisible(find.byKey(const ValueKey('new-flow-create')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('new-flow-create')));
  await t.pumpAndSettle();
  expect(location(c), Routes.flowEditor('flow-1'));

  // The editor shows every section of the reading, in its order.
  final all = [
    for (final s in buddha.sections) ref(buddha.id, s.id),
  ];
  expect(all.length, greaterThanOrEqualTo(3));
  expect(find.text(sectionCount(all.length)), findsOneWidget);
  expect(await _editorRows(t), [for (final r in all) flowSectionId(r)]);

  // Remove the second section, and let the "Removed" message go.
  final removed = all[1];
  await t.tap(find.byKey(ValueKey('flow-remove-${flowSectionId(removed)}')));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(seconds: 5));
  await t.pumpAndSettle();
  expect(find.text('Removed'), findsNothing);

  // Move the first down one, from its menu.
  await t.tap(find.byKey(ValueKey('flow-move-${flowSectionId(all[0])}')));
  await t.pumpAndSettle();
  await t.tap(find.text('Move down'));
  await t.pumpAndSettle();

  // Add the pirith from the sheet, then close it.
  final add = find.byKey(const ValueKey('flow-add'));
  await _scrollPageTo(t, add);
  await t.tap(add);
  await t.pumpAndSettle();
  final added = ref(pirith.id, pirith.sections.single.id);
  final tick = find.byKey(ValueKey('add-tick-${flowSectionId(added)}'));
  await t.scrollUntilVisible(
    tick,
    300,
    scrollable: _inSheet(find.byType(Scrollable)).first,
  );
  await t.pumpAndSettle();
  await t.tap(tick);
  await t.pumpAndSettle();
  await t.tapAt(const Offset(195, 20));
  await t.pumpAndSettle();
  expect(find.byType(BottomSheet), findsNothing);

  final made = [all[2], all[0], ...all.skip(3), added];
  expect(c.read(flowsProvider).flow('flow-1')!.sections, made);
  expect(savedFlow(c, 'flow-1')!.sections, made);
  expect(await _editorRows(t), [for (final r in made) flowSectionId(r)]);
  expect(find.text(sectionCount(made.length)), findsOneWidget);

  // Start chanting: the headings in the edited order, numbered from 1.
  final start = find.byKey(const ValueKey('flow-start'));
  await _scrollPageTo(t, start);
  await t.tap(start);
  await t.pumpAndSettle();
  expect(location(c), Routes.reader('flow-1', from: ReaderFrom.editor));
  final library = c.read(libraryProvider).value!;
  String headingOf(FlowRef r) => library
      .reading(r.readingId)!
      .sections
      .firstWhere((s) => s.id == r.sectionId)
      .heading;
  expect(_readerHeadings(t), [
    for (final (i, r) in made.indexed) (flowSectionId(r), i + 1, headingOf(r)),
  ]);
  final first = find.byKey(ValueKey('heading-${flowSectionId(made.first)}'));
  expect(find.descendant(of: first, matching: find.text('1')), findsOneWidget);
  expect(
    find.descendant(of: first, matching: find.text(headingOf(made.first))),
    findsOneWidget,
  );

  // Back to the editor, Back to the Library.
  await t.tap(find.byTooltip('Back'));
  await t.pumpAndSettle();
  expect(location(c), Routes.flowEditor('flow-1'));
  expect(find.byKey(const ValueKey('screen-flow-editor')), findsOneWidget);
  await t.tap(find.byTooltip('Back').first);
  await t.pumpAndSettle();
  expect(location(c), Routes.library);
  expect(t.takeException(), isNull);
  return made;
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('make a flow from Buddha Wandanawa, edit it, chant it, and '
      'find it in the Library and on Home', (t) async {
    final lib = await realLibrary(t);
    final buddha = lib.reading(realReadingId)!;
    final pirith = lib.reading(mangalaReadingId)!;
    await openReal(t, Routes.library, library: lib);

    final made = await _journey(t, buddha, pirith);

    final row = find.byKey(const ValueKey('flow-open-flow-1'));
    await t.ensureVisible(row);
    await t.pumpAndSettle();
    expect(
      find.descendant(of: row, matching: find.text('Evening')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text(sectionCount(made.length))),
      findsOneWidget,
    );

    await t.tap(find.byKey(const ValueKey('nav-home')));
    await t.pumpAndSettle();
    final card = find.byKey(const ValueKey('home-flow-flow-1'));
    await t.ensureVisible(card);
    await t.pumpAndSettle();
    expect(find.text('Your flows'), findsOneWidget);
    expect(
      t.getTopLeft(card).dy,
      greaterThan(t.getTopLeft(find.text('Your flows')).dy),
    );
    expect(
      find.descendant(of: card, matching: find.text('Evening')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text(sectionCount(made.length))),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('the journey leaves the original readings and the Library '
      'untouched', (t) async {
    final lib = await realLibrary(t);
    final buddha = lib.reading(realReadingId)!;
    final pirith = lib.reading(mangalaReadingId)!;
    await openReal(t, Routes.library, library: lib);
    final c = _container(t);

    Future<Map<String, List<(String, int, String)>>> headings() async => {
      for (final id in [buddha.id, pirith.id])
        id: await () async {
          await _go(t, Routes.reader(id));
          return _readerHeadings(t);
        }(),
    };

    final held = c.read(libraryProvider).value!;
    expect(identical(held, lib), isTrue);
    final sectionLists = {
      for (final r in held.categories.expand((c) => c.readings))
        r.id: r.sections,
    };
    final sections = {
      for (final e in sectionLists.entries) e.key: [...e.value],
    };
    final before = await headings();
    expect(before[buddha.id]!.length, buddha.sections.length);
    expect(before[pirith.id]!.single.$1, pirith.sections.single.id);

    await _journey(t, buddha, pirith);

    expect(await headings(), before);
    final after = c.read(libraryProvider).value!;
    expect(identical(after, held), isTrue);
    for (final r in after.categories.expand((c) => c.readings)) {
      expect(identical(r.sections, sectionLists[r.id]), isTrue, reason: r.id);
      expect(r.sections.length, sections[r.id]!.length, reason: r.id);
      for (final (i, s) in r.sections.indexed) {
        expect(identical(s, sections[r.id]![i]), isTrue, reason: '${r.id} $i');
      }
    }
  });

  testWidgets('a section the content no longer has is skipped in the '
      'Library, the editor, the reader and on Home, and the stored flow is '
      'not rewritten', (t) async {
    final a = ref('r1', 's01'), gone = ref('r1', 'gone'), b = ref('r1', 's02');
    final c = await openFlows(t, Routes.library, {
      'flow-1': [a, gone, b],
    });
    final stored = c.read(keyValueStoreProvider).read(flowsKey);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('flow-open-flow-1')),
        matching: find.text('2 sections'),
      ),
      findsOneWidget,
    );

    await _go(t, Routes.flowEditor('flow-1'));
    expect(find.text('2 sections'), findsOneWidget);
    expect(await _editorRows(t), ['r1~s01', 'r1~s02']);

    await _go(t, Routes.reader('flow-1'));
    expect(_readerHeadings(t), [
      ('r1~s01', 1, 'heading 1'),
      ('r1~s02', 2, 'heading 2'),
    ]);

    await _go(t, Routes.home);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-flow-flow-1')),
        matching: find.text('2 sections'),
      ),
      findsOneWidget,
    );

    expect(c.read(keyValueStoreProvider).read(flowsKey), stored);
    expect(c.read(flowsProvider).flow('flow-1')!.sections, [a, gone, b]);
    expect(t.takeException(), isNull);
  });
}
