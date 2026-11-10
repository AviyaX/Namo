import 'dart:ui' show Tristate;

import 'package:buddhist_gatha/app.dart';
import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/typography.dart';
import 'package:buddhist_gatha/home/featured_card.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/design/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../quality/quality_support.dart';
import '../support/pump_app.dart';
import '../support/test_content.dart';

Section _section(String id, int number, String heading) => Section(
  id: id,
  number: number,
  heading: heading,
  verses: [Verse(id: '$id-v1', paliSi: 'pali', sinhala: 'sinhala')],
);

/// One category with two readings, Latin placeholder titles.
Library _twoReadings() => Library(
  categories: [
    Category(
      id: 'c1',
      title: 'category 1',
      subtitle: 'subtitle 1',
      readings: [
        Reading(
          id: 'ra',
          title: 'Alpha reading',
          sections: [
            _section('a01', 1, 'Alpha one'),
            _section('a02', 2, 'Alpha two'),
          ],
        ),
        Reading(
          id: 'rb',
          title: 'Beta reading',
          sections: [_section('b01', 1, 'Beta one')],
        ),
      ],
    ),
  ],
);

String _location(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .routeInformationProvider
        .value
        .uri
        .toString();

void main() {
  setUpAll(loadBundledFonts);
  final fake = [
    contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
  ];

  testWidgets('Library shows the category card closed, with no section rows', (
    t,
  ) async {
    await pumpApp(t, overrides: fake, location: Routes.library);
    expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
    expect(find.text('category 1'), findsOneWidget);
    expect(find.text('subtitle 1'), findsOneWidget);
    expect(find.byIcon(Symbols.expand_more_rounded), findsOneWidget);
    expect(find.text('heading 1'), findsNothing);
  });

  testWidgets(
    'tapping the card shows all 19 sections in place and stays on /library',
    (t) async {
      final lib = await realLibrary(t);
      final reading = lib.reading(realReadingId)!;
      expect(reading.sections.length, 19);
      await openReal(t, Routes.library, size: const Size(390, 4000));
      await t.tap(find.text(lib.category(realCategoryId)!.title));
      await t.pumpAndSettle();
      for (final s in reading.sections) {
        expect(find.text(s.heading), findsOneWidget, reason: s.id);
      }
      expect(_location(t), '/library');
    },
  );

  testWidgets('tapping the card again hides the sections', (t) async {
    await pumpApp(t, overrides: fake, location: Routes.library);
    await t.tap(find.text('category 1'));
    await t.pumpAndSettle();
    expect(find.text('heading 1'), findsOneWidget);
    await t.tap(find.text('category 1'));
    await t.pumpAndSettle();
    expect(find.text('heading 1'), findsNothing);
  });

  testWidgets('sections look like the old contents rows', (t) async {
    await pumpApp(t, overrides: fake, location: Routes.library);
    await t.tap(find.text('category 1'));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('1, heading 1'), findsOneWidget);
    final row = t.getSize(
      find
          .ancestor(
            of: find.text('heading 1'),
            matching: find.byType(Pressable),
          )
          .first,
    );
    expect(row.height, greaterThanOrEqualTo(48));
  });

  testWidgets('tapping a section opens the reader at that section', (t) async {
    await pumpApp(t, overrides: fake, location: Routes.library);
    await t.tap(find.text('category 1'));
    await t.pumpAndSettle();
    await t.tap(find.text('heading 2'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('heading-s02')), findsOneWidget);
    expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
  });

  testWidgets('the card says expanded / collapsed to screen readers', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pumpApp(t, overrides: fake, location: Routes.library);
    final card = find.bySemanticsLabel('category 1, subtitle 1');
    SemanticsData data() => t.getSemantics(card).getSemanticsData();
    expect(data().flagsCollection.isButton, isTrue);
    expect(data().flagsCollection.isExpanded, Tristate.isFalse);
    await t.tap(find.text('category 1'));
    await t.pumpAndSettle();
    expect(data().flagsCollection.isExpanded, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('Enter on the focused card toggles it', (t) async {
    await pumpApp(t, overrides: fake, location: Routes.library);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.text('heading 1'), findsOneWidget);
  });

  testWidgets(
    'the open list is still open after going to another tab and back, and after returning from the reader',
    (t) async {
      await pumpApp(t, overrides: fake, location: Routes.library);
      await t.tap(find.text('category 1'));
      await t.pumpAndSettle();
      await t.tap(find.text('Saved'));
      await t.pumpAndSettle();
      await t.tap(find.text('Library'));
      await t.pumpAndSettle();
      expect(find.text('heading 1'), findsOneWidget);

      await t.tap(find.text('heading 3'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
      expect(find.text('heading 1'), findsOneWidget);
    },
  );

  testWidgets('Home category card lands on the Library with the list open', (
    t,
  ) async {
    // A category with one reading opens the reader from Home, so this one
    // has two.
    await pumpApp(
      t,
      overrides: [
        contentRepositoryProvider.overrideWithValue(
          FakeContentRepository(library: _twoReadings()),
        ),
      ],
    );
    await t.tap(find.byType(FeaturedCard));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
    expect(find.text('Alpha one'), findsOneWidget);
    expect(find.text('Beta one'), findsOneWidget);
  });

  for (final old in ['/library/category/c1', '/library/reading/r1']) {
    testWidgets('old address $old lands on the Library with the list open', (
      t,
    ) async {
      await pumpApp(t, overrides: fake, location: old);
      expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
      expect(find.text('heading 1'), findsOneWidget);
      expect(find.text('This page could not be found.'), findsNothing);
      expect(_location(t), '/library');
    });
  }

  for (final unknown in ['/library/category/nope', '/library/reading/nope']) {
    testWidgets('old address $unknown (unknown id) shows the Library closed', (
      t,
    ) async {
      await pumpApp(t, overrides: fake, location: unknown);
      expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
      expect(find.text('category 1'), findsOneWidget);
      expect(find.text('heading 1'), findsNothing);
    });
  }

  testWidgets(
    'a category with two readings shows each reading title above its sections',
    (t) async {
      await pumpApp(
        t,
        overrides: [
          contentRepositoryProvider.overrideWithValue(
            FakeContentRepository(library: _twoReadings()),
          ),
        ],
        location: Routes.library,
      );
      await t.tap(find.text('category 1'));
      await t.pumpAndSettle();
      expect(find.text('Alpha reading'), findsOneWidget);
      expect(find.text('Beta reading'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('Alpha reading')).dy,
        lessThan(t.getTopLeft(find.text('Alpha one')).dy),
      );
      expect(
        t.getTopLeft(find.text('Beta reading')).dy,
        greaterThan(t.getTopLeft(find.text('Alpha two')).dy),
      );
      expect(
        t.getTopLeft(find.text('Beta reading')).dy,
        lessThan(t.getTopLeft(find.text('Beta one')).dy),
      );
      await t.tap(find.text('Beta one'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('heading-b01')), findsOneWidget);
    },
  );

  testWidgets('a reading heading uses the same family as the section rows '
      '(a reading title may be Sinhala)', (t) async {
    await pumpApp(
      t,
      overrides: [
        contentRepositoryProvider.overrideWithValue(
          FakeContentRepository(library: _twoReadings()),
        ),
      ],
      location: Routes.library,
    );
    await t.tap(find.text('category 1'));
    await t.pumpAndSettle();
    final heading = t.widget<Text>(find.text('Alpha reading'));
    final row = t.widget<Text>(find.text('Alpha one'));
    expect(heading.style!.fontFamily, NamoFonts.sinhala);
    expect(heading.style!.fontFamily, row.style!.fontFamily);
    // The family is itself the bundled Sinhala one; the fallback is the other
    // bundled family, so no font is fetched.
    expect(heading.style!.fontFamilyFallback, row.style!.fontFamilyFallback);
    expect(heading.style!.fontFamilyFallback, [NamoFonts.serif]);
  });

  testWidgets('a single reading shows no reading heading', (t) async {
    await pumpApp(t, overrides: fake, location: Routes.library);
    await t.tap(find.text('category 1'));
    await t.pumpAndSettle();
    expect(find.text('reading 1'), findsNothing);
  });

  testWidgets('with animations disabled the list opens at once', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(t, overrides: fake, location: Routes.library);
    await t.tap(find.text('category 1'));
    await t.pump();
    expect(find.text('heading 1'), findsOneWidget);
    expect(
      t.getSize(find.byKey(const ValueKey('open-c1'))).height,
      greaterThan(100),
    );
    expect(t.binding.hasScheduledFrame, isFalse);

    // And closes at once.
    await t.tap(find.text('category 1'));
    await t.pump();
    expect(find.byKey(const ValueKey('open-c1')), findsNothing);
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the list opens and closes over 200 ms', (t) async {
    await pumpApp(t, overrides: fake, location: Routes.library);
    final list = find.byKey(const ValueKey('open-c1'));
    // The list keeps its full size inside; the clip around it shows part.
    double height() => t
        .getSize(find.ancestor(of: list, matching: find.byType(ClipRect)).first)
        .height;

    await t.tap(find.text('category 1'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    final halfway = height();
    await t.pump(const Duration(milliseconds: 100));
    final full = height();
    expect(halfway, greaterThan(0));
    expect(halfway, lessThan(full));
    await t.pumpAndSettle();
    expect(height(), full);

    await t.tap(find.text('category 1'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(height(), greaterThan(0));
    expect(height(), lessThan(full));
    await t.pump(const Duration(milliseconds: 100));
    expect(list, findsNothing);
  });

  testWidgets('several categories can be open at once', (t) async {
    await pumpApp(
      t,
      overrides: [
        contentRepositoryProvider.overrideWithValue(
          FakeContentRepository(
            library: Library(
              categories: [
                ...testLibrary().categories,
                ..._twoReadings().categories.map(
                  (c) => Category(
                    id: 'c2',
                    title: 'category 2',
                    subtitle: 'subtitle 2',
                    readings: c.readings,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      location: Routes.library,
      size: const Size(390, 2000),
    );
    await t.tap(find.text('category 1'));
    await t.pumpAndSettle();
    await t.tap(find.text('category 2'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-c1')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-c2')), findsOneWidget);
    expect(find.text('heading 1'), findsOneWidget);
    expect(find.text('Alpha one'), findsOneWidget);

    // Closing one leaves the other open.
    await t.tap(find.text('category 1'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-c1')), findsNothing);
    expect(find.text('Alpha one'), findsOneWidget);
  });

  testWidgets('the Home card opens the list again after the person closed it', (
    t,
  ) async {
    await pumpApp(
      t,
      overrides: [
        contentRepositoryProvider.overrideWithValue(
          FakeContentRepository(library: _twoReadings()),
        ),
      ],
    );
    await t.tap(find.byType(FeaturedCard));
    await t.pumpAndSettle();
    expect(find.text('Alpha one'), findsOneWidget);

    await t.tap(find.text('category 1'));
    await t.pumpAndSettle();
    expect(find.text('Alpha one'), findsNothing);

    await t.tap(find.text('Home'));
    await t.pumpAndSettle();
    await t.tap(find.byType(FeaturedCard));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
    expect(find.text('Alpha one'), findsOneWidget);
  });

  group('an address request', () {
    Future<void> pumpUntilLibrary(WidgetTester t) async {
      for (
        var i = 0;
        i < 20 && find.text('category 1').evaluate().isEmpty;
        i++
      ) {
        await t.pump();
      }
      expect(find.text('category 1'), findsOneWidget);
    }

    testWidgets(
      'opens the list on the first frame that shows the Library, with no animation',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              ...fake,
              routerProvider.overrideWith(
                (ref) => buildRouter(initialLocation: Routes.category('c1')),
              ),
            ],
            child: const NamoApp(),
          ),
        );
        await pumpUntilLibrary(t);
        expect(find.text('heading 1'), findsOneWidget);
        final height = t.getSize(find.byKey(const ValueKey('open-c1'))).height;
        await t.pumpAndSettle();
        expect(t.getSize(find.byKey(const ValueKey('open-c1'))).height, height);
      },
    );

    testWidgets(
      'opens the list on the first frame when the Library is kept alive (from Home)',
      (t) async {
        await pumpApp(
          t,
          overrides: [
            contentRepositoryProvider.overrideWithValue(
              FakeContentRepository(library: _twoReadings()),
            ),
          ],
          location: Routes.library,
        );
        await t.tap(find.text('Home'));
        await t.pumpAndSettle();
        await t.tap(find.byType(FeaturedCard));
        await t.pump();
        expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
        // In the Library (Home, fading out, shows the same heading on its
        // section row).
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('screen-library')),
            matching: find.text('Alpha one'),
          ),
          findsOneWidget,
        );
        final height = t.getSize(find.byKey(const ValueKey('open-c1'))).height;
        await t.pumpAndSettle();
        expect(t.getSize(find.byKey(const ValueKey('open-c1'))).height, height);
      },
    );

    testWidgets('is handled exactly once, however often the screen rebuilds', (
      t,
    ) async {
      var changes = 0;
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            ...fake,
            routerProvider.overrideWith((ref) {
              final r = buildRouter(initialLocation: Routes.category('c1'));
              r.routeInformationProvider.addListener(() => changes++);
              return r;
            }),
          ],
          child: const NamoApp(),
        ),
      );
      // Several frames while the request is pending.
      for (var i = 0; i < 5; i++) {
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(changes, 1);
      expect(_location(t), '/library');
      expect(find.text('heading 1'), findsOneWidget);
    });
  });
}
