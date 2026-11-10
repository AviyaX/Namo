import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../support/fake_chant_player.dart';
import '../support/pump_app.dart';
import '../support/test_content.dart';

class _One implements AudioCatalogue {
  @override
  Recording? recordingFor(String readingId) => Recording(
    readingId: readingId,
    asset: 'assets/audio/test.mp3',
    label: 'A test recording',
    placeholder: false,
  );
}

Future<ProviderContainer> open(WidgetTester t, String location) async {
  final player = FakeChantPlayer();
  await pumpApp(
    t,
    overrides: [
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      audioCatalogueProvider.overrideWithValue(_One()),
      chantPlayerProvider.overrideWith((ref) {
        ref.onDispose(player.dispose);
        return player;
      }),
    ],
    location: location,
  );
  return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
}

/// Every icon on screen is a thin-line rounded Material Symbol at the
/// weight the tabs use.
void expectThinLineIcons(WidgetTester t, String where) {
  final icons = t.widgetList<Icon>(find.byType(Icon)).toList();
  expect(icons, isNotEmpty, reason: where);
  for (final icon in icons) {
    expect(
      icon.icon!.fontFamily,
      Symbols.home_rounded.fontFamily,
      reason: '$where: ${icon.icon}',
    );
    expect(icon.weight, 300, reason: '$where: ${icon.icon}');
  }
}

Icon iconIn(WidgetTester t, Finder button) =>
    t.widget<Icon>(find.descendant(of: button, matching: find.byType(Icon)));

void main() {
  testWidgets('the reader, its audio row and its settings sheet use '
      'thin-line icons', (t) async {
    final c = await open(t, Routes.reader('r1'));
    c.read(savedProvider.notifier).toggleBookmark('r1', 's01');
    c.read(savedProvider.notifier).toggleFavourite('r1');
    await t.pumpAndSettle();
    expectThinLineIcons(t, 'reader');

    await t.tap(find.byKey(const ValueKey('audio-play')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('reader-play')));
    await t.pump();
    expectThinLineIcons(t, 'reader, playing');
    await t.tap(find.byKey(const ValueKey('reader-play')));
    await t.pump();

    await t.tap(find.byKey(const ValueKey('reader-settings')));
    await t.pumpAndSettle();
    expectThinLineIcons(t, 'reader sheet');
    expect(t.takeException(), isNull);
  });

  testWidgets('bookmark and favourite show their state by fill', (t) async {
    final c = await open(t, Routes.reader('r1'));
    c.read(savedProvider.notifier).toggleBookmark('r1', 's01');
    c.read(savedProvider.notifier).toggleFavourite('r1');
    await t.pumpAndSettle();

    final on = iconIn(t, find.byTooltip('Remove bookmark'));
    expect(on.icon, Symbols.bookmark_rounded);
    expect(on.fill, 1);
    final off = iconIn(t, find.byTooltip('Bookmark this section').first);
    expect(off.icon, Symbols.bookmark_rounded);
    expect(off.fill, 0);

    final heart = iconIn(t, find.byTooltip('Remove from favourites'));
    expect(heart.icon, Symbols.favorite_rounded);
    expect(heart.fill, 1);
    c.read(savedProvider.notifier).toggleFavourite('r1');
    await t.pump();
    final empty = iconIn(t, find.byTooltip('Add to favourites'));
    expect(empty.icon, Symbols.favorite_rounded);
    expect(empty.fill, 0);
  });

  testWidgets('Saved and Settings use thin-line icons', (t) async {
    final c = await open(t, Routes.saved);
    c.read(savedProvider.notifier).toggleBookmark('r1', 's01');
    c.read(savedProvider.notifier).toggleFavourite('r1');
    await t.pumpAndSettle();
    expectThinLineIcons(t, 'Saved');

    await open(t, Routes.settings);
    expectThinLineIcons(t, 'Settings');
  });
}
