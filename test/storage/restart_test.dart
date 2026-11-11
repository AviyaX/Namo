import 'dart:async';
import 'dart:convert';

import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/flows/flows.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';

/// A new app start: new providers on a new store over the same saved values.
Future<ProviderContainer> restart() async {
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(SharedPrefsKeyValueStore(prefs)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// One store fails inside the future, the other before returning one.
class _FailingStore implements KeyValueStore {
  @override
  String? read(String key) => null;

  _FailingStore({required this.synchronously});

  final bool synchronously;

  @override
  Future<void> write(String key, String value) {
    if (synchronously) throw Exception('no disk');
    return Future.error(Exception('disk full'));
  }

  @override
  Future<void> remove(String key) async => throw Exception('disk full');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('settings, bookmarks, favourites, position and progress survive a '
      'restart', () async {
    final first = await restart();
    first.read(settingsProvider.notifier)
      ..toggleLanguage(ReadingLanguage.sinhala)
      ..toggleLanguage(ReadingLanguage.english)
      ..setLayout(TwoLanguageLayout.section)
      ..setFontScale(1.3)
      ..setLineSpacing(2.0)
      ..setScrollSpeed(36)
      ..setAutoScrollWithAudio(true)
      ..setThemeMode(ThemeMode.dark);
    first.read(savedProvider.notifier)
      ..toggleBookmark('r1', 's02')
      ..toggleFavourite('r1');
    first
        .read(positionProvider.notifier)
        .save(
          const ReadingPosition(
            readingId: 'r1',
            sectionId: 's02',
            verseId: 's02-v1',
            fraction: 0.25,
          ),
          0.4,
        );
    // Let the writes finish before "closing" the app.
    await Future<void>.delayed(Duration.zero);

    final second = await restart();
    final s = second.read(settingsProvider);
    expect(s.languages.languages, [
      ReadingLanguage.pali,
      ReadingLanguage.english,
    ]);
    expect(s.layout, TwoLanguageLayout.section);
    expect(s.fontScale, 1.3);
    expect(s.lineSpacing, 2.0);
    expect(s.scrollSpeed, 36);
    expect(s.autoScrollWithAudio, isTrue);
    expect(s.themeMode, ThemeMode.dark);

    final saved = second.read(savedProvider);
    expect(saved.bookmarks, [
      const Bookmark(readingId: 'r1', sectionId: 's02'),
    ]);
    expect(saved.favourites, {'r1'});

    final pos = second.read(positionProvider);
    expect(pos.lastReadingId, 'r1');
    final p = pos.byReading['r1']!;
    expect(p.position.sectionId, 's02');
    expect(p.position.verseId, 's02-v1');
    expect(p.position.fraction, 0.25);
    expect(p.progress, 0.4);
  });

  test('flows, their order and each flow\'s place survive a restart', () async {
    const a = FlowRef(readingId: 'r1', sectionId: 's01');
    const b = FlowRef(readingId: 'r1', sectionId: 's02');
    const c = FlowRef(readingId: 'r1', sectionId: 's03');
    final first = await restart();
    final flows = first.read(flowsProvider.notifier);
    flows.create('Morning');
    flows
      ..add('flow-1', a)
      ..add('flow-1', b)
      ..add('flow-1', c)
      ..move('flow-1', 2, 0);
    flows.create('Gone');
    flows.create('  Evening  ');
    flows
      ..add('flow-3', b)
      ..delete('flow-2');
    for (final (id, section, fraction) in [
      ('flow-1', 'r1~s01', 0.25),
      ('flow-3', 'r1~s02', 0.5),
    ]) {
      first
          .read(positionProvider.notifier)
          .save(
            ReadingPosition(
              readingId: id,
              sectionId: section,
              verseId: '$section-v1',
              fraction: fraction,
            ),
            fraction,
          );
    }
    await Future<void>.delayed(Duration.zero);

    final second = await restart();
    final state = second.read(flowsProvider);
    expect(state.flows, const [
      Flow(id: 'flow-1', name: 'Morning', sections: [c, a, b]),
      Flow(id: 'flow-3', name: 'Evening', sections: [b]),
    ]);
    // The deleted flow's id is not given again.
    expect(state.nextNumber, 4);
    expect(second.read(flowsProvider.notifier).create('').id, 'flow-4');

    final pos = second.read(positionProvider);
    expect(pos.lastReadingId, 'flow-3');
    expect(pos.byReading['flow-1']!.position.sectionId, 'r1~s01');
    expect(pos.byReading['flow-1']!.position.verseId, 'r1~s01-v1');
    expect(pos.byReading['flow-1']!.position.fraction, 0.25);
    expect(pos.byReading['flow-3']!.position.sectionId, 'r1~s02');
    expect(pos.byReading['flow-3']!.progress, 0.5);
  });

  for (final damaged in ['{', 'not json', '[]', '"flows"', '{"flows": 5}']) {
    test('flows saved as damaged text ($damaged) start empty and leave the '
        'other saved data intact', () async {
      SharedPreferences.setMockInitialValues({
        flowsKey: damaged,
        settingsKey: '{"fontScale": 1.3}',
        savedKey: '{"favourites": ["r1"]}',
        positionKey:
            '{"byReading": {"r1": {"position": {"readingId": "r1", '
            '"sectionId": "s02", "fraction": 0.5}, "progress": 0.5}}, '
            '"lastReadingId": "r1"}',
      });
      final c = await restart();
      expect(c.read(flowsProvider).flows, isEmpty);
      expect(c.read(flowsProvider).nextNumber, 1);
      expect(c.read(settingsProvider).fontScale, 1.3);
      expect(c.read(savedProvider).favourites, {'r1'});
      expect(c.read(positionProvider).lastReadingId, 'r1');
      expect(c.read(positionProvider).byReading['r1']!.progress, 0.5);
    });
  }

  testWidgets('the app starts with damaged flows: no flows in the Library or '
      'on Home', (t) async {
    SharedPreferences.setMockInitialValues({flowsKey: '{"flows": [1, '});
    final prefs = await SharedPreferences.getInstance();
    for (final at in [Routes.home, Routes.library]) {
      await t.pumpWidget(const SizedBox());
      await pumpApp(
        t,
        overrides: [
          contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
          keyValueStoreProvider.overrideWithValue(
            SharedPrefsKeyValueStore(prefs),
          ),
        ],
        location: at,
      );
      expect(t.takeException(), isNull, reason: at);
      expect(find.text('Your flows'), findsNothing, reason: at);
    }
    expect(find.text('Make your own flow'), findsOneWidget);
  });

  test('settings, bookmarks and places saved before flows existed still load, '
      'and making flows does not rewrite them', () async {
    // Written in the format the app used before flows.
    const settings =
        '{"languages": ["pi", "en"], "layout": "section", "fontScale": 1.3, '
        '"lineSpacing": 2.0, "scrollSpeed": 36, "autoScrollWithAudio": true, '
        '"themeMode": "dark"}';
    const saved =
        '{"bookmarks": [{"readingId": "r1", "sectionId": "s02"}], '
        '"favourites": ["r1"]}';
    const position =
        '{"byReading": {"r1": {"position": {"readingId": "r1", '
        '"sectionId": "s02", "verseId": "s02-v1", "fraction": 0.25}, '
        '"progress": 0.4}}, "lastReadingId": "r1"}';
    SharedPreferences.setMockInitialValues({
      settingsKey: settings,
      savedKey: saved,
      positionKey: position,
    });
    final c = await restart();
    final s = c.read(settingsProvider);
    expect(s.languages.languages, [
      ReadingLanguage.pali,
      ReadingLanguage.english,
    ]);
    expect(s.layout, TwoLanguageLayout.section);
    expect(s.fontScale, 1.3);
    expect(s.lineSpacing, 2.0);
    expect(s.scrollSpeed, 36);
    expect(s.autoScrollWithAudio, isTrue);
    expect(s.themeMode, ThemeMode.dark);
    expect(c.read(savedProvider).bookmarks, [
      const Bookmark(readingId: 'r1', sectionId: 's02'),
    ]);
    expect(c.read(savedProvider).favourites, {'r1'});
    final p = c.read(positionProvider).byReading['r1']!;
    expect(p.position.verseId, 's02-v1');
    expect(p.position.fraction, 0.25);
    expect(p.progress, 0.4);
    expect(c.read(flowsProvider).flows, isEmpty);

    final flows = c.read(flowsProvider.notifier);
    final made = flows.create('Morning');
    flows
      ..add(made.id, const FlowRef(readingId: 'r1', sectionId: 's01'))
      ..rename(made.id, 'Evening')
      ..delete(made.id);
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(settingsKey), settings);
    expect(prefs.getString(savedKey), saved);
    expect(prefs.getString(positionKey), position);
  });

  testWidgets('a flow reopens at its saved section after a restart', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({
      flowsKey: jsonEncode(
        const FlowsState(
          flows: [
            Flow(
              id: 'flow-1',
              name: 'Flow one',
              sections: [
                FlowRef(readingId: 'r1', sectionId: 's03'),
                FlowRef(readingId: 'r1', sectionId: 's01'),
                FlowRef(readingId: 'r1', sectionId: 's02'),
              ],
            ),
          ],
          nextNumber: 2,
        ).toJson(),
      ),
    });
    Future<void> open() async {
      final prefs = await SharedPreferences.getInstance();
      await t.pumpWidget(const SizedBox());
      await pumpApp(
        t,
        overrides: [
          contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
          keyValueStoreProvider.overrideWithValue(
            SharedPrefsKeyValueStore(prefs),
          ),
        ],
        location: Routes.reader('flow-1'),
      );
    }

    double distanceFromTop(String key) =>
        t.getTopLeft(find.byKey(ValueKey(key))).dy -
        t.getTopLeft(find.byType(ReaderBody)).dy;

    await open();
    final controller = t
        .state<ReaderBodyState>(find.byType(ReaderBody))
        .controller;
    controller.jumpTo(controller.offset + distanceFromTop('heading-r1~s01'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));

    await open();
    expect(distanceFromTop('heading-r1~s01').abs(), lessThan(2));
    expect(t.takeException(), isNull);
  });

  test('each damaged key falls back alone', () async {
    SharedPreferences.setMockInitialValues({
      savedKey:
          '{"bookmarks": [{"readingId": "r1"}, '
          '{"readingId": "r1", "sectionId": "s02"}, 5], "favourites": "x"}',
      positionKey: '[]',
      settingsKey: '{',
    });
    final c = await restart();
    final saved = c.read(savedProvider);
    expect(saved.bookmarks, [
      const Bookmark(readingId: 'r1', sectionId: 's02'),
    ]);
    expect(saved.favourites, isEmpty);
    expect(c.read(positionProvider).byReading, isEmpty);
    expect(c.read(positionProvider).lastReadingId, isNull);
    final s = c.read(settingsProvider);
    expect(s.fontScale, const AppSettings().fontScale);
    expect(s.languages.languages, LanguageSelection.initial.languages);

    // Good keys are still read when a neighbour is damaged.
    SharedPreferences.setMockInitialValues({
      savedKey: '{"favourites": ["r1"]}',
      settingsKey: '{"fontScale": 1.3}',
      positionKey: 'not json',
    });
    final d = await restart();
    expect(d.read(savedProvider).favourites, {'r1'});
    expect(d.read(settingsProvider).fontScale, 1.3);
    expect(d.read(positionProvider).byReading, isEmpty);
  });

  test('a store whose write fails does not surface an error', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      for (final store in [
        _FailingStore(synchronously: true),
        _FailingStore(synchronously: false),
      ]) {
        final c = ProviderContainer(
          overrides: [keyValueStoreProvider.overrideWithValue(store)],
        );
        addTearDown(c.dispose);
        c.read(settingsProvider.notifier).setFontScale(1.2);
        c.read(savedProvider.notifier)
          ..toggleBookmark('r1', 's01')
          ..toggleFavourite('r1');
        c
            .read(positionProvider.notifier)
            .save(
              const ReadingPosition(
                readingId: 'r1',
                sectionId: 's01',
                fraction: 0,
              ),
              0.1,
            );
        await Future<void>.delayed(Duration.zero);
        // The app state still changes in memory.
        expect(c.read(settingsProvider).fontScale, 1.2);
        expect(c.read(savedProvider).favourites, {'r1'});
      }
    }, (e, _) => errors.add(e));
    await Future<void>.delayed(Duration.zero);
    expect(errors, isEmpty);
  });

  test(
    'start-up falls back to the in-memory store when saved storage fails',
    () async {
      final ok = await openKeyValueStore(
        load: () async => await SharedPreferences.getInstance(),
      );
      expect(ok, isA<SharedPrefsKeyValueStore>());

      final fallback = await openKeyValueStore(
        load: () async => throw Exception('storage blocked'),
      );
      expect(fallback, isA<InMemoryKeyValueStore>());
    },
  );

  testWidgets('the app starts and opens the reader with a bookmark for a '
      'section that no longer exists', (t) async {
    SharedPreferences.setMockInitialValues({
      savedKey:
          '{"bookmarks": [{"readingId": "r1", "sectionId": "s99"}, '
          '{"readingId": "gone", "sectionId": "s01"}, '
          '{"readingId": "r1", "sectionId": "s02"}], '
          '"favourites": ["gone", "r1"]}',
      positionKey:
          '{"byReading": {"r1": {"position": {"readingId": "r1", '
          '"sectionId": "s99", "verseId": "x", "fraction": 0.5}, '
          '"progress": 0.5}}, "lastReadingId": "r1"}',
    });
    final prefs = await SharedPreferences.getInstance();
    await pumpApp(
      t,
      overrides: [
        contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
        keyValueStoreProvider.overrideWithValue(
          SharedPrefsKeyValueStore(prefs),
        ),
      ],
      location: Routes.reader('r1'),
    );
    expect(find.byType(ReaderBody), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the reader reopens at the saved verse after a restart', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    Future<ProviderContainer> open() async {
      final prefs = await SharedPreferences.getInstance();
      await t.pumpWidget(const SizedBox());
      await pumpApp(
        t,
        overrides: [
          contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
          keyValueStoreProvider.overrideWithValue(
            SharedPrefsKeyValueStore(prefs),
          ),
        ],
        location: Routes.reader('r1'),
      );
      return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    }

    double distanceFromTop(String key) =>
        t.getTopLeft(find.byKey(ValueKey(key))).dy -
        t.getTopLeft(find.byType(ReaderBody)).dy;

    await open();
    final controller = t
        .state<ReaderBodyState>(find.byType(ReaderBody))
        .controller;
    controller.jumpTo(controller.offset + distanceFromTop('verse-s02-v1-pi'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));

    await open();
    expect(distanceFromTop('verse-s02-v1-pi').abs(), lessThan(2));
    expect(t.takeException(), isNull);
  });
}
