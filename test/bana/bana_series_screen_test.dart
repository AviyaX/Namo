import 'dart:convert';

import 'package:buddhist_gatha/bana/bana_progress.dart';
import 'package:buddhist_gatha/design/widgets/pressable.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../quality/quality_support.dart';
import 'bana_support.dart';

Finder _k(String k) => find.byKey(ValueKey(k));

String _location(WidgetTester t) =>
    GoRouter.of(t.element(find.byType(Scaffold).first))
        .routerDelegate
        .currentConfiguration
        .last
        .matchedLocation;

Map<String, String> _progress(String video) => {
  banaLastPartKey: jsonEncode({'s1': video}),
};

void main() {
  testWidgets('lists parts in order with numbers', (t) async {
    await openReal(t, Routes.banaSeries('s1'), overrides: banaOverrides());
    expect(find.text('SERIES · 3 PARTS · Topic M'), findsOneWidget);
    expect(find.text('Calm series'), findsOneWidget);
    expect(find.text('Ven. Alpha'), findsOneWidget);
    expect(find.text('From YouTube · Chan'), findsOneWidget);
    final ys = [
      for (final i in ['v1', 'v2', 'v3']) t.getTopLeft(_k('bana-part-$i')).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
    Finder inRow(String text) =>
        find.descendant(of: _k('bana-part-v2'), matching: find.text(text));
    expect(inRow('2'), findsOneWidget);
    expect(inRow('Calm part 2'), findsOneWidget);
    expect(inRow('10:00'), findsOneWidget);
  });

  testWidgets('Start opens part 1', (t) async {
    await openReal(t, Routes.banaSeries('s1'), overrides: banaOverrides());
    expect(find.text('Start: part 1'), findsOneWidget);
    await t.tap(_k('bana-continue'));
    await t.pumpAndSettle();
    expect(_location(t), Routes.banaPlay('v1'));
  });

  testWidgets('Continue opens the last opened part', (t) async {
    await openReal(
      t,
      Routes.banaSeries('s1'),
      overrides: banaOverrides(),
      storeExtras: _progress('v2'),
    );
    expect(find.text('Continue: part 2'), findsOneWidget);
    await t.tap(_k('bana-continue'));
    await t.pumpAndSettle();
    expect(_location(t), Routes.banaPlay('v2'));
  });

  testWidgets('tapping a part opens it', (t) async {
    await openReal(t, Routes.banaSeries('s1'), overrides: banaOverrides());
    await t.tap(_k('bana-part-v3'));
    await t.pumpAndSettle();
    expect(_location(t), Routes.banaPlay('v3'));
  });

  testWidgets('the last opened part is highlighted', (t) async {
    final handle = t.ensureSemantics();
    await openReal(
      t,
      Routes.banaSeries('s1'),
      overrides: banaOverrides(),
      storeExtras: _progress('v2'),
    );
    bool selected(String id) =>
        t
            .getSemantics(
              find.descendant(
                of: _k('bana-part-$id'),
                matching: find.byType(Pressable),
              ),
            )
            .getSemanticsData()
            .flagsCollection
            .isSelected
            .toBoolOrNull() ==
        true;
    expect(selected('v2'), isTrue);
    expect(selected('v1'), isFalse);
    handle.dispose();
  });

  testWidgets('back returns to the Bana list', (t) async {
    await openReal(t, Routes.bana, overrides: banaOverrides());
    await t.tap(_k('bana-series-s1'));
    await t.pumpAndSettle();
    expect(_k('screen-bana-series'), findsOneWidget);
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(_k('screen-bana'), findsOneWidget);
  });

  testWidgets('unknown id shows not found', (t) async {
    await openReal(t, Routes.banaSeries('nope'), overrides: banaOverrides());
    expect(find.text('This page could not be found.'), findsOneWidget);
  });
}
