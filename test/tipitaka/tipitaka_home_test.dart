import 'dart:convert';
import 'dart:typed_data';

import 'package:buddhist_gatha/design/widgets/progress_line.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:buddhist_gatha/tipitaka/pali_display.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_search.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_state.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_tree.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tipitaka_app_support.dart';
import 'tipitaka_support.dart';

Finder _card(String key) => find.byKey(ValueKey('tipitaka-pitaka-$key'));
final _continue = find.byKey(const ValueKey('tipitaka-continue'));
final _search = find.byKey(const ValueKey('tipitaka-search'));
final _results = find.byKey(const ValueKey('tipitaka-results'));

Future<void> _type(WidgetTester t, String text) async {
  await t.enterText(
    find.descendant(of: _search, matching: find.byType(TextField)),
    text,
  );
  await t.pumpAndSettle();
}

void main() {
  late AssetBytes shipped;
  late TipitakaTree shippedTree;
  setUpAll(() async {
    shipped = await shippedTreeAssets();
    shippedTree = await TipitakaRepository(load: shipped).tree();
  });

  testWidgets('shows three pitaka cards with names from the tree and counts',
      (t) async {
    final app = await openTipitakaApp(t, Routes.tipitaka);
    expect(find.byKey(const ValueKey('screen-tripitaka')), findsOneWidget);
    expect(find.text('ත්‍රිපිටකය'), findsOneWidget);
    expect(find.text('Search by name'), findsOneWidget);
    final expected = {
      'vp': ('S vp', 'Vinaya Pitaka', '5 texts'),
      'sp': ('S sp', 'Sutta Pitaka', '1 text'),
      'ap': ('S ap', 'Abhidhamma Pitaka', '1 text'),
    };
    double? top;
    for (final MapEntry(:key, value: (name, label, count))
        in expected.entries) {
      expect(_card(key), findsOneWidget, reason: key);
      for (final s in [name, label, count]) {
        expect(find.descendant(of: _card(key), matching: find.text(s)),
            findsOneWidget, reason: '$key $s');
      }
      final y = t.getTopLeft(_card(key)).dy;
      if (top != null) expect(y, greaterThan(top), reason: key);
      top = y;
    }
    await t.tap(_card('sp'));
    await t.pumpAndSettle();
    expect(app.location, Routes.tipitakaNode('sp'));
  });

  testWidgets('on a wide screen the three cards sit in one row', (t) async {
    await openTipitakaApp(t, Routes.tipitaka, size: const Size(1280, 800));
    final y = t.getTopLeft(_card('vp')).dy;
    expect(t.getTopLeft(_card('sp')).dy, y);
    expect(t.getTopLeft(_card('ap')).dy, y);
    expect(t.getTopLeft(_card('sp')).dx,
        greaterThan(t.getTopLeft(_card('vp')).dx));
    expect(t.takeException(), isNull);
  });

  testWidgets('no Continue card at first; appears after a place is '
      'remembered; opens the reader', (t) async {
    final app = await openTipitakaApp(t, Routes.tipitaka);
    expect(_continue, findsNothing);
    app.container
        .read(tipitakaPlacesProvider.notifier)
        .remember('vp-2-1', entry: 0, fraction: 0.5);
    await t.pumpAndSettle();
    expect(_continue, findsOneWidget);
    for (final s in ['CONTINUE READING', 'S two one', 'S vp › S two']) {
      expect(find.descendant(of: _continue, matching: find.text(s)),
          findsOneWidget, reason: s);
    }
    final line = t.widget<ProgressLine>(
      find.descendant(of: _continue, matching: find.byType(ProgressLine)),
    );
    expect(line.value, 0.5);
    await t.tap(_continue);
    await t.pumpAndSettle();
    expect(app.location, Routes.tipitakaReader('vp-2-1'));
  });

  testWidgets('a remembered key missing from the tree shows no card and is '
      'pruned', (t) async {
    final store = InMemoryKeyValueStore();
    await store.write(
      tipitakaPlacesKey,
      jsonEncode([
        {'key': 'gone-1', 'entry': 0, 'fraction': 0.3, 'order': 1},
      ]),
    );
    final app = await openTipitakaApp(t, Routes.tipitaka, store: store);
    expect(_continue, findsNothing);
    expect(app.container.read(tipitakaPlacesProvider).recent, isEmpty);
  });

  testWidgets('typing shows results with paths; clearing restores the cards',
      (t) async {
    final app = await openTipitakaApp(t, Routes.tipitaka, load: shipped);
    // A name read from the shipped tree, typed as a person would.
    final node = shippedTree.node('dn-1')!;
    final path = shippedTree
        .ancestors('dn-1')
        .map((a) => tipitakaForDisplay(a.sinhala))
        .join(' › ');
    await _type(t, node.sinhala);
    expect(_results, findsOneWidget);
    expect(_card('vp'), findsNothing);
    final row = find.byKey(const ValueKey('tipitaka-result-dn-1'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(
          of: row, matching: find.text(tipitakaForDisplay(node.sinhala))),
      findsOneWidget,
    );
    expect(find.descendant(of: row, matching: find.text(path)),
        findsOneWidget);
    await t.tap(row);
    await t.pumpAndSettle();
    expect(app.location, Routes.tipitakaNode('dn-1'));
    app.go(Routes.tipitaka);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Clear search'));
    await t.pumpAndSettle();
    expect(_results, findsNothing);
    expect(_card('vp'), findsOneWidget);
  });

  testWidgets('Latin letters find a name by its Pali key', (t) async {
    await openTipitakaApp(t, Routes.tipitaka, load: shipped);
    // The plain a-z key of a name read from the shipped tree.
    await _type(t, latinKey(shippedTree.node('dn-1')!.pali));
    expect(_results, findsOneWidget);
    expect(find.byKey(const ValueKey('tipitaka-result-dn-1')), findsOneWidget);
  });

  testWidgets('a query with no match shows the empty state', (t) async {
    await openTipitakaApp(t, Routes.tipitaka);
    await _type(t, 'qqqq');
    expect(find.text('No names match'), findsOneWidget);
    expect(_card('vp'), findsNothing);
  });

  testWidgets('a query that folds to nothing keeps the page', (t) async {
    await openTipitakaApp(t, Routes.tipitaka);
    await _type(t, ' .,- ');
    expect(_results, findsNothing);
    expect(find.text('No names match'), findsNothing);
    expect(_card('vp'), findsOneWidget);
  });

  testWidgets('pressing the Tripitaka tab on its first page clears the search',
      (t) async {
    await openTipitakaApp(t, Routes.tipitaka);
    await _type(t, 'qqqq');
    expect(find.text('No names match'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nav-tripitaka')));
    await t.pumpAndSettle();
    expect(find.text('No names match'), findsNothing);
    expect(_card('vp'), findsOneWidget);
    final field = t.widget<TextField>(
      find.descendant(of: _search, matching: find.byType(TextField)),
    );
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('load failure shows the message and Try again reloads',
      (t) async {
    var broken = true;
    final good = fakeAssets(tinyTipitaka());
    Future<Uint8List> load(String path) {
      if (broken && path == tinyTreePath) {
        return Future.error(StateError('missing'));
      }
      return good(path);
    }

    await openTipitakaApp(t, Routes.tipitaka, load: load);
    expect(find.text('The Tripitaka could not be opened.'), findsOneWidget);
    expect(_card('vp'), findsNothing);
    broken = false;
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('The Tripitaka could not be opened.'), findsNothing);
    expect(_card('vp'), findsOneWidget);
  });
}
