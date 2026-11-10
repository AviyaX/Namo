import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/home/reading_card.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../support/pump_app.dart';
import '../support/test_content.dart';

Section _section(String id, int number) => Section(
  id: id,
  number: number,
  heading: 'Heading $id',
  verses: [Verse(id: '$id-v1', paliSi: 'pali', sinhala: 'sinhala')],
);

/// One category with two readings (2 + 1 sections), Latin placeholder titles.
Library _twoReadings() => Library(
  categories: [
    Category(
      id: 'c1',
      title: 'Category one',
      subtitle: 'Subtitle one',
      readings: [
        Reading(
          id: 'ra',
          title: 'Alpha reading',
          sections: [_section('a01', 1), _section('a02', 2)],
        ),
        Reading(
          id: 'rb',
          title: 'Beta reading',
          sections: [_section('b01', 1)],
        ),
      ],
    ),
  ],
);

Library _manyCategories(int n) => Library(
  categories: [
    for (var i = 1; i <= n; i++)
      Category(
        id: 'c$i',
        title: 'Category $i',
        subtitle: 'Subtitle $i',
        readings: [
          Reading(
            id: 'r$i',
            title: 'Reading $i',
            sections: [_section('s$i', 1)],
          ),
        ],
      ),
  ],
);

void main() {
  setUpAll(loadBundledFonts);

  testWidgets(
    'Home shows one card per category with title, subtitle and "19 sections"',
    (t) async {
      await openReal(t, Routes.home);
      final lib = await realLibrary(t);
      expect(find.byType(ReadingCard), findsNWidgets(lib.categories.length));
      final c = lib.categories.first;
      final card = find.byType(ReadingCard).first;
      expect(
        find.descendant(of: card, matching: find.text(c.title)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(c.subtitle)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('19 sections')),
        findsOneWidget,
      );
    },
  );

  testWidgets('a single section is written "1 section"', (t) async {
    await openReal(t, Routes.home, library: _manyCategories(1));
    expect(find.text('1 section'), findsOneWidget);
  });

  testWidgets('tapping the card opens the reader for a one-reading category', (
    t,
  ) async {
    await openReal(t, Routes.home);
    await t.tap(find.byType(ReadingCard).first);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('screen-library')), findsNothing);
  });

  testWidgets(
    'a category with two readings shows the summed section count and goes to the Library with it open',
    (t) async {
      await openReal(t, Routes.home, library: _twoReadings());
      expect(find.text('3 sections'), findsOneWidget);
      await t.tap(find.byType(ReadingCard));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
      expect(find.text('Alpha reading'), findsOneWidget);
      expect(find.text('Heading b01'), findsOneWidget);
    },
  );

  testWidgets(
    'the card is one button for screen readers, labelled "<title>, <subtitle>, 19 sections"',
    (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.home);
      final c = (await realLibrary(t)).categories.first;
      final label = '${c.title}, ${c.subtitle}, 19 sections';
      final node = find.bySemanticsLabel(label);
      expect(node, findsOneWidget);
      final data = t.getSemantics(node).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      // One node: the title and the subtitle are not separate nodes.
      expect(find.bySemanticsLabel(c.title), findsNothing);
      expect(find.bySemanticsLabel(c.subtitle), findsNothing);
      handle.dispose();
    },
  );

  testWidgets(
    'at 1280x800 a single card is at most 360 wide and starts at the content column edge',
    (t) async {
      await openReal(t, Routes.home, size: const Size(1280, 800));
      final card = find.byType(ReadingCard).first;
      final width = t.getSize(card).width;
      expect(width, inInclusiveRange(320, 360));
      // Left edge of the column: where the Namo heading starts.
      expect(t.getTopLeft(card).dx, t.getTopLeft(find.text('Namo')).dx);
    },
  );

  testWidgets('at 1280x800 the cards wrap into a grid with 16 px gaps', (
    t,
  ) async {
    await openReal(
      t,
      Routes.home,
      size: const Size(1280, 800),
      library: _manyCategories(4),
    );
    final a = find.byType(ReadingCard).at(0);
    final b = find.byType(ReadingCard).at(1);
    final c = find.byType(ReadingCard).at(2);
    final d = find.byType(ReadingCard).at(3);
    expect(t.getTopLeft(b).dy, t.getTopLeft(a).dy);
    expect(t.getTopLeft(b).dx - t.getTopRight(a).dx, closeTo(16, 0.01));
    // At 1280x800 (pinned above) three cards fit a row, so the fourth
    // always starts the second row and the row gap is always checked.
    expect(t.getTopLeft(c).dy, t.getTopLeft(a).dy);
    expect(t.getTopLeft(d).dx, t.getTopLeft(a).dx);
    expect(t.getTopLeft(d).dy - t.getBottomLeft(a).dy, closeTo(16, 0.01));
    for (final i in [0, 1, 2, 3]) {
      expect(
        t.getSize(find.byType(ReadingCard).at(i)).width,
        inInclusiveRange(320, 360),
      );
    }
  });

  testWidgets('on a phone each card takes the full width of the column', (
    t,
  ) async {
    await openReal(t, Routes.home, library: _manyCategories(2));
    expect(t.getSize(find.byType(ReadingCard).first).width, 390 - 32);
    expect(
      t.getTopLeft(find.byType(ReadingCard).at(1)).dy,
      greaterThan(t.getBottomLeft(find.byType(ReadingCard).first).dy),
    );
  });

  testWidgets(
    'Continue reading still shows above the cards after something was read',
    (t) async {
      await pumpApp(
        t,
        overrides: [
          contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );
      final c = ProviderScope.containerOf(
        t.element(find.byType(Scaffold).first),
      );
      c
          .read(positionProvider.notifier)
          .save(
            const ReadingPosition(
              readingId: 'r1',
              sectionId: 's02',
              fraction: 0,
            ),
            0.5,
          );
      await t.pumpAndSettle();
      expect(find.text('Continue reading'), findsOneWidget);
      expect(find.byType(ReadingCard), findsOneWidget);
      expect(
        t.getTopLeft(find.text('Continue reading')).dy,
        lessThan(t.getTopLeft(find.byType(ReadingCard)).dy),
      );
    },
  );

  testWidgets(
    'Home shows Continue reading only after something was read, and reopens at that place',
    (t) async {
      await pumpApp(
        t,
        overrides: [
          contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );
      expect(find.text('Continue reading'), findsNothing);
      expect(find.text('category 1'), findsOneWidget);

      final c = ProviderScope.containerOf(
        t.element(find.byType(Scaffold).first),
      );
      c
          .read(positionProvider.notifier)
          .save(
            const ReadingPosition(
              readingId: 'r1',
              sectionId: 's02',
              fraction: 0,
            ),
            0.5,
          );
      await t.pumpAndSettle();

      expect(find.text('Continue reading'), findsOneWidget);
      expect(find.text('reading 1'), findsOneWidget);
      expect(find.text('heading 2'), findsOneWidget);
      final line = t.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(line.value, 0.5);
      expect(
        find.bySemanticsLabel(RegExp('^Continue reading, reading 1')),
        findsOneWidget,
      );

      await t.tap(find.text('reading 1'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('heading-s02')), findsOneWidget);
    },
  );

  testWidgets(
    'Continue reading is absent when the reading is not in the content',
    (t) async {
      final store = InMemoryKeyValueStore();
      await pumpApp(
        t,
        overrides: [
          contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
          keyValueStoreProvider.overrideWithValue(store),
        ],
      );
      final c = ProviderScope.containerOf(
        t.element(find.byType(Scaffold).first),
      );
      c
          .read(positionProvider.notifier)
          .save(
            const ReadingPosition(
              readingId: 'gone',
              sectionId: 's01',
              fraction: 0,
            ),
            0.2,
          );
      await t.pumpAndSettle();
      expect(find.text('Continue reading'), findsNothing);
    },
  );
}
