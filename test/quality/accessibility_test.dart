import 'dart:convert';

import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/floating_bar.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quality_support.dart';

Future<void> expectGuidelines(WidgetTester t) async {
  await expectLater(t, meetsGuideline(androidTapTargetGuideline));
  await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(t, meetsGuideline(textContrastGuideline));
}

Future<void> openSheet(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('reader-settings')));
  await t.pumpAndSettle();
}

void main() {
  // The test font is used here, not the bundled ones: the contrast check
  // reads the most common dark pixel, and the thin strokes of a real font at
  // 14-16 px are mostly anti-aliasing, which reads as a paler colour than the
  // text really is. Glyph shapes do not change a colour's contrast.

  // Each screen, with the surface it is checked on (tall where the page
  // scrolls, so everything is on screen) and what to do once it is open.
  final screens = <(String, String, Size, Future<void> Function(WidgetTester)?, bool)>[
    ('Home', Routes.home, const Size(390, 1800), null, false),
    ('Library (closed)', Routes.library, const Size(390, 844), null, false),
    ('Library (open)', Routes.category(realCategoryId), const Size(390, 1800), null, false),
    ('Reader', Routes.reader(realReadingId), const Size(390, 844), null, false),
    ('Reader sheet', Routes.reader(realReadingId), const Size(390, 844), openSheet, false),
    ('Saved', Routes.saved, const Size(390, 844), null, true),
    ('Settings', Routes.settings, const Size(390, 1400), null, false),
    ('Sources', Routes.sources, const Size(390, 6000), null, false),
  ];

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('openReal(settings: ${mode.name}) without dark uses it', (t) async {
      await openReal(t, Routes.home, settings: AppSettings(themeMode: mode));
      final expected = mode == ThemeMode.dark ? NamoPalette.dark : NamoPalette.light;
      final context = t.element(find.byType(Scaffold).first);
      expect(Theme.of(context).scaffoldBackgroundColor, expected.background);
      expect(NamoPalette.of(context), expected);
    });
  }

  for (final dark in [false, true]) {
    testWidgets('openReal(dark: $dark) really selects the theme', (t) async {
      await openReal(t, Routes.home, dark: dark);
      final expected = dark ? NamoPalette.dark : NamoPalette.light;
      final context = t.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, dark ? Brightness.dark : Brightness.light);
      expect(Theme.of(context).scaffoldBackgroundColor, expected.background);
      expect(NamoPalette.of(context), expected);
    });
  }

  for (final dark in [false, true]) {
    for (final (name, location, size, after, saved) in screens) {
      testWidgets(
        '$name (${dark ? 'dark' : 'light'}) meets tap-target, label and contrast guidelines',
        (t) async {
          final handle = t.ensureSemantics();
          await openReal(t, location, size: size, dark: dark, withSaved: saved);
          if (after != null) await after(t);
          await expectGuidelines(t);
          handle.dispose();
        },
      );
    }
  }

  for (final dark in [false, true]) {
    for (final size in const [Size(390, 1800), Size(1280, 800)]) {
      testWidgets(
        'Home with several reading cards (${dark ? 'dark' : 'light'}, ${size.width.round()}x${size.height.round()}) '
        'meets tap-target, label and contrast guidelines',
        (t) async {
          final handle = t.ensureSemantics();
          await openReal(t, Routes.home, size: size, dark: dark, library: severalCategories());
          expect(find.byKey(const ValueKey('card-art-panel')), findsNWidgets(4));
          await expectGuidelines(t);
          handle.dispose();
        },
      );
    }
  }

  testWidgets('the reader with a recording meets the guidelines', (t) async {
    final handle = t.ensureSemantics();
    await openReal(t, Routes.reader(realReadingId), audio: true);
    expect(find.text('Development placeholder tone (not a chant)'), findsOneWidget);
    await expectGuidelines(t);
    handle.dispose();
  });

  group('bottom bar and navigation rail', () {
    const tabs = ['Home', 'Library', 'Saved', 'Settings'];

    testWidgets('the bottom bar has the four tabs, each labelled and 48 high', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.home);
      for (final tab in tabs) {
        final node = find.bySemanticsLabel(RegExp('^$tab'));
        expect(node, findsWidgets, reason: tab);
      }
      final bar = find.byType(FloatingBar);
      expect(bar, findsOneWidget);
      expect(t.getSize(bar).height, greaterThanOrEqualTo(48));
      for (final tab in tabs) {
        final destination = find.ancestor(
          of: find.text(tab),
          matching: find.byKey(ValueKey('nav-${tab.toLowerCase()}')),
        );
        expect(t.getSize(destination).height, greaterThanOrEqualTo(48), reason: tab);
        expect(t.getSize(destination).width, greaterThanOrEqualTo(48), reason: tab);
      }
      expect(find.byKey(const ValueKey('nav-rail')), findsNothing);
      handle.dispose();
    });

    testWidgets('the rail has the four tabs, each labelled and at least 48 x 48', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.home, size: const Size(1280, 800));
      expect(find.byKey(const ValueKey('nav-rail')), findsOneWidget);
      expect(find.byType(FloatingBar), findsNothing);
      for (final tab in tabs) {
        expect(find.bySemanticsLabel(RegExp('^$tab')), findsWidgets, reason: tab);
        final size = t.getSemantics(find.bySemanticsLabel(RegExp('^$tab')).first).rect.size;
        expect(size.width, greaterThanOrEqualTo(48), reason: tab);
        expect(size.height, greaterThanOrEqualTo(48), reason: tab);
      }
      handle.dispose();
    });

    testWidgets('the rail keeps clear of a left inset (a notch or a rounded edge)', (t) async {
      await openReal(t, Routes.home, size: const Size(1280, 800));
      // Measure the rail again with a 44 px left display cut-out.
      t.view.padding = const FakeViewPadding(left: 44);
      t.view.viewPadding = const FakeViewPadding(left: 44);
      addTearDown(t.view.resetPadding);
      addTearDown(t.view.resetViewPadding);
      await t.pumpAndSettle();
      final rail = find.byKey(const ValueKey('nav-rail'));
      expect(t.getTopLeft(rail).dx, greaterThanOrEqualTo(44));
    });

    testWidgets('the rail meets the guidelines on a wide screen', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.home, size: const Size(1280, 800));
      await expectGuidelines(t);
      handle.dispose();
    });
  });

  // My flows: the same guidelines on its screens and sheets, in both themes,
  // with two flows saved over the bundled content.
  Future<void> tapKey(WidgetTester t, String key) async {
    await t.ensureVisible(find.byKey(ValueKey(key)));
    await t.pumpAndSettle();
    await t.tap(find.byKey(ValueKey(key)));
    await t.pumpAndSettle();
  }

  // Each with a text that shows the flows were loaded.
  final flowScreens = <(String, String, Size, String, Future<void> Function(WidgetTester)?)>[
    ('Library with My flows', Routes.library, const Size(390, 1400), 'Evening', null),
    ('New flow sheet', Routes.library, const Size(390, 844), 'Start from', (t) => tapKey(t, 'new-flow')),
    ('Home with Your flows', Routes.home, const Size(390, 1800), 'Your flows', null),
    ('Flow editor', Routes.flowEditor('flow-1'), const Size(390, 1400), '4 sections', null),
    ('Flow editor, move menu open', Routes.flowEditor('flow-1'), const Size(390, 1400), 'Move down',
        (t) async {
          final first = (await realLibrary(t)).reading(realReadingId)!.sections.first;
          await tapKey(t, 'flow-move-$realReadingId~${first.id}');
        }),
    ('Rename sheet', Routes.flowEditor('flow-1'), const Size(390, 844), 'Rename flow', (t) => tapKey(t, 'flow-rename')),
    ('Add sections sheet', Routes.flowEditor('flow-1'), const Size(390, 844), 'Add sections', (t) => tapKey(t, 'flow-add')),
    ('Delete dialog', Routes.flowEditor('flow-1'), const Size(390, 1400), 'Delete "Evening"? This cannot be undone.', (t) => tapKey(t, 'flow-delete')),
    ('Empty flow editor', Routes.flowEditor('flow-3'), const Size(390, 844), 'This flow has no sections yet.', null),
  ];

  for (final dark in [false, true]) {
    for (final (name, location, size, marker, after) in flowScreens) {
      testWidgets(
        '$name (${dark ? 'dark' : 'light'}) meets tap-target, label and contrast guidelines',
        (t) async {
          final handle = t.ensureSemantics();
          final stored = await realFlowsStore(t);
          await openReal(t, location, size: size, dark: dark, storeExtras: stored);
          if (after != null) await after(t);
          expect(find.text(marker), findsWidgets);
          await expectGuidelines(t);
          handle.dispose();
        },
      );
    }
  }

  // Home with a remembered place: the featured page shows "NN% complete" on
  // its own scrim (and, for a topic of several readings, the reading's name).
  // Buddha Wandanawa is the hero picture page; the pirith adds the caption.
  // The featured card is one merged semantics node, so the contrast
  // guideline cannot see the words inside it; their contrast is pinned by
  // pixel and scrim tests in test/home/featured_carousel_test.dart. This
  // checks the rest of Home (tap targets, labels, other text) in that state.
  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    for (final readingId in [realReadingId, mangalaReadingId]) {
      testWidgets('Home resuming $readingId ($theme) meets tap-target, label '
          'and contrast guidelines', (t) async {
        final handle = t.ensureSemantics();
        final reading = (await realLibrary(t)).reading(readingId)!;
        await openReal(
          t,
          Routes.home,
          size: const Size(390, 1800),
          dark: dark,
          storeExtras: {
            positionKey: jsonEncode(
              PositionState(
                byReading: {
                  readingId: ReadingProgress(
                    position: ReadingPosition(
                      readingId: readingId,
                      sectionId: reading.sections.first.id,
                      fraction: 0,
                    ),
                    progress: 0.34,
                  ),
                },
                lastReadingId: readingId,
              ).toJson(),
            ),
          },
        );
        expect(find.text('34% complete'), findsOneWidget);
        await expectGuidelines(t);
        handle.dispose();
      });
    }
  }

  // Samantha Pattana: the same guidelines on its screens, in both themes.
  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('Library with Samantha Pattana open ($theme) meets the '
        'guidelines', (t) async {
      final handle = t.ensureSemantics();
      await openReal(
        t,
        Routes.category(samanthaCategoryId),
        size: const Size(390, 1800),
        dark: dark,
      );
      for (final id in [spIntroductionId, spVandanaId]) {
        expect(find.byKey(ValueKey('reading-row-$id')), findsOneWidget);
      }
      await expectGuidelines(t);
      handle.dispose();
    });
    testWidgets('the Vandana in the reader, silent ($theme), meets the '
        'guidelines', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.reader(spVandanaId), dark: dark);
      expect(find.byKey(const ValueKey('chant-play')), findsOneWidget);
      await expectGuidelines(t);
      handle.dispose();
    });
    testWidgets('the Vandana chanting with a line marked ($theme) meets the '
        'guidelines', (t) async {
      final handle = t.ensureSemantics();
      await openChanting(t, dark: dark, id: spVandanaId);
      await expectGuidelines(t);
      handle.dispose();
    });
    testWidgets('the Vandana with Follow the chanting showing ($theme) meets '
        'the guidelines', (t) async {
      final handle = t.ensureSemantics();
      await openChanting(t, dark: dark, pausedFollowing: true, id: spVandanaId);
      await expectGuidelines(t);
      final pill = find.byKey(const ValueKey('follow-chanting'));
      expect(t.getSize(pill).height, greaterThanOrEqualTo(48));
      expect(t.getSize(pill).width, greaterThanOrEqualTo(48));
      handle.dispose();
    });
    testWidgets('a unit of the Vandana that is tappable once chanting starts '
        'is at least 48 high ($theme)', (t) async {
      await openChanting(t, dark: dark, id: spVandanaId);
      final blocks = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('block-u-'),
      );
      expect(blocks, findsWidgets);
      for (final e in blocks.evaluate()) {
        expect(t.getSize(find.byElementPredicate((x) => x == e)).height,
            greaterThanOrEqualTo(48),
            reason: '${e.widget.key}');
      }
    });
  }

  // Pirith: the same guidelines on its screens, in both themes.
  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('Library with Pirith open ($theme) meets the guidelines', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.category(pirithCategoryId), size: const Size(390, 1800), dark: dark);
      expect(find.byKey(const ValueKey('pirith-row-$mangalaReadingId')), findsOneWidget);
      await expectGuidelines(t);
      handle.dispose();
    });
    testWidgets('a pirith in the reader, silent ($theme), meets the guidelines', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.reader(mangalaReadingId), dark: dark);
      await expectGuidelines(t);
      handle.dispose();
    });
    testWidgets('a pirith chanting with a phrase highlighted ($theme) meets the guidelines', (t) async {
      final handle = t.ensureSemantics();
      await openChanting(t, dark: dark);
      await expectGuidelines(t);
      handle.dispose();
    });
    testWidgets('a pirith with Follow the chanting showing ($theme) meets the guidelines', (t) async {
      final handle = t.ensureSemantics();
      await openChanting(t, dark: dark, pausedFollowing: true);
      await expectGuidelines(t);
      final pill = find.byKey(const ValueKey('follow-chanting'));
      expect(t.getSize(pill).height, greaterThanOrEqualTo(48));
      expect(t.getSize(pill).width, greaterThanOrEqualTo(48));
      handle.dispose();
    });
    testWidgets('a block that is tappable once chanting starts is at least 48 high ($theme)', (t) async {
      await openChanting(t, dark: dark);
      final blocks = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('block-') &&
            w.key != const ValueKey('block-active'),
      );
      expect(blocks, findsWidgets);
      for (final e in blocks.evaluate()) {
        expect(t.getSize(find.byElementPredicate((x) => x == e)).height,
            greaterThanOrEqualTo(48),
            reason: '${e.widget.key}');
      }
    });
  }
}
