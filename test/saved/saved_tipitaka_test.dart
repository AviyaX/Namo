import 'package:buddhist_gatha/design/widgets/empty_state.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tipitaka/tipitaka_app_support.dart';
import '../tipitaka/tipitaka_support.dart';

/// The made-up Tipitaka, counting how often each asset is asked for.
AssetBytes counting(Map<String, int> loads) {
  final inner = fakeAssets(tinyTipitaka());
  return (path) {
    loads[path] = (loads[path] ?? 0) + 1;
    return inner(path);
  };
}

final group = find.byKey(const ValueKey('saved-tipitaka-group'));

void main() {
  testWidgets(
    'Saved shows the Tripitaka group with bookmarked readings, newest first',
    (t) async {
      final app = await openTipitakaApp(t, Routes.saved);
      app.container.read(tipitakaSavedProvider.notifier)
        ..toggle('vp-1-1')
        ..toggle('vp-2-1')
        ..toggle('vp-1'); // a parent without text: not a reading, left out
      await t.pumpAndSettle();

      expect(group, findsOneWidget);
      expect(find.descendant(of: group, matching: find.text('Tripitaka')), findsOneWidget);
      expect(find.text('S one one'), findsOneWidget);
      expect(find.text('S two one'), findsOneWidget);
      expect(find.text('S one'), findsNothing);
      expect(
        t.getTopLeft(find.text('S two one')).dy,
        lessThan(t.getTopLeft(find.text('S one one')).dy),
      );
      expect(find.text('S vp › S two'), findsOneWidget);
      expect(find.text('S vp › S one'), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
    },
  );

  testWidgets('tapping opens the reader and Back returns to Saved', (t) async {
    final app = await openTipitakaApp(t, Routes.saved);
    app.container.read(tipitakaSavedProvider.notifier).toggle('vp-1-1');
    await t.pumpAndSettle();
    await t.tap(find.text('S one one'));
    await t.pumpAndSettle();
    expect(app.location, '/tipitaka/read/vp-1-1?from=saved');
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(app.location, Routes.saved);
    expect(find.byKey(const ValueKey('screen-saved')), findsOneWidget);
  });

  testWidgets('remove takes the row away and updates storage', (t) async {
    final app = await openTipitakaApp(t, Routes.saved);
    app.container.read(tipitakaSavedProvider.notifier)
      ..toggle('vp-1-1')
      ..toggle('vp-2-1');
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Remove bookmark: S one one'));
    await t.pumpAndSettle();
    expect(find.text('S one one'), findsNothing);
    expect(find.text('S two one'), findsOneWidget);
    expect(app.container.read(tipitakaSavedProvider), ['vp-2-1']);
    expect(app.store.read(tipitakaSavedKey), '["vp-2-1"]');

    await t.tap(find.byTooltip('Remove bookmark: S two one'));
    await t.pumpAndSettle();
    expect(group, findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets(
    'no group and no tree load when there are no Tripitaka bookmarks',
    (t) async {
      final loads = <String, int>{};
      final app = await openTipitakaApp(t, Routes.saved, load: counting(loads));
      app.container.read(savedProvider.notifier).toggleFavourite('r1');
      await t.pumpAndSettle();
      expect(group, findsNothing);
      expect(loads, isEmpty);
    },
  );

  testWidgets('a bookmark asks for the tree; while it loads nothing is drawn',
      (t) async {
    final loads = <String, int>{};
    final store = InMemoryKeyValueStore()
      ..save(tipitakaSavedKey, '["vp-1-1"]');
    await openTipitakaApp(t, Routes.saved, load: counting(loads), store: store);
    await t.pumpAndSettle();
    expect(loads[tinyTreePath], 1);
    expect(find.text('S one one'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('only stale Tripitaka bookmarks: the empty state once the tree '
      'has loaded', (t) async {
    final store = InMemoryKeyValueStore()
      // An unknown key and a parent without text: neither is a reading.
      ..save(tipitakaSavedKey, '["no-such-key","vp-1"]');
    await openTipitakaApp(t, Routes.saved, store: store);
    await t.pumpAndSettle();
    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(group, findsNothing);
    expect(find.text('No bookmarks yet.'), findsNothing);
  });

  testWidgets('empty state only when all three are empty', (t) async {
    final app = await openTipitakaApp(t, Routes.saved);
    await t.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);

    app.container.read(tipitakaSavedProvider.notifier).toggle('vp-1-1');
    await t.pumpAndSettle();
    expect(find.byType(EmptyState), findsNothing);
    expect(group, findsOneWidget);
    expect(find.text('Nothing saved yet'), findsNothing);
    app.container.read(tipitakaSavedProvider.notifier).toggle('vp-1-1');
    app.container.read(savedProvider.notifier).toggleFavourite('r1');
    await t.pumpAndSettle();
    expect(find.byType(EmptyState), findsNothing);
    expect(group, findsNothing);
  });
}
