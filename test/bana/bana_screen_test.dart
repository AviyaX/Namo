import 'dart:convert';

import 'package:buddhist_gatha/bana/bana_progress.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../quality/quality_support.dart';
import 'bana_support.dart';

Finder _nav(String l) => find.byKey(ValueKey('nav-${l.toLowerCase()}'));
Finder _k(String k) => find.byKey(ValueKey(k));

String _location(WidgetTester t) => GoRouter.of(
  t.element(_nav('Home')),
).routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  testWidgets('the bar has five tabs in order with Bana third', (t) async {
    await openReal(t, Routes.home, overrides: banaOverrides());
    final labels = ['Home', 'Library', 'Bana', 'Tripitaka', 'Settings'];
    final xs = [for (final l in labels) t.getCenter(_nav(l)).dx];
    expect(xs, orderedEquals([...xs]..sort()));
    await t.tap(_nav('Bana'));
    await t.pumpAndSettle();
    expect(_k('screen-bana'), findsOneWidget);
    expect(_location(t), Routes.bana);
  });

  testWidgets('existing tabs still open by address', (t) async {
    for (final (path, screen) in [
      ('/tipitaka', 'screen-tripitaka'),
      ('/settings/saved', 'screen-saved'),
      ('/settings', 'screen-settings'),
    ]) {
      await openReal(t, path, overrides: banaOverrides());
      expect(_k(screen), findsOneWidget, reason: path);
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('/bana shows series first then bana', (t) async {
    await openReal(t, '/bana', overrides: banaOverrides());
    expect(find.text('බණ · Bana'), findsOneWidget);
    expect(find.text('5 bana · 2 venerable speakers'), findsOneWidget);
    expect(find.text('Search bana'), findsOneWidget);
    expect(find.text('All speakers'), findsOneWidget);
    expect(find.text('SERIES · 3 PARTS'), findsOneWidget);
    expect(find.text('Start: part 1'), findsOneWidget);
    final series = t.getTopLeft(_k('bana-series-s1')).dy;
    final single = t.getTopLeft(_k('bana-tile-x1')).dy;
    expect(series, lessThan(single));
    expect(_k('bana-tile-v1'), findsNothing);
    expect(_k('bana-tile-x2'), findsOneWidget);
  });

  testWidgets('picking a monk hides topics he has no bana in', (t) async {
    await openReal(t, '/bana', overrides: banaOverrides());
    await t.tap(_k('bana-topic-K'));
    await t.pumpAndSettle();
    expect(_k('bana-tile-x2'), findsOneWidget);
    expect(_k('bana-tile-x1'), findsNothing);
    await t.ensureVisible(_k('bana-speaker-a'));
    await t.tap(_k('bana-speaker-a'));
    await t.pumpAndSettle();
    // K has nothing by Alpha: the chip is gone and the topic is All again.
    expect(_k('bana-topic-K'), findsNothing);
    expect(_k('bana-topic-M'), findsOneWidget);
    expect(_k('bana-tile-x1'), findsOneWidget);
    expect(_k('bana-tile-x2'), findsNothing);
  });

  testWidgets('a topic shows its series card and its bana', (t) async {
    await openReal(t, '/bana', overrides: banaOverrides());
    await t.tap(_k('bana-topic-M'));
    await t.pumpAndSettle();
    expect(_k('bana-series-s1'), findsOneWidget);
    expect(_k('bana-tile-x1'), findsOneWidget);
    expect(_k('bana-tile-x2'), findsNothing);
  });

  testWidgets('the topic chip speaks its English name', (t) async {
    final h = t.ensureSemantics();
    await openReal(t, '/bana', overrides: banaOverrides());
    expect(
      t.getSemantics(_k('bana-topic-M')).getSemanticsData().label,
      'Meditation',
    );
    h.dispose();
  });

  testWidgets('search finds a series part and opening it goes to its '
      'player route', (t) async {
    await openReal(t, '/bana', overrides: banaOverrides());
    await t.enterText(
      find.descendant(of: _k('bana-search'), matching: find.byType(TextField)),
      'part 2',
    );
    await t.pumpAndSettle();
    expect(_k('bana-series-s1'), findsNothing);
    expect(_k('bana-tile-v2'), findsOneWidget);
    await t.tap(_k('bana-tile-v2'));
    await t.pumpAndSettle();
    expect(_location(t), Routes.banaPlay('v2'));
  });

  testWidgets('the series card opens the series route', (t) async {
    await openReal(t, '/bana', overrides: banaOverrides());
    await t.tap(_k('bana-series-s1'));
    await t.pumpAndSettle();
    expect(_location(t), Routes.banaSeries('s1'));
  });

  testWidgets('series card shows Continue when a part was opened', (t) async {
    await openReal(
      t,
      '/bana',
      overrides: banaOverrides(),
      storeExtras: {banaLastPartKey: jsonEncode({'s1': 'v2'})},
    );
    expect(find.text('Continue: part 2'), findsOneWidget);
    expect(find.text('Start: part 1'), findsNothing);
  });

  testWidgets('pressing the Bana tab again clears filters', (t) async {
    await openReal(t, '/bana', overrides: banaOverrides());
    await t.ensureVisible(_k('bana-speaker-b'));
    await t.tap(_k('bana-speaker-b'));
    await t.pumpAndSettle();
    await t.enterText(
      find.descendant(of: _k('bana-search'), matching: find.byType(TextField)),
      'Beta',
    );
    await t.pumpAndSettle();
    expect(_k('bana-series-s1'), findsNothing);
    await t.tap(_nav('Bana'));
    await t.pumpAndSettle();
    expect(_k('bana-series-s1'), findsOneWidget);
    expect(_k('bana-tile-x1'), findsOneWidget);
    expect(
      t
          .widget<TextField>(
            find.descendant(
              of: _k('bana-search'),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      isEmpty,
    );
  });
}
