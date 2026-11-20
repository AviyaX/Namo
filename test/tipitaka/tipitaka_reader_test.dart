import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/design/widgets/not_found.dart';
import 'package:buddhist_gatha/design/widgets/progress_line.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_reader_screen.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';
import 'tipitaka_support.dart';

const _noSinhalaHere = 'No Sinhala in the source for this passage';
const _noSinhalaAtAll = 'The source has no Sinhala translation for this text';

/// [tinyTipitaka] with [extra] made-up paragraphs ('line 0', 'line 1', ...)
/// added to the end of the first page of book vp-a (inside reading vp-1-1).
Map<String, Object> _longTipitaka(int extra) {
  final all = tinyTipitaka();
  final book = jsonDecode(jsonEncode(all[tinyBookPath('vp-a')])) as Map;
  final page = (book['pages'] as List).first as Map;
  for (final side in ['pali', 'sinh']) {
    final entries = (page[side] as Map)['entries'] as List;
    for (var i = 0; i < extra; i++) {
      entries.add({
        'type': 'paragraph',
        'text': side == 'pali' ? 'line $i' : 's line $i',
      });
    }
  }
  all[tinyBookPath('vp-a')] = book.cast<String, Object>();
  return all;
}

/// [tinyTipitaka] with paragraphs added to reading vp-1-1 whose Sinhala is
/// blank in two runs: 'gap a 0..2', then 'kept' (with Sinhala), then
/// 'gap b 0..1'.
Map<String, Object> _gappedTipitaka() {
  final all = tinyTipitaka();
  final book = jsonDecode(jsonEncode(all[tinyBookPath('vp-a')])) as Map;
  final page = (book['pages'] as List).first as Map;
  final pali = (page['pali'] as Map)['entries'] as List;
  final sinh = (page['sinh'] as Map)['entries'] as List;
  void add(String text, String sinhala) {
    pali.add({'type': 'paragraph', 'text': text});
    sinh.add({'type': 'paragraph', 'text': sinhala});
  }

  for (var i = 0; i < 3; i++) {
    add('gap a $i', ' ');
  }
  add('kept', 's kept');
  for (var i = 0; i < 2; i++) {
    add('gap b $i', '');
  }
  all[tinyBookPath('vp-a')] = book.cast<String, Object>();
  return all;
}

class _Opened {
  _Opened(this.container, this.store, this.loads);
  final ProviderContainer container;
  final InMemoryKeyValueStore store;
  final List<String> loads;

  String get location => container
      .read(routerProvider)
      .routeInformationProvider
      .value
      .uri
      .toString();
}

Future<_Opened> _open(
  WidgetTester t,
  String location, {
  Size size = const Size(400, 900),
  TipitakaView? view,
  Map<String, Object>? assets,
  InMemoryKeyValueStore? store,
}) async {
  await t.pumpWidget(const SizedBox());
  final kv = store ?? InMemoryKeyValueStore();
  if (view != null) await kv.write(tipitakaViewKey, jsonEncode(view.name));
  final loads = <String>[];
  final serve = fakeAssets(assets ?? tinyTipitaka());
  Future<Uint8List> load(String path) {
    loads.add(path);
    return serve(path);
  }

  await pumpApp(
    t,
    size: size,
    overrides: [
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      keyValueStoreProvider.overrideWithValue(kv),
      tipitakaRepositoryProvider.overrideWithValue(
        TipitakaRepository(load: load, inBackground: false),
      ),
    ],
    location: location,
  );
  return _Opened(
    ProviderScope.containerOf(t.element(find.byType(MaterialApp))),
    kv,
    loads,
  );
}

double _top(WidgetTester t, String text) =>
    t.getTopLeft(find.textContaining(text).first).dy;

double _left(WidgetTester t, String text) =>
    t.getTopLeft(find.textContaining(text).first).dx;

void main() {
  testWidgets("shows the reading's entries in order including the title "
      'lines above it', (t) async {
    await _open(t, Routes.tipitakaReader('vp-1-1'), view: TipitakaView.pali);
    expect(find.byType(TipitakaReaderScreen), findsOneWidget);
    // The top bar names the reading by its Sinhala name.
    expect(find.text('S one one'), findsOneWidget);
    final order = ['Title A', 'Root vp', 'Part one', 'Leaf one one',
        'Leaf one text'];
    for (var i = 1; i < order.length; i++) {
      expect(_top(t, order[i]), greaterThan(_top(t, order[i - 1])),
          reason: order[i]);
    }
    expect(find.textContaining('Part two'), findsNothing);
    expect(find.textContaining('s Leaf one one'), findsNothing);
  });

  testWidgets('switch to පාලි shows Pali only; choice is stored', (t) async {
    final o = await _open(t, Routes.tipitakaReader('vp-1-1'));
    expect(find.bySemanticsLabel('Language'), findsOneWidget);
    expect(find.text('s Leaf one one'), findsOneWidget);
    await t.tap(find.text('පාලි'));
    await t.pumpAndSettle();
    expect(find.text('Leaf one one'), findsOneWidget);
    expect(find.text('s Leaf one one'), findsNothing);
    expect(o.container.read(tipitakaViewProvider), TipitakaView.pali);
    expect(o.store.read(tipitakaViewKey), jsonEncode('pali'));
  });

  testWidgets('both on 400 px interleaves; on 1280 px shows pairs side by '
      'side', (t) async {
    await _open(t, Routes.tipitakaReader('vp-1-1'), view: TipitakaView.both);
    expect(_top(t, 'Leaf one one'), lessThan(_top(t, 's Leaf one one')));
    expect(_top(t, 's Leaf one one'), lessThan(_top(t, 'Leaf one text')));
    expect(_left(t, 's Leaf one one'), _left(t, 'Leaf one one'));

    await _open(
      t,
      Routes.tipitakaReader('vp-1-1'),
      view: TipitakaView.both,
      size: const Size(1280, 900),
    );
    expect(_top(t, 's Leaf one one'), _top(t, 'Leaf one one'));
    expect(_left(t, 's Leaf one one'), greaterThan(_left(t, 'Leaf one one')));
    // Pairs stay level: the next pair starts below the taller of the two.
    expect(_top(t, 'Leaf one text'), greaterThan(_top(t, 's Leaf one one')));
    expect(_top(t, 's Leaf one text'), _top(t, 'Leaf one text'));
  });

  testWidgets('first run default is සිංහල at 400 px and Both at 1280 px',
      (t) async {
    await _open(t, Routes.tipitakaReader('vp-1-1'));
    expect(find.text('s Leaf one one'), findsOneWidget);
    expect(find.text('Leaf one one'), findsNothing);

    final o = await _open(
      t,
      Routes.tipitakaReader('vp-1-1'),
      size: const Size(1280, 900),
    );
    expect(find.text('s Leaf one one'), findsOneWidget);
    expect(find.text('Leaf one one'), findsOneWidget);
    // Nothing is stored until the person chooses.
    expect(o.container.read(tipitakaViewProvider), isNull);
  });

  testWidgets('Pali-only reading shows the single note and no per-entry '
      'notes', (t) async {
    for (final view in TipitakaView.values) {
      await _open(t, Routes.tipitakaReader('sp-1'), view: view);
      expect(find.text(_noSinhalaAtAll), findsOneWidget, reason: view.name);
      expect(find.text(_noSinhalaHere), findsNothing, reason: view.name);
      expect(find.text('Sp one'), findsOneWidget, reason: view.name);
      expect(find.textContaining('sp one text'), findsOneWidget);
    }
  });

  testWidgets('a run of entries without Sinhala shows one caption',
      (t) async {
    await _open(
      t,
      Routes.tipitakaReader('vp-1-1'),
      assets: _gappedTipitaka(),
      size: const Size(400, 2000),
    );
    // Two runs, one caption each, above the first entry of its run.
    expect(find.text(_noSinhalaHere), findsNWidgets(2));
    final captions = [
      for (final e in find.text(_noSinhalaHere).evaluate())
        t.getTopLeft(find.byWidget(e.widget)).dy,
    ]..sort();
    expect(captions[0], lessThan(_top(t, 'gap a 0')));
    expect(captions[0], greaterThan(_top(t, 's Leaf one text')));
    expect(captions[1], greaterThan(_top(t, 's kept')));
    expect(captions[1], lessThan(_top(t, 'gap b 0')));
    // The Pali is shown in their place.
    for (final text in ['gap a 1', 'gap a 2', 'gap b 1']) {
      expect(find.textContaining(text), findsOneWidget);
    }
    expect(find.text(_noSinhalaAtAll), findsNothing);

    // vp-2: the first entry has Sinhala, the second is blank in Sinhala.
    await _open(t, Routes.tipitakaReader('vp-2'));
    expect(find.text('s Part two'), findsOneWidget);
    expect(find.text(_noSinhalaHere), findsOneWidget);
    expect(find.textContaining('Part two intro'), findsOneWidget);

    // Not in the Pali view.
    await _open(
      t,
      Routes.tipitakaReader('vp-1-1'),
      assets: _gappedTipitaka(),
      view: TipitakaView.pali,
    );
    expect(find.text(_noSinhalaHere), findsNothing);
  });

  testWidgets('a reading whose entries all lack Sinhala gets the single note',
      (t) async {
    // vp-2-2: its page's two lists differ in length.
    await _open(t, Routes.tipitakaReader('vp-2-2'));
    expect(find.text(_noSinhalaAtAll), findsOneWidget);
    expect(find.text(_noSinhalaHere), findsNothing);
    expect(find.text('Leaf two two'), findsOneWidget);
  });

  testWidgets('bookmark toggles and is stored', (t) async {
    final o = await _open(t, Routes.tipitakaReader('vp-1-1'));
    await t.tap(find.byTooltip('Bookmark this text'));
    await t.pumpAndSettle();
    expect(o.container.read(tipitakaSavedProvider), ['vp-1-1']);
    expect(o.store.read(tipitakaSavedKey), jsonEncode(['vp-1-1']));
    expect(find.byTooltip('Remove bookmark'), findsOneWidget);
    await t.tap(find.byTooltip('Remove bookmark'));
    await t.pumpAndSettle();
    expect(o.container.read(tipitakaSavedProvider), isEmpty);
    expect(find.byTooltip('Bookmark this text'), findsOneWidget);
  });

  testWidgets('scrolling stores a place; reopening starts at that entry',
      (t) async {
    final assets = _longTipitaka(80);
    final store = InMemoryKeyValueStore();
    final o = await _open(
      t,
      Routes.tipitakaReader('vp-1-1'),
      view: TipitakaView.pali,
      assets: assets,
      store: store,
    );
    const count = 85; // 5 entries of the tiny book, 80 added
    await t.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 2));
    final place = o.container.read(tipitakaPlacesProvider).of('vp-1-1');
    expect(place, isNotNull);
    expect(place!.entry, greaterThan(20));
    expect(place.fraction, closeTo((place.entry + 1) / count, 1e-9));
    final progress = t.widget<ProgressLine>(find.byType(ProgressLine));
    expect(progress.value, closeTo(place.fraction, 1e-9));

    // The entry at the top is 'line <entry - 5>'.
    final top = 'line ${place.entry - 5}';
    expect(find.textContaining(top), findsOneWidget);

    // Reopen in a fresh app on the same store.
    await _open(
      t,
      Routes.tipitakaReader('vp-1-1'),
      assets: assets,
      store: store,
    );
    final scroll = t.getRect(find.byType(CustomScrollView));
    expect(find.textContaining(top), findsOneWidget);
    expect(_top(t, top), closeTo(scroll.top, 40));
    // What is far above is not built.
    expect(find.text('Title A'), findsNothing);
    expect(find.text('Root vp'), findsNothing);
    final reopened = t.widget<ProgressLine>(find.byType(ProgressLine));
    expect(reopened.value, closeTo(place.fraction, 1e-9));

    // Scrolling back up reaches the title lines.
    await t.scrollUntilVisible(find.text('Title A'), -300,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    expect(find.text('Title A'), findsOneWidget);
    expect(_top(t, 'Title A'), greaterThanOrEqualTo(scroll.top));
  });

  testWidgets('leaving stores the place at once', (t) async {
    final o = await _open(
      t,
      Routes.tipitakaReader('vp-1-1'),
      view: TipitakaView.pali,
      assets: _longTipitaka(80),
    );
    await t.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await t.pump();
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    final place = o.container.read(tipitakaPlacesProvider).of('vp-1-1');
    expect(place, isNotNull);
    expect(place!.entry, greaterThan(10));
  });

  testWidgets('Back to the beginning jumps to entry 0', (t) async {
    final store = InMemoryKeyValueStore();
    await _open(
      t,
      Routes.tipitakaReader('vp-1-1'),
      view: TipitakaView.pali,
      assets: _longTipitaka(80),
      store: store,
    );
    await t.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 2));
    expect(find.text('Title A'), findsNothing);
    await t.tap(find.byTooltip('Reading settings'));
    await t.pumpAndSettle();
    // Only text size, line spacing, theme and Back to the beginning.
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('Line spacing'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Languages'), findsNothing);
    expect(find.text('Scroll speed'), findsNothing);
    expect(find.text('When two languages show'), findsNothing);
    await t.tap(find.text('Back to the beginning'));
    await t.pumpAndSettle();
    expect(find.text('Title A'), findsOneWidget);
    final scroll = t.getRect(find.byType(CustomScrollView));
    expect(_top(t, 'Title A'), closeTo(scroll.top, 40));
  });

  testWidgets('Next goes to the next reading, also across files; no Previous '
      'on the first reading', (t) async {
    final o = await _open(t, Routes.tipitakaReader('vp-1-1'));
    await t.scrollUntilVisible(find.text('Next'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Previous'), findsNothing);
    expect(find.text('S two'), findsOneWidget); // vp-2's Sinhala name
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
    expect(o.location, Routes.tipitakaReader('vp-2'));
    expect(find.text('s Part two'), findsOneWidget);

    final o2 = await _open(
      t,
      Routes.tipitakaReader('vp-2-10', fromSaved: true),
    );
    await t.scrollUntilVisible(find.text('Next'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('S two two'), findsOneWidget);
    expect(find.text('S sp one'), findsOneWidget);
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
    expect(o2.location, Routes.tipitakaReader('sp-1'));
    expect(find.text('Sp one'), findsOneWidget);
  });

  testWidgets('Previous goes to the previous reading', (t) async {
    final o = await _open(t, Routes.tipitakaReader('vp-2'));
    await t.scrollUntilVisible(find.text('Previous'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('S one one'), findsWidgets);
    await t.tap(find.text('Previous'));
    await t.pumpAndSettle();
    expect(o.location, Routes.tipitakaReader('vp-1-1'));
  });

  testWidgets("Back goes to the parent's list address; with from=saved to "
      '/saved', (t) async {
    var o = await _open(t, Routes.tipitakaReader('vp-1-1'));
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(o.location, Routes.tipitakaNode('vp-1'));

    // A reading with children goes to its own list.
    o = await _open(t, Routes.tipitakaReader('vp-2'));
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(o.location, Routes.tipitakaNode('vp-2'));

    o = await _open(t, Routes.tipitakaReader('sp-1'));
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(o.location, Routes.tipitakaNode('sp'));

    o = await _open(t, Routes.tipitakaReader('vp-1-1', fromSaved: true));
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(o.location, Routes.saved);

    o = await _open(t, Routes.tipitakaReader('vp-2-1', fromSaved: true));
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(o.location, Routes.saved);
  });

  testWidgets('unknown key shows not found', (t) async {
    await _open(t, Routes.tipitakaReader('zz-9'));
    expect(find.byType(NotFoundScreen), findsOneWidget);
  });

  testWidgets('a parent without text shows not found', (t) async {
    await _open(t, Routes.tipitakaReader('vp-1'));
    expect(find.byType(NotFoundScreen), findsOneWidget);
  });

  testWidgets('a book that fails to load shows the message and Go back works',
      (t) async {
    final assets = tinyTipitaka()..remove(tinyBookPath('vp-a'));
    final o = await _open(t, Routes.tipitakaReader('vp-1-1'), assets: assets);
    expect(find.text('This text could not be opened.'), findsOneWidget);
    // Not retried behind the message.
    await t.pump(const Duration(seconds: 30));
    await t.pumpAndSettle();
    expect(
      o.loads.where((p) => p == tinyBookPath('vp-a')).length,
      1,
    );
    expect(find.text('This text could not be opened.'), findsOneWidget);
    await t.tap(find.text('Go back'));
    await t.pumpAndSettle();
    expect(o.location, Routes.tipitakaNode('vp-1'));
  });

  testWidgets('a broken book file shows the message once, not retried',
      (t) async {
    // A FormatException: an Exception, which Riverpod would retry by default.
    final assets = tinyTipitaka()..[tinyBookPath('vp-a')] = {'pages': 3};
    final o = await _open(t, Routes.tipitakaReader('vp-1-1'), assets: assets);
    expect(find.text('This text could not be opened.'), findsOneWidget);
    await t.pump(const Duration(seconds: 30));
    await t.pumpAndSettle();
    expect(o.loads.where((p) => p == tinyBookPath('vp-a')).length, 1);
    expect(find.text('This text could not be opened.'), findsOneWidget);
  });

  testWidgets('a tree that fails to load shows the message; Go back leads '
      'to the tab', (t) async {
    final assets = tinyTipitaka()..[tinyTreePath] = {'vp': 'broken'};
    // A tree of the wrong shape parses to an empty tree: not found.
    await _open(t, Routes.tipitakaReader('vp-1-1'), assets: assets);
    expect(find.byType(NotFoundScreen), findsOneWidget);

    final broken = tinyTipitaka()..remove(tinyTreePath);
    final o = await _open(t, Routes.tipitakaReader('vp-1-1'), assets: broken);
    expect(find.text('This text could not be opened.'), findsOneWidget);
    await t.tap(find.text('Go back'));
    await t.pumpAndSettle();
    expect(o.location, Routes.tipitaka);
  });

  testWidgets('while loading: a progress mark, and Back works', (t) async {
    await t.pumpWidget(const SizedBox());
    final kv = InMemoryKeyValueStore();
    await pumpApp(
      t,
      overrides: [
        contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
        keyValueStoreProvider.overrideWithValue(kv),
        tipitakaRepositoryProvider.overrideWithValue(
          // Never answers.
          TipitakaRepository(
            load: (_) => Completer<Uint8List>().future,
            inBackground: false,
          ),
        ),
      ],
      location: Routes.tipitakaReader('vp-1-1', fromSaved: true),
      settle: false,
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await t.tap(find.byTooltip('Back'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    expect(
      c.read(routerProvider).routeInformationProvider.value.uri.toString(),
      Routes.saved,
    );
  });

  testWidgets('text size and line spacing from settings change the entry '
      'text style', (t) async {
    final o = await _open(
      t,
      Routes.tipitakaReader('vp-1-1'),
      view: TipitakaView.pali,
    );
    TextStyle style() {
      final rich = t.widget<RichText>(
        find
            .descendant(
              of: find.byKey(const ValueKey('tipitaka-entry-3')),
              matching: find.byType(RichText),
            )
            .first,
      );
      final span = rich.text as TextSpan;
      return span.children!.first.style!.merge(null);
    }

    final before = style();
    o.container.read(settingsProvider.notifier)
      ..setFontScale(1.5)
      ..setLineSpacing(2.0);
    await t.pumpAndSettle();
    final after = style();
    expect(after.fontSize, closeTo(before.fontSize! * 1.5, 0.01));
    expect(after.height, 2.0);
  });

  testWidgets('no overflow at 320 px wide with text scale 2.0', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    for (final view in TipitakaView.values) {
      for (final key in ['vp-1-1', 'vp-2', 'vp-2-2', 'sp-1']) {
        await _open(
          t,
          Routes.tipitakaReader(key),
          size: const Size(320, 640),
          view: view,
        );
        expect(t.takeException(), isNull, reason: '$key ${view.name}');
        await t.scrollUntilVisible(find.text('Next'), 200,
            scrollable: find.byType(Scrollable).first);
        expect(t.takeException(), isNull, reason: '$key ${view.name}');
      }
    }
  });
}
