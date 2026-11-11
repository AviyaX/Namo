import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/settings/choosers.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';

const _sections = ['s01', 's02', 's03'];

/// Starts a fresh app at [location]; calling it again in the same test
/// starts over with a new router.
Future<ProviderContainer> openAt(WidgetTester t, String location) async {
  await t.pumpWidget(const SizedBox());
  await pumpApp(
    t,
    overrides: [
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
    ],
    location: location,
  );
  return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
}

ReaderBodyState body(WidgetTester t) =>
    t.state<ReaderBodyState>(find.byType(ReaderBody));

double bodyTop(WidgetTester t) => t.getTopLeft(find.byType(ReaderBody)).dy;

double headingTop(WidgetTester t, String sectionId) =>
    t.getTopLeft(find.byKey(ValueKey('heading-$sectionId'))).dy;

void expectHeadingAtTop(WidgetTester t, String sectionId) {
  expect(
    (headingTop(t, sectionId) - bodyTop(t)).abs(),
    lessThan(1),
    reason: '$sectionId should be at the top',
  );
}

NamoIconButton button(WidgetTester t, String key) =>
    t.widget<NamoIconButton>(find.byKey(ValueKey(key)));

Text verseText(WidgetTester t, String key) => t.widget<Text>(
  find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text)),
);

Future<void> openSheet(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('reader-settings')));
  await t.pumpAndSettle();
}

Finder chooserRow(Type chooser, String label) =>
    find.descendant(of: find.byType(chooser), matching: find.text(label));

bool aHeadingIsOnScreen(WidgetTester t) {
  final view = t.getRect(find.byType(ReaderBody));
  return _sections.any((id) {
    final f = find.byKey(ValueKey('heading-$id'));
    return f.evaluate().isNotEmpty && t.getRect(f).overlaps(view);
  });
}

void main() {
  testWidgets('shows the title in the top bar and every section heading', (
    t,
  ) async {
    await openAt(t, Routes.reader('r1'));
    final bar = find.byKey(const ValueKey('reader-top-bar'));
    expect(
      find.descendant(of: bar, matching: find.text('reading 1')),
      findsOneWidget,
    );
    expect(
      t.widget<Text>(find.text('reading 1')).style!.color,
      NamoPalette.dark.textSecondary, // the app opens dark
    );
    for (var i = 1; i <= 3; i++) {
      expect(find.byKey(ValueKey('heading-s0$i')), findsOneWidget);
      expect(find.text('heading $i'), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('verse-s01-v1-pi')), findsOneWidget);
    expect(find.byKey(const ValueKey('verse-s01-v1-si')), findsOneWidget);

    // Every control has a label and a 48 x 48 touch area.
    for (final label in [
      'Back',
      'Add to favourites',
      'Reading settings',
      'Previous section',
      'Start auto-scroll',
      'Next section',
    ]) {
      final f = find.byTooltip(label);
      expect(f, findsOneWidget, reason: label);
      final size = t.getSize(f);
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('a long title stays on one line, cut short, inside the top bar', (
    t,
  ) async {
    // In the test font every letter is as wide as the text is tall: far too
    // long for one line of the top bar at this width.
    const title = 'the long title of this reading';
    final library = testLibrary();
    final reading = library.categories.single.readings.single;
    final long = Library(
      categories: [
        Category(
          id: 'c1',
          title: 'category 1',
          subtitle: 'subtitle 1',
          readings: [
            Reading(id: 'r1', title: title, sections: reading.sections),
          ],
        ),
      ],
    );
    await pumpApp(
      t,
      overrides: [
        contentRepositoryProvider.overrideWithValue(
          FakeContentRepository(library: long),
        ),
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      ],
      location: Routes.reader('r1'),
    );
    expect(t.view.physicalSize, const Size(390, 844));
    final paragraph = t.renderObject<RenderParagraph>(find.text(title));
    final boxes = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: title.length),
    );
    expect({for (final b in boxes) b.top}, hasLength(1));
    expect(paragraph.didExceedMaxLines, isTrue);
    final bar = t.getRect(find.byKey(const ValueKey('reader-top-bar')));
    final words = t.getRect(find.text(title));
    expect(bar.contains(words.topLeft), isTrue);
    expect(bar.contains(words.bottomRight), isTrue);
    // The buttons beside it keep their place.
    expect(find.byTooltip('Reading settings'), findsOneWidget);
    expect(
      t.getRect(find.byTooltip('Reading settings')).right,
      lessThanOrEqualTo(390),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('a reading titled like its category shows the title once', (
    t,
  ) async {
    const same = Library(
      categories: [
        Category(
          id: 'c1',
          title: 'same title',
          subtitle: 'subtitle 1',
          readings: [
            Reading(
              id: 'r1',
              title: 'same title',
              sections: [
                Section(
                  id: 's01',
                  number: 1,
                  heading: 'heading 1',
                  verses: [Verse(id: 's01-v1', paliSi: 'pali 1')],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await pumpApp(
      t,
      overrides: [
        contentRepositoryProvider.overrideWithValue(
          FakeContentRepository(library: same),
        ),
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      ],
      location: Routes.reader('r1'),
    );
    expect(find.text('same title'), findsOneWidget);
    expect(find.byKey(const ValueKey('heading-s01')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('opening at ?section=s02 puts that heading at the top', (
    t,
  ) async {
    await openAt(t, Routes.reader('r1', sectionId: 's02'));
    expectHeadingAtTop(t, 's02');
  });

  testWidgets('the last section can also be opened at the top', (t) async {
    await openAt(t, Routes.reader('r1', sectionId: 's03'));
    expectHeadingAtTop(t, 's03');
  });

  testWidgets(
    'unknown section opens at the top; unknown reading shows not-found',
    (t) async {
      await openAt(t, Routes.reader('r1', sectionId: 'nope'));
      expect(t.takeException(), isNull);
      expectHeadingAtTop(t, 's01');
      expect(body(t).controller.offset, 0);

      await openAt(t, Routes.reader('nope'));
      expect(t.takeException(), isNull);
      expect(find.text('This page could not be found.'), findsOneWidget);
      expect(find.byType(ReaderBody), findsNothing);
    },
  );

  testWidgets(
    'next and previous move between headings and disable at the ends',
    (t) async {
      await openAt(t, Routes.reader('r1'));
      expect(button(t, 'reader-prev').onPressed, isNull);
      expect(button(t, 'reader-next').onPressed, isNotNull);

      await t.tap(find.byKey(const ValueKey('reader-next')));
      await t.pumpAndSettle();
      expectHeadingAtTop(t, 's02');
      expect(button(t, 'reader-prev').onPressed, isNotNull);

      await t.tap(find.byKey(const ValueKey('reader-next')));
      await t.pumpAndSettle();
      expectHeadingAtTop(t, 's03');
      expect(button(t, 'reader-next').onPressed, isNull);
      expect(button(t, 'reader-prev').onPressed, isNotNull);

      // Within 8 px of a section's start, previous goes to the section before.
      await t.tap(find.byKey(const ValueKey('reader-prev')));
      await t.pumpAndSettle();
      expectHeadingAtTop(t, 's02');
      expect(button(t, 'reader-next').onPressed, isNotNull);

      // Further into a section, previous goes back to that section's start.
      final c = body(t).controller;
      c.jumpTo(c.offset + 30);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('reader-prev')));
      await t.pumpAndSettle();
      expectHeadingAtTop(t, 's02');

      await t.tap(find.byKey(const ValueKey('reader-prev')));
      await t.pumpAndSettle();
      expectHeadingAtTop(t, 's01');
      expect(button(t, 'reader-prev').onPressed, isNull);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('the sheet changes text size and line spacing at once', (
    t,
  ) async {
    final c = await openAt(t, Routes.reader('r1'));
    await openSheet(t);
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('Line spacing'), findsOneWidget);

    final size = find.byKey(const ValueKey('reader-text-size'));
    await t.ensureVisible(size);
    await t.pumpAndSettle();
    await t.drag(size, const Offset(1000, 0));
    await t.pumpAndSettle();
    expect(c.read(settingsProvider).fontScale, 1.6);
    expect(
      verseText(t, 'verse-s01-v1-pi').style!.fontSize,
      closeTo(18 * 1.6, 1e-9),
    );
    expect(
      verseText(t, 'verse-s01-v1-si').style!.fontSize,
      closeTo(18 * 1.6, 1e-9),
    );

    final spacing = find.byKey(const ValueKey('reader-line-spacing'));
    await t.ensureVisible(spacing);
    await t.pumpAndSettle();
    await t.drag(spacing, const Offset(-1000, 0));
    await t.pumpAndSettle();
    expect(c.read(settingsProvider).lineSpacing, 1.3);
    expect(verseText(t, 'verse-s01-v1-pi').style!.height, 1.3);
    expect(t.takeException(), isNull);
  });

  testWidgets('switching languages in the sheet while reading does not throw', (
    t,
  ) async {
    final c = await openAt(t, Routes.reader('r1'));
    final scroll = body(t).controller;
    scroll.jumpTo(scroll.position.maxScrollExtent / 2);
    await t.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    await openSheet(t);

    const pi = ReadingLanguage.pali,
        si = ReadingLanguage.sinhala,
        en = ReadingLanguage.english;
    // Each toggle and the selection it leads to; together they pass through
    // every single language and every ordered pair.
    const steps = [
      (pi, [si]),
      (en, [si, en]),
      (si, [en]),
      (pi, [en, pi]),
      (en, [pi]),
      (en, [pi, en]),
      (pi, [en]),
      (si, [en, si]),
      (en, [si]),
      (pi, [si, pi]),
    ];
    final seen = <String>{'pi si'};
    for (final (toggle, expected) in steps) {
      await t.tap(chooserRow(LanguageChooser, toggle.label));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(c.read(settingsProvider).languages.languages, expected);
      expect(aHeadingIsOnScreen(t), isTrue, reason: '$expected');
      seen.add(expected.map((l) => l.code).join(' '));
    }
    expect(seen, hasLength(9));
  });

  testWidgets('changing languages or text size keeps the same section on top', (
    t,
  ) async {
    final c = await openAt(t, Routes.reader('r1', sectionId: 's02'));
    expectHeadingAtTop(t, 's02');
    await openSheet(t);
    await t.tap(chooserRow(LanguageChooser, 'Pali'));
    await t.pumpAndSettle();
    expect(c.read(settingsProvider).languages.languages, [
      ReadingLanguage.sinhala,
    ]);
    expectHeadingAtTop(t, 's02');

    c.read(settingsProvider.notifier).setFontScale(1.6);
    await t.pumpAndSettle();
    expectHeadingAtTop(t, 's02');
    expect(t.takeException(), isNull);
  });

  testWidgets('switching layout swaps the order of items', (t) async {
    await openAt(t, Routes.reader('r1'));
    double top(String key) => t.getTopLeft(find.byKey(ValueKey(key))).dy;
    expect(top('verse-s01-v2-pi'), greaterThan(top('verse-s01-v1-si')));

    await openSheet(t);
    await t.tap(chooserRow(LayoutChooser, 'Section by section'));
    await t.pumpAndSettle();
    expect(top('verse-s01-v2-pi'), lessThan(top('verse-s01-v1-si')));
    expect(t.takeException(), isNull);
  });

  testWidgets('back from the reader lands on the contents list', (t) async {
    await openAt(t, Routes.contents('r1'));
    await t.tap(find.text('heading 2'));
    await t.pumpAndSettle();
    expectHeadingAtTop(t, 's02');

    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(find.byType(ReaderBody), findsNothing);
    expect(find.text('heading 2'), findsOneWidget);
    expect(find.bySemanticsLabel('2, heading 2'), findsOneWidget);

    // Opened straight from an address, back still has somewhere to go.
    await openAt(t, Routes.reader('r1'));
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(find.byType(ReaderBody), findsNothing);
    expect(find.bySemanticsLabel('1, heading 1'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
