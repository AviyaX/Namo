import 'dart:math' as math;

import 'package:buddhist_gatha/design/widgets/floating_bar.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../quality/quality_support.dart';

const _labels = ['Home', 'Library', 'Saved', 'Settings'];

Finder _nav(String label) => find.byKey(ValueKey('nav-${label.toLowerCase()}'));
Finder _screen(String label) =>
    find.byKey(ValueKey('screen-${label.toLowerCase()}'));
Finder get _bar => find.byType(FloatingBar);

/// The vertical scroll view of the tab named [label].
Finder _scrollable(String label) => find
    .descendant(of: _screen(label), matching: find.byType(Scrollable))
    .first;

/// The lowest bottom edge of anything laid out in the list of [scrollable].
double _contentBottom(WidgetTester t, Finder scrollable) {
  final list = find
      .descendant(
        of: scrollable,
        matching: find.byWidgetPredicate((w) => w is SliverMultiBoxAdaptorWidget),
      )
      .first;
  final sliver = list.evaluate().single.renderObject!;
  // Only what the list itself lays out: not a slider's value bubble, which
  // is built inside the list but shown in the overlay.
  bool inList(RenderObject r) {
    for (RenderObject? o = r; o != null; o = o.parent) {
      if (o == sliver) return true;
    }
    return false;
  }

  var bottom = double.negativeInfinity;
  for (final e in find
      .descendant(of: list, matching: find.byWidgetPredicate((_) => true))
      .evaluate()) {
    final r = e.renderObject;
    if (r is RenderBox && r.attached && r.hasSize && inList(r)) {
      bottom = math.max(bottom, r.localToGlobal(Offset(0, r.size.height)).dy);
    }
  }
  return bottom;
}

Future<void> _go(WidgetTester t, String label) async {
  await t.tap(_nav(label));
  await t.pumpAndSettle();
}

// Every test starts the app with openReal (pumpApp with the bundled content
// read once, outside the fake clock). Mixing in pumpApp's own content load
// leaves a cached asset future from a finished test that never completes.
void main() {
  group('phone: floating bar', () {
    testWidgets('four destinations in order, each 48 x 48, the bar 16 from the sides',
        (t) async {
      await openReal(t, Routes.home);
      final xs = <double>[];
      for (final l in _labels) {
        expect(_nav(l), findsOneWidget, reason: l);
        expect(
          find.descendant(of: _nav(l), matching: find.text(l)),
          findsOneWidget,
          reason: l,
        );
        final size = t.getSize(_nav(l));
        expect(size.width, greaterThanOrEqualTo(48), reason: l);
        expect(size.height, greaterThanOrEqualTo(48), reason: l);
        xs.add(t.getCenter(_nav(l)).dx);
      }
      expect(xs, orderedEquals([...xs]..sort()));
      expect(_bar, findsOneWidget);
      final bar = t.getRect(_bar);
      expect(bar.left, 16);
      expect(bar.right, 390 - 16);
      expect(bar.bottom, 844 - 12);
      expect(bar.height, greaterThanOrEqualTo(64));
      for (final l in _labels) {
        expect(t.getRect(_nav(l)).top, greaterThanOrEqualTo(bar.top), reason: l);
      }
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('the bar sits 12 above the bottom safe area', (t) async {
      t.view.padding = const FakeViewPadding(bottom: 34);
      t.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(t.view.resetPadding);
      addTearDown(t.view.resetViewPadding);
      await openReal(t, Routes.home);
      expect(t.getRect(_bar).bottom, 844 - 34 - 12);
    });

    testWidgets('the active destination is selected and its icon filled', (t) async {
      final h = t.ensureSemantics();
      await openReal(t, Routes.home);
      for (final active in ['Home', 'Saved']) {
        if (active != 'Home') await _go(t, active);
        for (final l in _labels) {
          final data = t.getSemantics(_nav(l)).getSemanticsData();
          expect(data.label, l);
          expect(data.flagsCollection.isButton, isTrue, reason: l);
          expect(data.flagsCollection.isSelected.toBoolOrNull(), l == active,
              reason: '$l with $active active');
          final icon = t.widget<Icon>(
            find.descendant(of: _nav(l), matching: find.byType(Icon)),
          );
          expect(icon.fill, l == active ? 1 : 0, reason: '$l with $active active');
          expect(icon.weight, 300);
          expect(icon.size, 24);
        }
      }
      h.dispose();
    });

    testWidgets('icons are the ones the tabs had', (t) async {
      await openReal(t, Routes.home);
      const icons = [
        Symbols.home_rounded,
        Symbols.menu_book_rounded,
        Symbols.bookmark_rounded,
        Symbols.settings_rounded,
      ];
      for (var i = 0; i < 4; i++) {
        expect(
          find.descendant(of: _nav(_labels[i]), matching: find.byIcon(icons[i])),
          findsOneWidget,
        );
      }
    });

    testWidgets('tapping a destination shows its tab', (t) async {
      await openReal(t, Routes.home);
      await _go(t, 'Library');
      expect(_screen('Library'), findsOneWidget);
      expect(_screen('Home'), findsNothing);
    });

    testWidgets('each tab keeps its scroll position and open card when away',
        (t) async {
      await openReal(t, Routes.library);
      final lib = await realLibrary(t);
      final category = lib.categories.first;
      await t.tap(find.text(category.title));
      await t.pumpAndSettle();
      expect(find.byKey(ValueKey('open-${category.id}')), findsOneWidget);

      await _go(t, 'Settings');
      final position = t.state<ScrollableState>(_scrollable('Settings')).position;
      position.jumpTo(200);
      await t.pump();

      await _go(t, 'Home');
      expect(_screen('Settings'), findsNothing);
      await _go(t, 'Settings');
      expect(
        t.state<ScrollableState>(_scrollable('Settings')).position.pixels,
        200,
      );
      await _go(t, 'Library');
      expect(find.byKey(ValueKey('open-${category.id}')), findsOneWidget);
    });

    testWidgets('pressing the active tab returns it to its first page', (t) async {
      await openReal(t, Routes.sources);
      expect(find.byKey(const ValueKey('screen-sources')), findsOneWidget);
      await _go(t, 'Settings');
      expect(_screen('Settings'), findsOneWidget);
      expect(find.byKey(const ValueKey('screen-sources')), findsNothing);
    });
  });

  group('wide: side rail', () {
    for (final size in const [Size(840, 600), Size(1280, 800), Size(844, 390)]) {
      testWidgets('at ${size.width.round()} x ${size.height.round()} the '
          'destinations stand in a rail at the left', (t) async {
        await openReal(t, Routes.home, size: size);
        final rects = [for (final l in _labels) t.getRect(_nav(l))];
        for (var i = 0; i < 4; i++) {
          expect(rects[i].left, rects[0].left, reason: _labels[i]);
          expect(rects[i].right, lessThanOrEqualTo(88), reason: _labels[i]);
          expect(rects[i].width, greaterThanOrEqualTo(48), reason: _labels[i]);
          expect(rects[i].height, greaterThanOrEqualTo(48), reason: _labels[i]);
          if (i > 0) {
            expect(rects[i].top - rects[i - 1].bottom, 8, reason: _labels[i]);
          }
        }
        final rail = t.getRect(find.byKey(const ValueKey('nav-rail')));
        expect(rail.left, 0);
        expect(rail.width, 88);
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
        expect(_bar, findsNothing);
      });
    }
  });

  group('content clears the bar', () {
    for (final size in const [Size(390, 844), Size(320, 568)]) {
      for (final l in _labels) {
        testWidgets('$l at ${size.width.round()} x ${size.height.round()}: '
            'the end of the page scrolls above the bar', (t) async {
          await openReal(t, Routes.home, size: size, withSaved: true);
          if (l != 'Home') await _go(t, l);
          final position = t.state<ScrollableState>(_scrollable(l)).position;
          // A lazy list only knows its true length once it has laid out its
          // end, so go on jumping until the end stays put.
          do {
            position.jumpTo(position.maxScrollExtent);
            await t.pumpAndSettle();
          } while (position.pixels < position.maxScrollExtent);
          expect(
            _contentBottom(t, _scrollable(l)),
            lessThanOrEqualTo(t.getRect(_bar).top),
          );
        });
      }
    }

    // Sources is a page inside the Settings tab, so the bar floats over it
    // too. Its content is one column in a scroll view.
    final sources = find.byKey(const ValueKey('screen-sources'));
    final sourcesScroll = find
        .descendant(of: sources, matching: find.byType(Scrollable))
        .first;
    Finder sourcesContent() => find
        .descendant(
          of: find.descendant(
            of: sources,
            matching: find.byType(SingleChildScrollView),
          ),
          matching: find.byType(Column),
        )
        .first;
    Future<void> toEnd(WidgetTester t) async {
      final position = t.state<ScrollableState>(sourcesScroll).position;
      position.jumpTo(position.maxScrollExtent);
      await t.pumpAndSettle();
    }

    for (final size in const [Size(390, 844), Size(320, 568)]) {
      testWidgets('Sources at ${size.width.round()} x ${size.height.round()}: '
          'the end of the page scrolls above the bar', (t) async {
        await openReal(t, Routes.sources, size: size);
        await toEnd(t);
        final barTop = t.getRect(find.byKey(const ValueKey('nav-bar'))).top;
        expect(barTop, t.getRect(_bar).top);
        expect(t.getRect(sourcesContent()).bottom, lessThanOrEqualTo(barTop));
      });
    }

    for (final size in const [Size(840, 600), Size(1280, 800)]) {
      testWidgets('Sources at ${size.width.round()} x ${size.height.round()}: '
          'beside the rail the page ends 16 above the screen edge', (t) async {
        await openReal(t, Routes.sources, size: size);
        expect(find.byKey(const ValueKey('nav-rail')), findsOneWidget);
        expect(find.byKey(const ValueKey('nav-bar')), findsNothing);
        await toEnd(t);
        expect(t.getRect(sourcesContent()).bottom, size.height - 16);
      });
    }
  });

  group('large text on a small phone', () {
    setUpAll(loadBundledFonts);

    for (final dark in [false, true]) {
      testWidgets('320 x 568 at 2.0x text (${dark ? 'dark' : 'light'}): no overflow, '
          'every label whole and readable', (t) async {
        await openReal(t, Routes.home,
            size: const Size(320, 568), deviceTextScale: 2, dark: dark);
        expect(t.takeException(), isNull);
        final bar = t.getRect(_bar);
        for (final l in _labels) {
          final label = find.descendant(of: _nav(l), matching: find.text(l));
          final text = t.widget<Text>(label);
          expect(text.overflow, isNot(anyOf(TextOverflow.ellipsis, TextOverflow.clip, TextOverflow.fade)));
          expect(text.maxLines, isNull, reason: l);
          final paragraph = t.renderObject<RenderParagraph>(label);
          expect(paragraph.didExceedMaxLines, isFalse, reason: l);
          // One word, so one line: not broken in the middle.
          final lines = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: l.length),
          ).map((b) => b.top).toSet();
          expect(lines, hasLength(1), reason: '$l is broken across lines');
          // Never smaller than the 12 px it has at 1.0x.
          expect(paragraph.textScaler.scale(12), greaterThanOrEqualTo(12), reason: l);
          final rect = t.getRect(label);
          final dest = t.getRect(_nav(l));
          expect(rect.left, greaterThanOrEqualTo(dest.left), reason: l);
          expect(rect.right, lessThanOrEqualTo(dest.right), reason: l);
          expect(rect.top, greaterThanOrEqualTo(dest.top), reason: l);
          expect(rect.bottom, lessThanOrEqualTo(dest.bottom), reason: l);
          expect(dest.top, greaterThanOrEqualTo(bar.top), reason: l);
          expect(dest.bottom, lessThanOrEqualTo(bar.bottom), reason: l);
        }
      });
    }

    testWidgets('the labels grow with the text size', (t) async {
      await openReal(t, Routes.home, size: const Size(390, 844), deviceTextScale: 1.3);
      final paragraph = t.renderObject<RenderParagraph>(
        find.descendant(of: _nav('Home'), matching: find.text('Home')),
      );
      expect(paragraph.textScaler.scale(12), greaterThan(12));
    });
  });
}
