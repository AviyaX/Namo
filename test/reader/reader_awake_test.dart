import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/reader/screen_awake.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_chant_player.dart';
import '../support/fake_screen_awake.dart';
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

final _scrollPlay = find.byKey(const ValueKey('reader-play'));
final _audioPlay = find.byKey(const ValueKey('audio-play'));

ScrollController scroll(WidgetTester t) =>
    t.state<ReaderBodyState>(find.byType(ReaderBody)).controller;

Future<void> runFor(WidgetTester t, Duration time) async {
  const frame = Duration(milliseconds: 16);
  for (var passed = Duration.zero; passed < time; passed += frame) {
    await t.pump(frame);
  }
}

Future<void> tap(WidgetTester t, Finder f) async {
  await t.tap(f);
  await t.pump();
}

Future<ProviderContainer> open(
  WidgetTester t,
  FakeScreenAwake awake, {
  String? location,
  FakeChantPlayer? player,
}) async {
  await pumpApp(
    t,
    overrides: [
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      if (player != null) ...[
        audioCatalogueProvider.overrideWithValue(_One()),
        chantPlayerProvider.overrideWith((ref) {
          ref.onDispose(player.dispose);
          return player;
        }),
      ],
    ],
    location: location ?? Routes.reader('r1'),
    screenAwake: awake,
  );
  return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
}

void main() {
  testWidgets('auto-scroll holds the screen on; pausing releases it', (
    t,
  ) async {
    final awake = FakeScreenAwake();
    await open(t, awake);
    expect(awake.calls, isEmpty);

    await tap(t, _scrollPlay);
    expect(awake.calls, ['hold']);
    await runFor(t, const Duration(milliseconds: 500));
    expect(awake.calls, ['hold']);

    await tap(t, _scrollPlay);
    expect(awake.calls, ['hold', 'release']);

    // A touch on the text pauses, and releases, too.
    await tap(t, _scrollPlay);
    expect(awake.held, isTrue);
    await t.tap(find.byType(ReaderBody));
    await t.pump();
    expect(awake.calls, ['hold', 'release', 'hold', 'release']);
    expect(t.takeException(), isNull);
  });

  testWidgets('reaching the end releases the screen', (t) async {
    final awake = FakeScreenAwake();
    await open(t, awake, location: Routes.reader('r1', sectionId: 's03'));
    final c = scroll(t);
    c.jumpTo(c.position.maxScrollExtent - 5);
    await t.pump();
    await tap(t, _scrollPlay);
    expect(awake.held, isTrue);
    await runFor(t, const Duration(seconds: 1));
    expect(c.offset, c.position.maxScrollExtent);
    expect(awake.calls, ['hold', 'release']);
  });

  testWidgets('leaving the reader releases the screen', (t) async {
    final awake = FakeScreenAwake();
    await open(t, awake);
    await tap(t, _scrollPlay);
    await runFor(t, const Duration(milliseconds: 500));
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(find.byType(ReaderBody), findsNothing);
    expect(awake.calls, ['hold', 'release']);
    expect(t.takeException(), isNull);
  });

  testWidgets('going to the background releases the screen', (t) async {
    final awake = FakeScreenAwake();
    await open(t, awake);
    await tap(t, _scrollPlay);
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await t.pump();
    expect(awake.calls, ['hold', 'release']);
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(awake.calls, ['hold', 'release']);
  });

  testWidgets('a playing recording holds the screen on until both it and '
      'the scroll stop', (t) async {
    final awake = FakeScreenAwake();
    final player = FakeChantPlayer();
    await open(t, awake, player: player);

    await tap(t, _audioPlay);
    expect(player.state.status, ChantStatus.playing);
    expect(awake.calls, ['hold']);

    // Scroll joins, then stops: the recording still plays.
    await tap(t, _scrollPlay);
    await tap(t, _scrollPlay);
    expect(awake.calls, ['hold']);

    await tap(t, _audioPlay);
    expect(awake.calls, ['hold', 'release']);

    // Playing to the end releases it.
    await tap(t, _audioPlay);
    expect(awake.held, isTrue);
    player.advance(const Duration(seconds: 30));
    await t.pump();
    expect(player.state.status, ChantStatus.completed);
    expect(awake.calls, ['hold', 'release', 'hold', 'release']);
    expect(t.takeException(), isNull);
  });

  test('a failing plugin never throws', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // No platform answers in a test, so the plugin's calls fail.
    const awake = WakelockScreenAwake();
    await expectLater(awake.hold(), completes);
    await expectLater(awake.release(), completes);
  });
}
