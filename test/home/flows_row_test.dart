import 'dart:convert';

import 'package:buddhist_gatha/flows/flows.dart';
import 'package:buddhist_gatha/home/flows_row.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_test/flutter_test.dart';

import '../flows/flow_test_support.dart';
import '../quality/quality_support.dart';

const _row = ValueKey('home-flows');

Finder _card(String id) => find.byKey(ValueKey('home-flow-$id'));

void main() {
  setUpAll(loadBundledFonts);

  final a = ref('r1', 's01'), b = ref('r1', 's02');

  testWidgets('no flows: no "Your flows" and no row', (t) async {
    await openFlows(t, Routes.home, {});
    expect(find.text('Your flows'), findsNothing);
    expect(find.byKey(_row), findsNothing);
    expect(find.byType(FlowsRow), findsNothing);
  });

  testWidgets('one card per flow in creation order, with the count of the '
      'sections the content has; an empty flow is listed too', (t) async {
    await openFlows(t, Routes.home, {
      'flow-1': [a],
      'flow-2': [a, b, ref('r1', 'gone')],
      'flow-3': [],
    });
    expect(find.text('Your flows'), findsOneWidget);
    expect(find.byKey(_row), findsOneWidget);
    for (final (id, name, count) in [
      ('flow-1', 'Flow 1', '1 section'),
      ('flow-2', 'Flow 2', '2 sections'),
      ('flow-3', 'Flow 3', '0 sections'),
    ]) {
      final card = _card(id);
      expect(card, findsOneWidget, reason: id);
      expect(
        find.descendant(of: card, matching: find.text(name)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(count)),
        findsOneWidget,
      );
    }
    expect(
      t.getTopLeft(_card('flow-1')).dx,
      lessThan(t.getTopLeft(_card('flow-2')).dx),
    );
    expect(
      t.getTopLeft(_card('flow-2')).dx,
      lessThan(t.getTopLeft(_card('flow-3')).dx),
    );
    // Under the label.
    expect(
      t.getTopLeft(_card('flow-1')).dy,
      greaterThan(t.getTopLeft(find.text('Your flows')).dy),
    );
  });

  testWidgets('a card opens the flow in the reader from Home', (t) async {
    final c = await openFlows(t, Routes.home, {
      'flow-1': [a],
      'flow-2': [a, b],
    });
    await t.ensureVisible(_card('flow-2'));
    await t.pumpAndSettle();
    await t.tap(_card('flow-2'));
    await t.pumpAndSettle();
    expect(location(c), '/read/flow-2?from=home');
    expect(find.byKey(const ValueKey('heading-r1~s02')), findsOneWidget);
  });

  testWidgets('an empty flow opens the reader\'s empty state', (t) async {
    final c = await openFlows(t, Routes.home, {'flow-1': []});
    await t.ensureVisible(_card('flow-1'));
    await t.pumpAndSettle();
    await t.tap(_card('flow-1'));
    await t.pumpAndSettle();
    expect(location(c), '/read/flow-1?from=home');
    expect(find.text('This flow has no sections yet.'), findsOneWidget);
  });

  testWidgets('a card is one button "<name>, <count>", at least 48 tall', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await openFlows(t, Routes.home, {
      'flow-1': [a, b],
      'flow-2': [],
    });
    for (final label in ['Flow 1, 2 sections', 'Flow 2, 0 sections']) {
      final node = find.bySemanticsLabel(label);
      expect(node, findsOneWidget, reason: label);
      expect(
        t.getSemantics(node).getSemanticsData().flagsCollection.isButton,
        isTrue,
      );
    }
    for (final id in ['flow-1', 'flow-2']) {
      final size = t.getSize(_card(id));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    }
    handle.dispose();
  });

  testWidgets('a long name is kept to two lines with an ellipsis', (t) async {
    await openFlows(t, Routes.home, {'flow-1': [a]});
    final name = t.widget<Text>(
      find.descendant(of: _card('flow-1'), matching: find.text('Flow 1')),
    );
    expect(name.maxLines, 2);
    expect(name.overflow, TextOverflow.ellipsis);
  });

  group('no overflow with a 40-character name', () {
    final long = '${'W' * 20} ${'m' * 19}';
    assert(long.length == 40);
    final stored = jsonEncode(
      FlowsState(
        flows: [
          Flow(id: 'flow-1', name: long, sections: [a, b]),
          Flow(id: 'flow-2', name: long, sections: const []),
        ],
        nextNumber: 3,
      ).toJson(),
    );
    final cases = <(Size, double)>[
      (const Size(320, 568), 2.0),
      for (final w in [840.0, 1280.0])
        for (final s in [1.0, 1.5]) (Size(w, 800), s),
    ];
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      for (final (size, scale) in cases) {
        testWidgets('${size.width.round()} x ${size.height.round()}, text '
            '$scale, ${theme.name}', (t) async {
          await openReal(
            t,
            Routes.home,
            size: size,
            deviceTextScale: scale,
            library: flowTestLibrary(),
            settings: AppSettings(themeMode: theme),
            storeExtras: {flowsKey: stored},
          );
          expect(_card('flow-1'), findsOneWidget);
          await scrollThrough(t);
          await t.ensureVisible(_card('flow-2'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          expect(t.getSize(_card('flow-1')).height, greaterThanOrEqualTo(48));
        });
      }
    }
  });
}
