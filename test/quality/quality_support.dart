import 'dart:convert';

import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_chant_player.dart';
import '../support/pump_app.dart';

const realReadingId = 'namaskaraya';
const realCategoryId = 'cat-namaskaraya';

/// The bundled families, loaded from assets/fonts so the tests measure text
/// with the real glyphs and not the test font.
Future<void> loadBundledFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  await load('NotoSansSinhala', ['NotoSansSinhala.ttf']);
  await load('NotoSerif', ['NotoSerif.ttf']);
  await load('Lora', ['Lora.ttf']);
  // The app points 'Roboto' at Lora (see pubspec.yaml).
  await load('Roboto', ['Lora.ttf']);
}

Library? _library;

/// The bundled content, read once.
Future<Library> realLibrary(WidgetTester t) async {
  return _library ??= (await t.runAsync(
    () => AssetContentRepository(rootBundle).load(),
  ))!;
}

/// Four categories, Latin placeholder text, one of them with two readings and
/// a long title, so that Home has several cards to lay out.
Library severalCategories() => Library(
  categories: [
    for (var i = 1; i <= 4; i++)
      Category(
        id: 'c$i',
        title: i == 2
            ? 'A category with a rather long title that has to wrap onto lines'
            : 'Category $i',
        subtitle: 'Subtitle $i',
        readings: [
          for (var j = 1; j <= (i == 2 ? 2 : 1); j++)
            Reading(
              id: 'r$i$j',
              title: 'Reading $i$j',
              sections: [
                for (var k = 1; k <= 12; k++)
                  Section(
                    id: 's$i$j$k',
                    number: k,
                    heading: 'Heading $k',
                    verses: [Verse(id: 's$i$j$k-v', paliSi: 'pali', sinhala: 'sinhala')],
                  ),
              ],
            ),
        ],
      ),
  ],
);

class PlaceholderCatalogue implements AudioCatalogue {
  @override
  Recording? recordingFor(String readingId) => Recording(
    readingId: readingId,
    asset: placeholderToneAsset,
    label: placeholderToneLabel,
    placeholder: true,
  );
}

/// Opens the app at [location] with the bundled content.
///
/// [deviceTextScale] is the device's text size setting, [dark] the device
/// theme. [withSaved] fills Saved with bookmarks and a favourite.
/// [library] replaces the bundled content. [audio] puts the placeholder
/// recording on every reading; [audioFails] makes the player fail to load it.
Future<void> openReal(
  WidgetTester t,
  String location, {
  Size size = const Size(390, 844),
  double deviceTextScale = 1.0,
  bool dark = false,
  AppSettings settings = const AppSettings(),
  bool withSaved = false,
  Library? library,
  bool audio = false,
  bool audioFails = false,
}) async {
  final lib = library ?? await realLibrary(t);
  t.platformDispatcher.textScaleFactorTestValue = deviceTextScale;
  t.platformDispatcher.platformBrightnessTestValue =
      dark ? Brightness.dark : Brightness.light;
  addTearDown(() {
    t.platformDispatcher.clearTextScaleFactorTestValue();
    t.platformDispatcher.clearPlatformBrightnessTestValue();
  });
  final store = InMemoryKeyValueStore();
  await store.write(settingsKey, jsonEncode(settings.toJson()));
  if (withSaved) {
    final sections = lib.categories.first.readings.first.sections;
    final readingId = lib.categories.first.readings.first.id;
    await store.write(
      savedKey,
      jsonEncode(
        SavedState(
          bookmarks: [
            for (final s in sections.take(3))
              Bookmark(readingId: readingId, sectionId: s.id),
          ],
          favourites: {readingId},
        ).toJson(),
      ),
    );
  }
  final player = FakeChantPlayer(failOnLoad: audioFails);
  await pumpApp(
    t,
    overrides: [
      contentRepositoryProvider.overrideWithValue(
        _FixedRepository(lib),
      ),
      keyValueStoreProvider.overrideWithValue(store),
      if (audio) audioCatalogueProvider.overrideWithValue(PlaceholderCatalogue()),
      if (audio)
        chantPlayerProvider.overrideWith((ref) {
          ref.onDispose(player.dispose);
          return player;
        }),
    ],
    location: location,
    size: size,
  );
}

class _FixedRepository implements ContentRepository {
  _FixedRepository(this.library);
  final Library library;
  @override
  Future<Library> load() async => library;
}

/// Scrolls the first vertical scrollable from top to bottom in steps of its
/// viewport, checking after each step that nothing threw.
Future<void> scrollThrough(WidgetTester t) async {
  final state = t.state<ScrollableState>(find.byType(Scrollable).first);
  final position = state.position;
  expect(t.takeException(), isNull, reason: 'at the top');
  final step = position.viewportDimension;
  var offset = 0.0;
  while (offset < position.maxScrollExtent) {
    offset = (offset + step).clamp(0.0, position.maxScrollExtent);
    position.jumpTo(offset);
    await t.pump();
    expect(t.takeException(), isNull, reason: 'at offset $offset');
  }
}
