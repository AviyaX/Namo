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
    ('Home', Routes.home, const Size(390, 844), null, false),
    ('Library (closed)', Routes.library, const Size(390, 844), null, false),
    ('Library (open)', Routes.category(realCategoryId), const Size(390, 1800), null, false),
    ('Reader', Routes.reader(realReadingId), const Size(390, 844), null, false),
    ('Reader sheet', Routes.reader(realReadingId), const Size(390, 844), openSheet, false),
    ('Saved', Routes.saved, const Size(390, 844), null, true),
    ('Settings', Routes.settings, const Size(390, 1400), null, false),
    ('Sources', Routes.sources, const Size(390, 6000), null, false),
  ];

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
      final bar = find.byType(NavigationBar);
      expect(bar, findsOneWidget);
      expect(t.getSize(bar).height, greaterThanOrEqualTo(48));
      for (final tab in tabs) {
        final destination = find.ancestor(
          of: find.text(tab),
          matching: find.byType(NavigationDestination),
        );
        expect(t.getSize(destination).height, greaterThanOrEqualTo(48), reason: tab);
        expect(t.getSize(destination).width, greaterThanOrEqualTo(48), reason: tab);
      }
      expect(find.byType(NavigationRail), findsNothing);
      handle.dispose();
    });

    testWidgets('the rail has the four tabs, each labelled and at least 48 x 48', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.home, size: const Size(1280, 800));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
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
      final rail = find.byType(NavigationRail);
      expect(t.getTopLeft(rail).dx, greaterThanOrEqualTo(44));
    });

    testWidgets('the rail meets the guidelines on a wide screen', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.home, size: const Size(1280, 800));
      await expectGuidelines(t);
      handle.dispose();
    });
  });
}
