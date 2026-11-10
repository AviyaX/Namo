import 'package:buddhist_gatha/design/widgets/list_row.dart';
import 'package:buddhist_gatha/library/search.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../quality/quality_support.dart';

const _search = ValueKey('library-search');
const _results = ValueKey('library-results');
const _chips = ValueKey('library-chips');
const _noResults = 'No results for “zzzz”';

Future<void> _type(WidgetTester t, String q) async {
  await t.enterText(find.byKey(_search), q);
  await t.pumpAndSettle();
}

String _prefix(String s, int n) => String.fromCharCodes(s.runes.take(n));

GoRouter _router(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byKey(_search)))
        .read(routerProvider);

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('one character keeps the topic list; two matching characters '
      'show the results instead', (t) async {
    final lib = await buddhaOnlyLibrary(t);
    await openReal(t, Routes.library, library: lib);
    final topic = lib.category(realCategoryId)!;
    expect(find.text(topic.title), findsOneWidget);
    final heading = topic.readings.first.sections[2].heading;
    await _type(t, _prefix(heading, 1));
    expect(find.byKey(_results), findsNothing);
    expect(find.text(topic.title), findsOneWidget);
    await _type(t, _prefix(heading, 2));
    expect(find.byKey(_results), findsOneWidget);
    expect(find.text(topic.title), findsNothing);
  });

  testWidgets('a heading prefix finds the section; tapping opens the reader', (
    t,
  ) async {
    final lib = await realLibrary(t);
    await openReal(t, Routes.library, size: const Size(390, 4000));
    final section = lib.reading(realReadingId)!.sections[2];
    await _type(t, _prefix(section.heading, 3));
    expect(
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(section.heading),
      ),
      findsOneWidget,
    );
    await t.tap(find.text(section.heading).first);
    await t.pumpAndSettle();
    expect(find.byKey(ValueKey('heading-${section.id}')), findsOneWidget);
  });

  testWidgets('a verse match shows the line; an unchosen language is named', (
    t,
  ) async {
    final lib = await realLibrary(t);
    await openReal(t, Routes.library, size: const Size(390, 6000));
    final selection = const AppSettings().languages;
    // A chosen language (Pali and Sinhala by default).
    final verse = lib.reading(realReadingId)!.sections[3].verses.first;
    final source = verse.paliSi ?? verse.sinhala!;
    final chosenQuery = _prefix(source.split('\n').first.trim(), 6);
    final chosen = searchLibrary(
      lib,
      chosenQuery,
      selection,
    ).firstWhere((h) => h.line != null);
    await _type(t, chosenQuery);
    expect(find.text(chosen.line!), findsWidgets);
    // A chosen language is not named, as on screen.
    expect(
      t
          .widgetList<ListRow>(find.byType(ListRow))
          .map((r) => r.detailLabel),
      contains(chosen.line),
    );

    // A language that is not chosen: its name is shown with the line.
    final english = lib
        .reading(realReadingId)!
        .sections
        .expand((s) => s.verses)
        .map((v) => v.english)
        .whereType<String>()
        .first;
    final q = _prefix(english.split('\n').first.trim(), 14);
    final hit = searchLibrary(
      lib,
      q,
      selection,
    ).firstWhere((h) => h.line != null && !h.lineLanguageChosen);
    await _type(t, q);
    expect(find.text(hit.line!), findsWidgets);
    expect(find.text(hit.lineLanguage!.label), findsWidgets);
    // Screen readers are told the language too.
    expect(
      t
          .widgetList<ListRow>(find.byType(ListRow))
          .map((r) => r.detailLabel),
      contains('${hit.lineLanguage!.label}, ${hit.line}'),
    );
  });

  testWidgets('no match shows the nothing-found state', (t) async {
    await openReal(t, Routes.library);
    await _type(t, 'zzzz');
    expect(find.text(_noResults), findsOneWidget);
    expect(
      find.text('Try a word from a section title or a verse.'),
      findsOneWidget,
    );
  });

  for (final q in ['  ', '((', '\\', 'x' * 5000]) {
    testWidgets('a query of ${q.length} characters does not throw', (t) async {
      await openReal(t, Routes.library);
      await _type(t, q);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('clearing brings back the topic list with the same topics open', (
    t,
  ) async {
    final lib = await buddhaOnlyLibrary(t);
    await openReal(t, Routes.library, size: const Size(390, 4000), library: lib);
    final topic = lib.category(realCategoryId)!;
    await t.tap(find.text(topic.title));
    await t.pumpAndSettle();
    final first = topic.readings.first.sections.first.heading;
    expect(find.text(first), findsOneWidget);
    await _type(t, 'zzzz');
    expect(find.text(topic.title), findsNothing);
    await t.tap(find.byTooltip('Clear search'));
    await t.pumpAndSettle();
    expect(find.byKey(_results), findsNothing);
    expect(find.text(topic.title), findsOneWidget);
    expect(find.text(first), findsOneWidget);
  });

  testWidgets('an address request empties the field and opens that topic', (
    t,
  ) async {
    final lib = await realLibrary(t);
    await openReal(t, Routes.library, size: const Size(390, 4000));
    await _type(t, 'zzzz');
    expect(find.text(_noResults), findsOneWidget);
    _router(t).go(Routes.category(realCategoryId));
    await t.pumpAndSettle();
    final field = t.widget<TextField>(
      find.descendant(
        of: find.byKey(_search),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, '');
    expect(find.byKey(_results), findsNothing);
    expect(
      find.text(lib.reading(realReadingId)!.sections.first.heading),
      findsOneWidget,
    );
  });

  testWidgets('the query is not written to the key-value store', (t) async {
    await openReal(t, Routes.library);
    final container = ProviderScope.containerOf(t.element(find.byKey(_search)));
    final store = container.read(keyValueStoreProvider);
    final before = store.read(settingsKey);
    await _type(t, 'zzzz');
    await _type(t, '');
    expect(store.read(settingsKey), before);
    expect(store.read(savedKey), isNull);
    expect(store.read(positionKey), isNull);
  });

  testWidgets('header caption for the bundled content, and no chips', (
    t,
  ) async {
    await openReal(t, Routes.library, library: await buddhaOnlyLibrary(t));
    expect(find.text('1 collection · 19 sections'), findsOneWidget);
    expect(find.byKey(_chips), findsNothing);
  });

  testWidgets('several collections: caption, chips, and a chip filters', (
    t,
  ) async {
    final lib = severalCategories();
    final sections = lib.categories.fold<int>(
      0,
      (n, c) => n + c.readings.fold<int>(0, (m, r) => m + r.sections.length),
    );
    await openReal(
      t,
      Routes.library,
      library: lib,
      size: const Size(390, 2000),
    );
    expect(find.text('4 collections · $sections sections'), findsOneWidget);
    expect(find.byKey(_chips), findsOneWidget);
    expect(find.text('Subtitle 1'), findsOneWidget);
    expect(find.text('Subtitle 3'), findsOneWidget);
    await t.tap(
      find.descendant(
        of: find.byKey(_chips),
        matching: find.text('Category 3'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Subtitle 3'), findsOneWidget);
    expect(find.text('Subtitle 1'), findsNothing);
    await t.tap(
      find.descendant(of: find.byKey(_chips), matching: find.text('All')),
    );
    await t.pumpAndSettle();
    expect(find.text('Subtitle 1'), findsOneWidget);
    expect(find.text('Subtitle 3'), findsOneWidget);
  });

  testWidgets('an address request resets the chip to All', (t) async {
    await openReal(
      t,
      Routes.library,
      library: severalCategories(),
      size: const Size(390, 2000),
    );
    await t.tap(
      find.descendant(
        of: find.byKey(_chips),
        matching: find.text('Category 3'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Subtitle 1'), findsNothing);
    _router(t).go(Routes.category('c1'));
    await t.pumpAndSettle();
    expect(find.text('Subtitle 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-c1')), findsOneWidget);
  });

  group('overflow', () {
    final sizes = <(Size, double)>[
      (const Size(320, 800), 2.0),
      for (final w in [360.0, 390.0, 840.0, 1280.0])
        for (final s in [1.0, 1.5]) (Size(w, 900), s),
    ];
    for (final dark in [false, true]) {
      for (final (size, scale) in sizes) {
        testWidgets('${size.width} wide at $scale x text, dark $dark', (
          t,
        ) async {
          await openReal(
            t,
            Routes.library,
            library: severalCategories(),
            size: size,
            deviceTextScale: scale,
            dark: dark,
          );
          await t.ensureVisible(find.text('Subtitle 1'));
          await t.tap(find.text('Subtitle 1'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await _type(t, 'Heading');
          expect(find.byKey(_results), findsOneWidget);
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
