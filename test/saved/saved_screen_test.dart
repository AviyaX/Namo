import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';

Future<ProviderContainer> openSaved(WidgetTester t) async {
  await pumpApp(
    t,
    overrides: [
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
    ],
    location: Routes.saved,
  );
  return ProviderScope.containerOf(t.element(find.byType(Scaffold).first));
}

void main() {
  testWidgets(
    'Saved lists bookmarks and favourites and opens the reader at the bookmark',
    (t) async {
      final c = await openSaved(t);
      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.text('Favourites'), findsOneWidget);

      c.read(savedProvider.notifier)
        ..toggleBookmark('r1', 's01')
        ..toggleBookmark('r1', 's03')
        ..toggleFavourite('r1');
      await t.pumpAndSettle();

      expect(find.text('No bookmarks yet.'), findsNothing);
      expect(find.text('No favourites yet.'), findsNothing);
      // Newest bookmark first; the reading title sits beneath each heading.
      expect(
        t.getTopLeft(find.text('heading 3')).dy,
        lessThan(t.getTopLeft(find.text('heading 1')).dy),
      );
      expect(find.text('reading 1'), findsNWidgets(3));

      await t.tap(find.text('heading 3'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('heading-s03')), findsOneWidget);
    },
  );

  testWidgets('a favourite opens the reader at its saved position', (t) async {
    final c = await openSaved(t);
    c.read(savedProvider.notifier).toggleFavourite('r1');
    await t.pumpAndSettle();
    await t.tap(find.text('reading 1'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
  });

  testWidgets('each row has a remove button that removes only that entry', (
    t,
  ) async {
    final c = await openSaved(t);
    c.read(savedProvider.notifier)
      ..toggleBookmark('r1', 's01')
      ..toggleBookmark('r1', 's02')
      ..toggleFavourite('r1');
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('Remove bookmark: heading 1'));
    await t.pumpAndSettle();
    expect(find.text('heading 1'), findsNothing);
    expect(find.text('heading 2'), findsOneWidget);
    expect(c.read(savedProvider).isBookmarked('r1', 's01'), isFalse);
    expect(c.read(savedProvider).isBookmarked('r1', 's02'), isTrue);

    await t.tap(find.byTooltip('Remove favourite: reading 1'));
    await t.pumpAndSettle();
    expect(c.read(savedProvider).favourites, isEmpty);
    expect(find.text('No favourites yet.'), findsOneWidget);
    expect(find.text('No bookmarks yet.'), findsNothing);
  });

  testWidgets(
    'Saved hides entries the content no longer has and shows the empty lines',
    (t) async {
      final c = await openSaved(t);
      expect(find.text('No bookmarks yet.'), findsOneWidget);
      expect(find.text('No favourites yet.'), findsOneWidget);

      c.read(savedProvider.notifier)
        ..toggleBookmark('gone', 's01')
        ..toggleBookmark('r1', 'gone')
        ..toggleFavourite('gone');
      await t.pumpAndSettle();
      // Nothing of them is shown, so both lists read as empty.
      expect(find.text('No bookmarks yet.'), findsOneWidget);
      expect(find.text('No favourites yet.'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    },
  );

  testWidgets('every row and remove button is at least 48 tall', (t) async {
    final c = await openSaved(t);
    c.read(savedProvider.notifier)
      ..toggleBookmark('r1', 's01')
      ..toggleFavourite('r1');
    await t.pumpAndSettle();
    final buttons = find.byType(IconButton);
    expect(buttons, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      final size = t.getSize(buttons.at(i));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
