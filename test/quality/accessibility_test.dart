import 'dart:convert';

import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/floating_bar.dart';
import 'package:buddhist_gatha/home/featured_carousel.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

/// Home scrolls, so it is checked on a tall surface; this makes sure that
/// surface still holds every block, down to Collections, clear of the bar.
Future<void> expectWholeHome(WidgetTester t) async {
  final last = t.getRect(find.byKey(const ValueKey('home-collections')));
  expect(last.bottom, lessThanOrEqualTo(t.getRect(find.byType(FloatingBar)).top));
}

void main() {
  // The test font is used here, not the bundled ones: the contrast check
  // reads the most common dark pixel, and the thin strokes of a real font at
  // 14-16 px are mostly anti-aliasing, which reads as a paler colour than the
  // text really is. Glyph shapes do not change a colour's contrast.

  // Each screen, with the surface it is checked on (tall where the page
  // scrolls, so everything is on screen) and what to do once it is open.
  final screens = <(String, String, Size, Future<void> Function(WidgetTester)?, bool)>[
    ('Home', Routes.home, const Size(390, 2600), expectWholeHome, false),
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
    for (final size in const [Size(390, 2600), Size(1280, 800)]) {
      testWidgets(
        'Home with several reading cards (${dark ? 'dark' : 'light'}, ${size.width.round()}x${size.height.round()}) '
        'meets tap-target, label and contrast guidelines',
        (t) async {
          final handle = t.ensureSemantics();
          await openReal(t, Routes.home, size: size, dark: dark, library: severalCategories());
          // The featured page and the four Collections cards.
          expect(find.byKey(const ValueKey('card-art-panel')), findsNWidgets(5));
          if (size.width < 840) await expectWholeHome(t);
          await expectGuidelines(t);
          handle.dispose();
        },
      );
    }
  }

  // Home's controls are all at least 48 px, the carousel can be moved from a
  // screen reader, and the screen reader meets the blocks top to bottom.
  for (final size in const [Size(320, 2800), Size(412, 2600)]) {
    testWidgets('Home controls are 48 px or more, ${size.width.round()} wide', (t) async {
      await openReal(t, Routes.home, size: size);
      final keys = [
        'home-search',
        'gatha-bookmark',
        for (final id in ['s01', 's02', 's03', 's04']) 'quick-$id',
      ];
      for (final k in keys) {
        final box = t.getSize(find.byKey(ValueKey(k)));
        expect(box.width, greaterThanOrEqualTo(48), reason: k);
        expect(box.height, greaterThanOrEqualTo(48), reason: k);
      }
    });
  }

  testWidgets('Home: the carousel offers increase and decrease to a screen reader', (t) async {
    final handle = t.ensureSemantics();
    await openReal(t, Routes.home, size: const Size(390, 2600));
    SemanticsNode node() =>
        t.getSemantics(find.bySemanticsLabel('Featured collections'));
    expect(node().getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
    expect(node().getSemanticsData().hasAction(SemanticsAction.decrease), isFalse);
    node().owner!.performAction(node().id, SemanticsAction.increase);
    await t.pumpAndSettle();
    expect(node().value, 'Page 2 of 3');
    expect(node().getSemanticsData().hasAction(SemanticsAction.decrease), isTrue);
    node().owner!.performAction(node().id, SemanticsAction.decrease);
    await t.pumpAndSettle();
    expect(node().value, 'Page 1 of 3');
    handle.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('Home: screen reader order is the visual order (${dark ? 'dark' : 'light'})', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.home, size: const Size(390, 2600), dark: dark);
      // What each node says (its label, or its tooltip when it has none), in
      // traversal order.
      final spoken = <String>[];
      void walk(SemanticsNode n) {
        final data = n.getSemanticsData();
        spoken.add(data.label.isNotEmpty ? data.label : data.tooltip);
        for (final c in n.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)) {
          walk(c);
        }
      }

      walk(t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
      // Each block, with the words that identify it to a screen reader and
      // where it is drawn.
      final blocks = <(String, String, Finder)>[
        ('search', 'Search the library', find.byKey(const ValueKey('home-search'))),
        ('featured', 'Featured collections', find.byType(FeaturedCarousel)),
        ('bookmark', 'Bookmark this section', find.byKey(const ValueKey('gatha-bookmark'))),
        ('read in context', 'Read in context', find.text('Read in context')),
        for (final (id, label) in [
          ('s01', 'Namaskara'),
          ('s02', 'Tisarana'),
          ('s03', 'Pancha Sila'),
          ('s04', 'Buddha Guna'),
        ])
          ('quick $id', label, find.byKey(ValueKey('quick-$id'))),
        ('collections', 'Buddha Wandanawa, ', find.byKey(const ValueKey('collection-$realCategoryId'))),
      ];
      var from = 0;
      Rect? before;
      for (final (name, words, finder) in blocks) {
        final index = spoken.indexWhere((w) => w.startsWith(words), from);
        expect(index, isNonNegative, reason: '$name is read after the one above');
        from = index + 1;
        final rect = t.getRect(finder);
        if (before != null) {
          expect(
            rect.top >= before.bottom - 1 || rect.left >= before.right - 1,
            isTrue,
            reason: '$name is drawn after the one before it',
          );
        }
        before = rect;
      }
      handle.dispose();
    });
  }

  testWidgets('the reader with a recording meets the guidelines', (t) async {
    final handle = t.ensureSemantics();
    await openReal(t, Routes.reader(realReadingId), audio: true);
    expect(find.text('Development placeholder tone (not a chant)'), findsOneWidget);
    await expectGuidelines(t);
    handle.dispose();
  });

  group('bottom bar and navigation rail', () {
    const tabs = ['Home', 'Library', 'Tripitaka', 'Saved', 'Settings'];

    testWidgets('the bottom bar has the five tabs, each labelled and 48 high', (t) async {
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

    testWidgets('the rail has the five tabs, each labelled and at least 48 x 48', (t) async {
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
    ('Home with Your flows', Routes.home, const Size(390, 2800), 'Your flows', expectWholeHome),
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
          size: const Size(390, 2800),
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
        await expectWholeHome(t);
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

  // The Tripitaka (the made-up fixture): the same guidelines on its first
  // page, a list page, the reader in each view and the footnotes sheet, in
  // both themes; and the names a screen reader hears for its tab, path,
  // rows, language switch and footnote marks.
  Future<void> openFootnotes(WidgetTester t) async {
    await t.tap(find.bySemanticsLabel('Footnote 1').first);
    await t.pumpAndSettle();
    expect(find.text('Footnotes'), findsOneWidget);
  }

  final tipitakaScreens = <(String, String, Map<String, String>, Future<void> Function(WidgetTester)?)>[
    ('Tripitaka first page', Routes.tipitaka, const {}, null),
    ('Tripitaka list', Routes.tipitakaNode('vp-2'), const {}, null),
    for (final view in TipitakaView.values)
      (
        'Tripitaka reader (${view.name})',
        Routes.tipitakaReader('vp-1-1'),
        {tipitakaViewKey: jsonEncode(view.name)},
        null,
      ),
    ('Tripitaka footnotes sheet', Routes.tipitakaReader('vp-1-1'), const {}, openFootnotes),
  ];
  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    for (final (name, location, extras, after) in tipitakaScreens) {
      testWidgets('$name ($theme) meets tap-target, label and contrast '
          'guidelines', (t) async {
        final handle = t.ensureSemantics();
        await openReal(t, location, size: const Size(390, 1400), dark: dark, storeExtras: extras);
        if (after != null) await after(t);
        await expectGuidelines(t);
        handle.dispose();
      });
    }
  }

  group('Tripitaka names for a screen reader', () {
    testWidgets('the tab', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.tipitaka);
      final tab = find.byKey(const ValueKey('nav-tripitaka'));
      expect(t.getSemantics(tab).label, startsWith('Tripitaka'));
      expect(t.getSize(tab).height, greaterThanOrEqualTo(48));
      handle.dispose();
    });

    testWidgets('the pitaka cards', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.tipitaka, size: const Size(390, 1400));
      expect(find.bySemanticsLabel(RegExp(r'^S vp, Vinaya Pitaka, \d+ texts?$')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the path, the rows and their parts', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.tipitakaNode('vp-2'), size: const Size(390, 1400));
      expect(find.bySemanticsLabel('Path'), findsOneWidget);
      for (final part in ['Tripitaka', 'S vp']) {
        final node = t.getSemantics(find.descendant(
          of: find.byKey(const ValueKey('tipitaka-breadcrumb')),
          matching: find.bySemanticsLabel(part),
        ));
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue, reason: part);
        expect(node.rect.height, greaterThanOrEqualTo(48), reason: part);
      }
      expect(find.bySemanticsLabel('S two, Opening text'), findsOneWidget);
      for (final row in ['S two one', 'S two two', 'S ten']) {
        final node = t.getSemantics(find.bySemanticsLabel(row));
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue, reason: row);
        expect(node.rect.height, greaterThanOrEqualTo(48), reason: row);
      }
      handle.dispose();
    });

    testWidgets('the language switch and the footnote marks', (t) async {
      final handle = t.ensureSemantics();
      await openReal(
        t,
        Routes.tipitakaReader('vp-1-1'),
        size: const Size(390, 1400),
        storeExtras: {tipitakaViewKey: jsonEncode('both')},
      );
      expect(find.bySemanticsLabel(RegExp('^Language')), findsWidgets);
      for (final label in ['Both', 'පාලි', 'සිංහල']) {
        expect(find.bySemanticsLabel(RegExp(label)), findsWidgets, reason: label);
      }
      final marks = find.bySemanticsLabel('Footnote 1');
      // The Pali and the Sinhala text both have the mark.
      expect(marks, findsNWidgets(2));
      for (final m in marks.evaluate()) {
        final data = t.getSemantics(find.byElementPredicate((e) => e == m)).getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.flagsCollection.isLink, isTrue);
      }
      handle.dispose();
    });
  });
}
