import 'dart:convert';

import 'package:buddhist_gatha/design/widgets/not_found.dart';
import 'package:buddhist_gatha/design/widgets/progress_line.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_reader_screen.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_search.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_state.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_tree.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tipitaka_app_support.dart';
import 'tipitaka_support.dart';

Finder _row(String key) => find.byKey(ValueKey('tipitaka-row-$key'));
Finder _own(String key) => find.byKey(ValueKey('tipitaka-row-own-$key'));
final _crumbs = find.byKey(const ValueKey('tipitaka-breadcrumb'));
final _count = RegExp(r'^\d+ texts?$');

double _top(WidgetTester t, Finder f) => t.getTopLeft(f).dy;

/// Scrolls the page to its end in viewport steps; nothing may throw.
Future<void> scrollToEnd(WidgetTester t) async {
  final position = t.state<ScrollableState>(find.byType(Scrollable).first).position;
  while (position.pixels < position.maxScrollExtent) {
    position.jumpTo((position.pixels + position.viewportDimension)
        .clamp(0.0, position.maxScrollExtent));
    await t.pump();
    expect(t.takeException(), isNull, reason: 'at ${position.pixels}');
  }
}

void main() {
  testWidgets('rows are in numeric order', (t) async {
    await openTipitakaApp(t, Routes.tipitakaNode('vp-2'));
    // Inserted as vp-2-10 first in the tree; shown by number.
    final rows = ['vp-2-1', 'vp-2-2', 'vp-2-10'];
    for (final r in rows) {
      expect(_row(r), findsOneWidget, reason: r);
    }
    expect(_top(t, _row('vp-2-1')), lessThan(_top(t, _row('vp-2-2'))));
    expect(_top(t, _row('vp-2-2')), lessThan(_top(t, _row('vp-2-10'))));
    expect(find.descendant(of: _row('vp-2-1'), matching: find.text('S two one')),
        findsOneWidget);
    expect(find.descendant(of: _row('vp-2-1'), matching: find.text('P two one')),
        findsOneWidget);
  });

  testWidgets('parent row shows a count, leaf row does not', (t) async {
    final h = t.ensureSemantics();
    await openTipitakaApp(t, Routes.tipitakaNode('vp'));
    expect(find.descendant(of: _row('vp-1'), matching: find.text('1 text')),
        findsOneWidget);
    expect(find.descendant(of: _row('vp-2'), matching: find.text('4 texts')),
        findsOneWidget);
    expect(find.bySemanticsLabel('S one, 1 text'), findsOneWidget);
    expect(find.bySemanticsLabel('S two, 4 texts'), findsOneWidget);

    await openTipitakaApp(t, Routes.tipitakaNode('vp-1'));
    expect(
      find.descendant(of: _row('vp-1-1'), matching: find.textContaining(_count)),
      findsNothing,
    );
    expect(find.bySemanticsLabel('S one one'), findsOneWidget);
    h.dispose();
  });

  testWidgets('tapping a parent opens its list, a leaf opens the reader',
      (t) async {
    final app = await openTipitakaApp(t, Routes.tipitakaNode('vp'));
    await t.tap(_row('vp-1'));
    await t.pumpAndSettle();
    expect(app.location, Routes.tipitakaNode('vp-1'));
    await t.tap(_row('vp-1-1'));
    await t.pumpAndSettle();
    expect(app.location, Routes.tipitakaReader('vp-1-1'));
    expect(find.byType(TipitakaReaderScreen), findsOneWidget);
  });

  testWidgets('a node with its own text has the Opening text row first and it '
      'opens the reader', (t) async {
    final app = await openTipitakaApp(t, Routes.tipitakaNode('vp-2'));
    expect(_own('vp-2'), findsOneWidget);
    expect(find.descendant(of: _own('vp-2'), matching: find.text('S two')),
        findsOneWidget);
    expect(
      find.descendant(of: _own('vp-2'), matching: find.text('Opening text')),
      findsOneWidget,
    );
    expect(_top(t, _own('vp-2')), lessThan(_top(t, _row('vp-2-1'))));
    // A node without text of its own has no such row.
    app.go(Routes.tipitakaNode('vp-1'));
    await t.pumpAndSettle();
    expect(_own('vp-1'), findsNothing);
    app.go(Routes.tipitakaNode('vp-2'));
    await t.pumpAndSettle();
    await t.tap(_own('vp-2'));
    await t.pumpAndSettle();
    expect(app.location, Routes.tipitakaReader('vp-2'));
  });

  testWidgets('breadcrumb parts navigate', (t) async {
    final h = t.ensureSemantics();
    final app = await openTipitakaApp(t, Routes.tipitakaNode('vp-2'));
    expect(find.bySemanticsLabel('Path'), findsOneWidget);
    expect(find.descendant(of: _crumbs, matching: find.text('Tripitaka')),
        findsOneWidget);
    // The page's own name is its title, not a part of the path.
    expect(find.descendant(of: _crumbs, matching: find.text('S two')),
        findsNothing);
    await t.tap(find.descendant(of: _crumbs, matching: find.text('S vp')));
    await t.pumpAndSettle();
    expect(app.location, Routes.tipitakaNode('vp'));
    await t.tap(find.descendant(of: _crumbs, matching: find.text('Tripitaka')));
    await t.pumpAndSettle();
    expect(app.location, Routes.tipitaka);
    h.dispose();
  });

  testWidgets('Back goes to the parent and from a root to /tipitaka',
      (t) async {
    final app = await openTipitakaApp(t, Routes.tipitakaNode('vp-2'));
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(app.location, Routes.tipitakaNode('vp'));
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(app.location, Routes.tipitaka);
  });

  testWidgets('system Back also goes to the parent', (t) async {
    final app = await openTipitakaApp(t, Routes.tipitakaNode('vp-2'));
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(app.location, Routes.tipitakaNode('vp'));
  });

  testWidgets('works when opened directly by address', (t) async {
    await openTipitakaApp(t, Routes.tipitakaNode('vp-1'));
    expect(find.text('S one'), findsWidgets);
    expect(_row('vp-1-1'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a labelled node shows its English label as the caption',
      (t) async {
    await openTipitakaApp(t, Routes.tipitakaNode('vp'));
    expect(find.text('Vinaya Pitaka'), findsOneWidget);
  });

  testWidgets('unknown key shows not found', (t) async {
    await openTipitakaApp(t, Routes.tipitakaNode('no-such-key'));
    expect(find.byType(NotFoundScreen), findsOneWidget);
  });

  testWidgets('leaf key redirects to the reader', (t) async {
    final app = await openTipitakaApp(t, Routes.tipitakaNode('vp-1-1'));
    expect(app.location, Routes.tipitakaReader('vp-1-1'));
    expect(find.byType(TipitakaReaderScreen), findsOneWidget);
  });

  testWidgets('a leaf with a remembered place shows a progress line',
      (t) async {
    final store = InMemoryKeyValueStore();
    await store.write(
      tipitakaPlacesKey,
      jsonEncode([
        {'key': 'vp-2-1', 'entry': 1, 'fraction': 0.25, 'order': 1},
      ]),
    );
    await openTipitakaApp(t, Routes.tipitakaNode('vp-2'), store: store);
    final line = find.descendant(
      of: _row('vp-2-1'),
      matching: find.byType(ProgressLine),
    );
    expect(line, findsOneWidget);
    expect(t.widget<ProgressLine>(line).value, 0.25);
    expect(
      find.descendant(of: _row('vp-2-2'), matching: find.byType(ProgressLine)),
      findsNothing,
    );
  });

  testWidgets('bar stays visible on list pages', (t) async {
    final h = t.ensureSemantics();
    await openTipitakaApp(t, Routes.tipitakaNode('vp-2'));
    expect(find.byKey(const ValueKey('nav-bar')), findsOneWidget);
    final tab = find.byKey(const ValueKey('nav-tripitaka'));
    expect(tab, findsOneWidget);
    expect(
      t.getSemantics(tab).getSemanticsData().flagsCollection.isSelected
          .toBoolOrNull(),
      isTrue,
    );
    h.dispose();
  });

  testWidgets('a long list is built lazily', (t) async {
    final all = tinyTipitaka();
    final tree = Map<String, Object>.of(all[tinyTreePath]! as Map<String, Object>);
    for (var i = 1; i <= 300; i++) {
      tree['sp-1-$i'] = ['P n$i', 'S n$i', 1, [0, 1], 'sp-1', 'ap-b'];
    }
    all[tinyTreePath] = tree;
    await openTipitakaApp(t, Routes.tipitakaNode('sp-1'),
        load: fakeAssets(all));
    expect(_row('sp-1-1'), findsOneWidget);
    expect(_row('sp-1-300'), findsNothing);
    expect(t.takeException(), isNull);
  });

  late AssetBytes shipped;
  late TipitakaTree shippedTree;
  setUpAll(() async {
    shipped = await shippedTreeAssets();
    shippedTree = await TipitakaRepository(load: shipped).tree();
  });

  for (final (size, scale) in const [(Size(320, 568), 2.0), (Size(1280, 800), 1.5)]) {
    testWidgets('${size.width.round()} px at ${scale}x text: first page, a '
        'list and results draw without overflow', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final app = await openTipitakaApp(t, Routes.tipitaka, size: size);
      expect(t.takeException(), isNull);
      app.go(Routes.tipitakaNode('vp'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      app.go(Routes.tipitakaNode('vp-2'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);

      // Results, over the shipped tree (the made-up names have no letters
      // a search can match): the plain a-z key of a name read from it.
      await openTipitakaApp(t, Routes.tipitaka, size: size, load: shipped);
      await t.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('tipitaka-search')),
          matching: find.byType(TextField),
        ),
        latinKey(shippedTree.node('dn-1')!.pali),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('tipitaka-result-dn-1')), findsOneWidget);
      expect(t.takeException(), isNull);
      await scrollToEnd(t);
    });
  }

  testWidgets('a row with no Sinhala name shows the Pali name once, as the '
      'title', (t) async {
    final assets = tinyTipitaka();
    final tree = assets[tinyTreePath]! as Map<String, Object>;
    final node = List<Object>.of(tree['vp-2-2']! as List<Object>);
    node[1] = '';
    tree['vp-2-2'] = node;
    await openTipitakaApp(
      t,
      Routes.tipitakaNode('vp-2'),
      load: fakeAssets(assets),
    );
    expect(
      find.descendant(of: _row('vp-2-2'), matching: find.text('P two two')),
      findsOneWidget,
    );
  });
}
