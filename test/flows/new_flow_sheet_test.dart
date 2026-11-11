import 'dart:ui' as ui;

import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/typography.dart';
import 'package:buddhist_gatha/flows/flows.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import 'flow_test_support.dart';

const _field = ValueKey('flow-name-field');
const _create = ValueKey('new-flow-create');

/// The sheet's list of starting points.
Finder _choices() => find.descendant(
  of: find.byKey(const ValueKey('new-flow-choices')),
  matching: find.byType(Scrollable),
);

Future<void> _openSheet(WidgetTester t) async {
  await t.ensureVisible(find.byKey(const ValueKey('new-flow')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('new-flow')));
  await t.pumpAndSettle();
  expect(find.byType(BottomSheet), findsOneWidget);
}

Future<void> _tapCreate(WidgetTester t) async {
  await t.ensureVisible(find.byKey(_create));
  await t.pumpAndSettle();
  await t.tap(find.byKey(_create));
  await t.pumpAndSettle();
}

/// Scrolls the list of starting points until [key] is built and on screen.
Future<void> _scrollTo(WidgetTester t, String key) async {
  await t.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    100,
    scrollable: _choices(),
  );
  await t.pumpAndSettle();
}

ui.SemanticsFlags _flags(WidgetTester t, String key) => t
    .getSemantics(find.byKey(ValueKey(key)))
    .getSemanticsData()
    .flagsCollection;

bool _checked(WidgetTester t, String key) =>
    _flags(t, key).isChecked == ui.CheckedState.isTrue;

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('shows the title, the name with its hint, "Start from", '
      '"Nothing" chosen, and every reading grouped by category', (t) async {
    await openFlows(t, Routes.library, {});
    await _openSheet(t);
    final sheet = find.byType(BottomSheet);
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    expect(inSheet('New flow'), findsOneWidget);
    expect(inSheet('Name'), findsOneWidget);
    expect(inSheet('Morning'), findsOneWidget);
    expect(inSheet('Start from'), findsOneWidget);
    expect(inSheet('Nothing'), findsOneWidget);
    expect(inSheet('Create'), findsOneWidget);
    final h = t.ensureSemantics();
    expect(_checked(t, 'start-from-nothing'), isTrue);
    expect(_checked(t, 'start-from-r1'), isFalse);
    expect(_flags(t, 'start-from-r1').isInMutuallyExclusiveGroup, isTrue);
    h.dispose();
    // In library order, each reading under its category's title.
    await _scrollTo(t, 'start-from-r3');
    final order = [
      inSheet('category 1'),
      find.byKey(const ValueKey('start-from-r1')),
      inSheet('category 2'),
      find.byKey(const ValueKey('start-from-r2')),
      find.byKey(const ValueKey('start-from-r3')),
    ];
    for (var i = 1; i < order.length; i++) {
      expect(
        t.getTopLeft(order[i - 1]).dy,
        lessThan(t.getTopLeft(order[i]).dy),
        reason: '$i',
      );
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('start-from-r3')),
        matching: find.text('roman 3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('start-from-r2')),
        matching: find.text('reading 2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('"Nothing" is drawn in the English font, the readings in the '
      'Sinhala one', (t) async {
    await openFlows(t, Routes.library, {});
    await _openSheet(t);
    String? family(String key, String text) => t
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.text(text),
          ),
        )
        .style
        ?.fontFamily;
    expect(family('start-from-nothing', 'Nothing'), NamoFonts.english);
    expect(family('start-from-r1', 'reading 1'), NamoFonts.sinhala);
  });

  testWidgets('Create with no name and "Nothing" makes an empty "My flow" '
      'and opens its editor', (t) async {
    final c = await openFlows(t, Routes.library, {});
    await _openSheet(t);
    await _tapCreate(t);
    expect(location(c), '/library/flow/flow-1');
    final flow = savedFlow(c, 'flow-1')!;
    expect(flow.name, 'My flow');
    expect(flow.sections, isEmpty);
    expect(find.byKey(const ValueKey('screen-flow-editor')), findsOneWidget);
    expect(find.text('This flow has no sections yet.'), findsOneWidget);
  });

  testWidgets('a second flow with no name is "My flow 2"', (t) async {
    final c = await openFlows(t, Routes.library, {});
    await _openSheet(t);
    await _tapCreate(t);
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    await _openSheet(t);
    await _tapCreate(t);
    expect(location(c), '/library/flow/flow-2');
    expect(savedFlow(c, 'flow-2')!.name, 'My flow 2');
    expect(c.read(flowsProvider).flows.map((f) => f.name), [
      'My flow',
      'My flow 2',
    ]);
  });

  testWidgets('a typed name is kept, trimmed', (t) async {
    final c = await openFlows(t, Routes.library, {});
    await _openSheet(t);
    await t.enterText(find.byKey(_field), '  Evening  ');
    await t.pump();
    await _tapCreate(t);
    expect(savedFlow(c, 'flow-1')!.name, 'Evening');
  });

  testWidgets('choosing a reading starts the flow with all its sections, in '
      'order', (t) async {
    final c = await openFlows(t, Routes.library, {});
    await _openSheet(t);
    await _scrollTo(t, 'start-from-r2');
    await t.tap(find.byKey(const ValueKey('start-from-r2')));
    await t.pumpAndSettle();
    final h = t.ensureSemantics();
    expect(_checked(t, 'start-from-r2'), isTrue);
    h.dispose();
    await _tapCreate(t);
    expect(savedFlow(c, 'flow-1')!.sections, [ref('r2', 's01'), ref('r2', 's02')]);
    expect(find.text('2 sections'), findsOneWidget);
  });

  testWidgets('choosing "Nothing" again after a reading makes an empty flow',
      (t) async {
    final c = await openFlows(t, Routes.library, {});
    await _openSheet(t);
    await t.tap(find.byKey(const ValueKey('start-from-r1')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('start-from-nothing')));
    await t.pump();
    await _tapCreate(t);
    expect(savedFlow(c, 'flow-1')!.sections, isEmpty);
  });

  testWidgets('a 500-character paste keeps at most 40 characters on one line',
      (t) async {
    final c = await openFlows(t, Routes.library, {});
    await _openSheet(t);
    final long = List.filled(50, 'abcdefghi\n').join();
    expect(long.length, 500);
    await t.enterText(find.byKey(_field), long);
    await t.pump();
    final field = t.widget<TextField>(find.byKey(_field));
    expect(field.controller!.text.length, lessThanOrEqualTo(40));
    await _tapCreate(t);
    final name = savedFlow(c, 'flow-1')!.name;
    expect(name.length, lessThanOrEqualTo(40));
    expect(name, isNot(contains('\n')));
    expect(name, startsWith('abcdefghi'));
  });

  testWidgets('dismissing the sheet creates nothing', (t) async {
    final c = await openFlows(t, Routes.library, {});
    await _openSheet(t);
    await t.enterText(find.byKey(_field), 'Other');
    await t.tap(find.byKey(const ValueKey('start-from-r1')));
    await t.pump();
    await t.tapAt(const Offset(195, 20));
    await t.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(c.read(flowsProvider).flows, isEmpty);
    expect(c.read(flowsProvider).nextNumber, 1);
    expect(location(c), Routes.library);
  });

  testWidgets('the list of readings is built lazily', (t) async {
    final lib = await realLibrary(t);
    await openFlows(t, Routes.library, {}, library: lib);
    await _openSheet(t);
    final last = lib.categories.last.readings.last;
    final key = 'start-from-${last.id}';
    expect(find.byKey(ValueKey(key)), findsNothing);
    await _scrollTo(t, key);
    expect(find.byKey(ValueKey(key)), findsOneWidget);
  });

  group('layout', () {
    const sizes = [
      Size(320, 568),
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 800),
    ];
    for (final size in sizes) {
      for (final scale in [1.0, 2.0]) {
        for (final dark in [false, true]) {
          final name =
              '${size.width.round()}x${size.height.round()}, text ${scale}x, '
              '${dark ? 'dark' : 'light'}';
          testWidgets('the sheet does not overflow: $name', (t) async {
            final Library lib = await realLibrary(t);
            await openFlows(
              t,
              Routes.library,
              {},
              library: lib,
              size: size,
              deviceTextScale: scale,
              dark: dark,
            );
            await _openSheet(t);
            expect(t.takeException(), isNull);
            final nothing = t.getSize(
              find.byKey(const ValueKey('start-from-nothing')),
            );
            expect(nothing.height, greaterThanOrEqualTo(48));
            await t.enterText(find.byKey(_field), 'W' * 40);
            await t.pump();
            expect(t.takeException(), isNull);
            // Through the list of starting points, then the whole sheet.
            for (final scrollable in [_choices(), _sheetScroll()]) {
              final position = t.state<ScrollableState>(scrollable).position;
              while (position.pixels < position.maxScrollExtent) {
                position.jumpTo(
                  (position.pixels + position.viewportDimension).clamp(
                    0.0,
                    position.maxScrollExtent,
                  ),
                );
                await t.pump();
                expect(t.takeException(), isNull);
              }
            }
            final create = t.getSize(find.byKey(_create));
            expect(create.height, greaterThanOrEqualTo(48));
            expect(create.width, greaterThanOrEqualTo(48));
          });
        }
      }
    }
  });
}

/// The scroll view of the whole sheet (the list of starting points scrolls
/// inside it).
Finder _sheetScroll() => find
    .descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable))
    .first;
