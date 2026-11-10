import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/design/widgets/floating_bar.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../quality/quality_support.dart';
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
      c.read(savedProvider.notifier)
        ..toggleBookmark('r1', 's01')
        ..toggleBookmark('r1', 's03')
        ..toggleFavourite('r1');
      await t.pumpAndSettle();

      expect(find.text('Bookmarks · 2'), findsOneWidget);
      expect(find.text('Favourites · 1'), findsOneWidget);
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

  testWidgets('with nothing saved there is one calm empty state', (t) async {
    await openSaved(t);
    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(
      find.text(
        'Bookmark a section or favourite a reading and it will wait for you '
        'here.',
      ),
      findsOneWidget,
    );
    expect(find.text('No bookmarks yet.'), findsNothing);
    expect(find.text('No favourites yet.'), findsNothing);
    expect(find.textContaining('Bookmarks ·'), findsNothing);

    await t.tap(find.text('Open the Library'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
  });

  testWidgets('only a bookmark: its row and the favourites line', (t) async {
    final c = await openSaved(t);
    c.read(savedProvider.notifier).toggleBookmark('r1', 's02');
    await t.pumpAndSettle();
    expect(find.text('Nothing saved yet'), findsNothing);
    expect(find.text('Bookmarks · 1'), findsOneWidget);
    expect(find.text('Favourites · 0'), findsOneWidget);
    expect(find.text('heading 2'), findsOneWidget);
    expect(find.text('No favourites yet.'), findsOneWidget);
    expect(find.text('No bookmarks yet.'), findsNothing);
  });

  testWidgets('only a favourite: its row and the bookmarks line', (t) async {
    final c = await openSaved(t);
    c.read(savedProvider.notifier).toggleFavourite('r1');
    await t.pumpAndSettle();
    expect(find.text('Favourites · 1'), findsOneWidget);
    expect(find.text('Bookmarks · 0'), findsOneWidget);
    expect(find.text('reading 1'), findsOneWidget);
    expect(find.text('subtitle 1'), findsOneWidget);
    expect(find.text('No bookmarks yet.'), findsOneWidget);
    expect(find.text('No favourites yet.'), findsNothing);
  });

  testWidgets(
    'Saved hides entries the content no longer has and shows the empty state',
    (t) async {
      final c = await openSaved(t);
      c.read(savedProvider.notifier)
        ..toggleBookmark('gone', 's01')
        ..toggleBookmark('r1', 'gone')
        ..toggleFavourite('gone');
      await t.pumpAndSettle();
      // Nothing of them is shown, so both lists read as empty.
      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(find.byIcon(Symbols.close_rounded), findsNothing);

      // Beside a real entry they are still left out, and the count is real.
      c.read(savedProvider.notifier).toggleBookmark('r1', 's01');
      await t.pumpAndSettle();
      expect(find.text('Bookmarks · 1'), findsOneWidget);
      expect(find.text('Favourites · 0'), findsOneWidget);
      expect(find.text('No favourites yet.'), findsOneWidget);
      expect(find.byIcon(Symbols.close_rounded), findsOneWidget);
    },
  );

  testWidgets('Back from the reader returns to Saved', (t) async {
    final c = await openSaved(t);
    c.read(savedProvider.notifier).toggleBookmark('r1', 's02');
    await t.pumpAndSettle();
    await t.tap(find.text('heading 2'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-saved')), findsNothing);
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-saved')), findsOneWidget);
    expect(find.text('heading 2'), findsOneWidget);
  });

  testWidgets('every row and remove button is at least 48 tall', (t) async {
    final c = await openSaved(t);
    c.read(savedProvider.notifier)
      ..toggleBookmark('r1', 's01')
      ..toggleFavourite('r1');
    await t.pumpAndSettle();
    final buttons = find.byType(NamoIconButton);
    expect(buttons, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      final size = t.getSize(buttons.at(i));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('the last row can be scrolled above the navigation bar', (
    t,
  ) async {
    await openReal(t, Routes.saved, withSaved: true);
    final position = t
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.maxScrollExtent);
    await t.pumpAndSettle();
    final barTop = t.getRect(find.byType(FloatingBar)).top;
    expect(
      t.getRect(find.byKey(const ValueKey('saved-column'))).bottom,
      lessThanOrEqualTo(barTop),
    );
  });

  group('no overflow', () {
    final cases = <(Size, double)>[
      (const Size(320, 568), 2.0),
      for (final w in [360.0, 390.0, 840.0, 1280.0])
        for (final s in [1.0, 1.5]) (Size(w, 800), s),
    ];
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      for (final (size, scale) in cases) {
        for (final saved in [false, true]) {
          testWidgets(
            '${size.width.round()} x ${size.height.round()}, text $scale, '
            '${theme.name}, ${saved ? 'with' : 'without'} entries',
            (t) async {
              await openReal(
                t,
                Routes.saved,
                size: size,
                deviceTextScale: scale,
                settings: AppSettings(themeMode: theme),
                withSaved: saved,
              );
              await scrollThrough(t);
            },
          );
        }
      }
    }
  });
}
