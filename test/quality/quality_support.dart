import 'dart:convert';

import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/flows/flows.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_chant_player.dart';
import '../support/passages.dart';
import '../support/pump_app.dart';
import '../tipitaka/tipitaka_support.dart';

const realReadingId = 'namaskaraya';
const realCategoryId = 'cat-namaskaraya';
const pirithCategoryId = 'cat-pirith';
const mangalaReadingId = 'pirith-08-mahamangala';
const samanthaCategoryId = 'cat-samantha-patthana';
const spIntroductionId = 'sp-introduction';
const spVandanaId = 'sp-vandana';

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

/// The bundled content with only Buddha Wandanawa, for tests that are about
/// one topic (the bundled Library now has Pirith as a second topic).
Future<Library> buddhaOnlyLibrary(WidgetTester t) async {
  final lib = await realLibrary(t);
  return Library(categories: [lib.category(realCategoryId)!]);
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

/// Two flows saved over the bundled content, for [openReal]'s
/// `storeExtras`: flow-1 "Evening" (the first three sections of Buddha
/// Wandanawa, then a pirith), flow-2 "Morning" (the same pirith) and
/// flow-3 "Later" (empty).
Future<Map<String, String>> realFlowsStore(WidgetTester t) async {
  final lib = await realLibrary(t);
  final buddha = lib.reading(realReadingId)!;
  final pirith = lib.reading(mangalaReadingId)!;
  final chanted = FlowRef(
    readingId: pirith.id,
    sectionId: pirith.sections.single.id,
  );
  return {
    flowsKey: jsonEncode(
      FlowsState(
        flows: [
          Flow(
            id: 'flow-1',
            name: 'Evening',
            sections: [
              for (final s in buddha.sections.take(3))
                FlowRef(readingId: buddha.id, sectionId: s.id),
              chanted,
            ],
          ),
          Flow(id: 'flow-2', name: 'Morning', sections: [chanted]),
          const Flow(id: 'flow-3', name: 'Later'),
        ],
        nextNumber: 4,
      ).toJson(),
    ),
  };
}

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
/// [deviceTextScale] is the device's text size setting. [dark] picks the
/// theme: true or false stores Dark or Light (and sets the device to match);
/// left null, the theme is whatever [settings] holds (the app's default is
/// Dark) and the device is light. [withSaved] fills Saved with bookmarks and
/// a favourite.
/// [library] replaces the bundled content. [player] is the player the reader
/// gets (by default a fake, which fails to load when [audioFails]). [audio]
/// puts the placeholder recording on every reading.
/// [storeExtras] are extra saved values (a remembered reading place, say).
/// [overrides] are added to the app's provider overrides (a fixed clock, say).
/// [tipitaka] serves the Tripitaka's files (by default the made-up
/// [tinyTipitaka], parsed on the test's own clock).
Future<void> openReal(
  WidgetTester t,
  String location, {
  Size size = const Size(390, 844),
  double deviceTextScale = 1.0,
  bool? dark,
  AppSettings settings = const AppSettings(),
  bool withSaved = false,
  Library? library,
  bool audio = false,
  bool audioFails = false,
  ChantPlayer? player,
  List<Override> overrides = const [],
  Map<String, String> storeExtras = const {},
  bool settle = true,
  AssetBytes? tipitaka,
}) async {
  final lib = library ?? await realLibrary(t);
  t.platformDispatcher.textScaleFactorTestValue = deviceTextScale;
  t.platformDispatcher.platformBrightnessTestValue =
      (dark ?? false) ? Brightness.dark : Brightness.light;
  addTearDown(() {
    t.platformDispatcher.clearTextScaleFactorTestValue();
    t.platformDispatcher.clearPlatformBrightnessTestValue();
  });
  final store = InMemoryKeyValueStore();
  // The theme comes from the stored settings, not from the device. An
  // explicit [dark] sets it (Same as device is left to follow the device);
  // without one the caller's settings stand.
  final stored = dark == null || settings.themeMode == ThemeMode.system
      ? settings
      : settings.copyWith(themeMode: dark ? ThemeMode.dark : ThemeMode.light);
  await store.write(settingsKey, jsonEncode(stored.toJson()));
  for (final e in storeExtras.entries) {
    await store.write(e.key, e.value);
  }
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
  final chantPlayer = player ?? FakeChantPlayer(failOnLoad: audioFails);
  await pumpApp(
    t,
    overrides: [
      ...overrides,
      contentRepositoryProvider.overrideWithValue(
        _FixedRepository(lib),
      ),
      keyValueStoreProvider.overrideWithValue(store),
      tipitakaRepositoryProvider.overrideWithValue(
        TipitakaRepository(
          load: tipitaka ?? fakeAssets(tinyTipitaka()),
          inBackground: false,
        ),
      ),
      if (audio) audioCatalogueProvider.overrideWithValue(PlaceholderCatalogue()),
      // Never a real player: nothing makes a sound in a test.
      chantPlayerProvider.overrideWith((ref) {
        ref.onDispose(chantPlayer.dispose);
        return chantPlayer;
      }),
    ],
    location: location,
    size: size,
    settle: settle,
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

/// A pirith in the reader with the chanting playing (fake player, no sound)
/// and a phrase highlighted. With [pausedFollowing] a hand has then moved the
/// text, so the `Follow the chanting` pill shows.
Future<void> openChanting(
  WidgetTester t, {
  Size size = const Size(390, 844),
  double deviceTextScale = 1.0,
  bool? dark,
  bool pausedFollowing = false,
  String id = mangalaReadingId,
}) async {
  final lib = await realLibrary(t);
  final recording = ContentAudioCatalogue(lib).recordingFor(id)!;
  final times = recording.blockTimes.whereType<BlockTime>().toList();
  final player = FakeChantPlayer(
    length: times.last.end + const Duration(seconds: 2),
  );
  await openReal(
    t,
    Routes.reader(id),
    size: size,
    deviceTextScale: deviceTextScale,
    dark: dark,
    player: player,
  );
  await t.tap(find.byKey(const ValueKey('chant-play')));
  await t.pump();
  final middle = times[3];
  player.advance(
    middle.start + (middle.end - middle.start) ~/ 2 - player.state.position,
  );
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(markCount(t), greaterThan(0));
  if (pausedFollowing) {
    // Start near the top of the text: in a short window the floating bar
    // covers the middle of it.
    final text = t.getRect(find.byType(CustomScrollView));
    await t.dragFrom(
      Offset(text.center.dx, text.top + 40),
      const Offset(0, 60),
    );
    await t.pump();
    expect(find.byKey(const ValueKey('follow-chanting')), findsOneWidget);
  }
}
