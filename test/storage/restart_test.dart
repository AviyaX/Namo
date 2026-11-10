import 'dart:async';

import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
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
