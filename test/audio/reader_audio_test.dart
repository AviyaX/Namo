import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/audio_controls.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_chant_player.dart';
import '../support/pump_app.dart';
import '../support/test_content.dart';

const _placeholderLabel = 'Development placeholder tone (not a chant)';
const _failed = 'The recording could not be played.';

class _One implements AudioCatalogue {
  _One({required this.placeholder});
  final bool placeholder;
  @override
  Recording? recordingFor(String readingId) => Recording(
        readingId: readingId,
        asset: 'assets/audio/test.mp3',
        label: placeholder ? _placeholderLabel : 'A test recording',
        placeholder: placeholder,
      );
}

class _None implements AudioCatalogue {
  @override
  Recording? recordingFor(String readingId) => null;
}

final _audioPlay = find.byKey(const ValueKey('audio-play'));
final _audioRestart = find.byKey(const ValueKey('audio-restart'));
final _scrollPlay = find.byKey(const ValueKey('reader-play'));

Future<ProviderContainer> open(
  WidgetTester t, {
  AudioCatalogue? catalogue,
  FakeChantPlayer? player,
  List<Override> extra = const [],
}) async {
  await pumpApp(
    t,
    overrides: [
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      audioCatalogueProvider.overrideWithValue(
        catalogue ?? _One(placeholder: false),
      ),
      if (player != null)
        chantPlayerProvider.overrideWith((ref) {
          ref.onDispose(player.dispose);
          return player;
        }),
      ...extra,
    ],
    location: Routes.reader('r1'),
  );
  return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
}

String audioLabel(WidgetTester t) => t.widget<IconButton>(_audioPlay).tooltip!;
String scrollLabel(WidgetTester t) =>
    t.widget<IconButton>(_scrollPlay).tooltip!;

ScrollController scroll(WidgetTester t) =>
    t.state<ReaderBodyState>(find.byType(ReaderBody)).controller;

Future<void> runFor(WidgetTester t, Duration time) async {
  const frame = Duration(milliseconds: 16);
  for (var passed = Duration.zero; passed < time; passed += frame) {
    await t.pump(frame);
  }
}

void main() {
  test('times are shown as m:ss, an unknown one as –:––', () {
    expect(formatTime(Duration.zero), '0:00');
    expect(formatTime(const Duration(seconds: 75)), '1:15');
    expect(formatTime(const Duration(minutes: 12, seconds: 5)), '12:05');
    expect(formatTime(null), '–:––');
  });

  testWidgets('with no recording the reader shows no audio controls and '
      'never builds a player', (t) async {
    var built = 0;
    await open(t, catalogue: _None(), extra: [
      chantPlayerProvider.overrideWith((ref) {
        built++;
        return FakeChantPlayer();
      }),
    ]);
    expect(find.byType(AudioControls), findsNothing);
    expect(_audioPlay, findsNothing);
    expect(built, 0);
    expect(_scrollPlay, findsOneWidget);
  });

  testWidgets('with a recording: play, pause, resume, restart', (t) async {
    final player = FakeChantPlayer();
    await open(t, player: player);
    expect(find.byType(AudioControls), findsOneWidget);
    expect(player.loaded.single.asset, 'assets/audio/test.mp3');
    expect(audioLabel(t), 'Play recording');
    expect(find.text('0:00 / 0:20'), findsOneWidget);
    expect(find.text('A test recording'), findsNothing);

    for (final k in [_audioPlay, _audioRestart]) {
      final size = t.getSize(k);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(
      t.getSemantics(_audioPlay),
      isSemantics(tooltip: 'Play recording', isButton: true, isEnabled: true),
    );
    expect(
      t.getSemantics(_audioRestart),
      isSemantics(
        tooltip: 'Restart recording',
        isButton: true,
        isEnabled: true,
      ),
    );

    await t.tap(_audioPlay);
    await t.pump();
    expect(player.state.status, ChantStatus.playing);
    expect(audioLabel(t), 'Pause recording');
    player.advance(const Duration(seconds: 7));
    await t.pump();
    expect(find.text('0:07 / 0:20'), findsOneWidget);

    await t.tap(_audioPlay);
    await t.pump();
    expect(player.state.status, ChantStatus.paused);
    expect(audioLabel(t), 'Play recording');
    expect(find.text('0:07 / 0:20'), findsOneWidget);

    await t.tap(_audioPlay);
    await t.pump();
    expect(player.state.status, ChantStatus.playing);
    expect(player.state.position, const Duration(seconds: 7));
    expect(audioLabel(t), 'Pause recording');

    await t.tap(_audioRestart);
    await t.pump();
    expect(player.state.status, ChantStatus.playing);
    expect(player.state.position, Duration.zero);
    expect(find.text('0:00 / 0:20'), findsOneWidget);

    player.advance(const Duration(seconds: 30));
    await t.pump();
    expect(player.state.status, ChantStatus.completed);
    expect(audioLabel(t), 'Play recording');
    expect(find.text('0:20 / 0:20'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the placeholder is labelled as one', (t) async {
    await open(
      t,
      catalogue: _One(placeholder: true),
      player: FakeChantPlayer(),
    );
    expect(find.text(_placeholderLabel), findsOneWidget);
  });

  testWidgets('audio and auto-scroll run alone and together', (t) async {
    final player = FakeChantPlayer();
    await open(t, player: player);

    // Audio alone.
    await t.tap(_audioPlay);
    await t.pump();
    expect(scrollLabel(t), 'Start auto-scroll');
    final before = scroll(t).offset;
    await runFor(t, const Duration(seconds: 1));
    expect(scroll(t).offset, before);

    // Both.
    await t.tap(_scrollPlay);
    await t.pump();
    expect(scrollLabel(t), 'Pause auto-scroll');
    expect(audioLabel(t), 'Pause recording');
    final mid = scroll(t).offset;
    await runFor(t, const Duration(seconds: 1));
    expect(scroll(t).offset, greaterThan(mid));
    expect(player.state.status, ChantStatus.playing);

    // Scroll alone: pausing audio leaves scrolling.
    await t.tap(_audioPlay);
    await t.pump();
    expect(player.state.status, ChantStatus.paused);
    expect(scrollLabel(t), 'Pause auto-scroll');
    final again = scroll(t).offset;
    await runFor(t, const Duration(seconds: 1));
    expect(scroll(t).offset, greaterThan(again));

    // Pausing scroll leaves audio running.
    await t.tap(_audioPlay);
    await t.pump();
    await t.tap(_scrollPlay);
    await t.pump();
    expect(scrollLabel(t), 'Resume auto-scroll');
    expect(player.state.status, ChantStatus.playing);
    expect(t.takeException(), isNull);
  });

  testWidgets('"start auto-scroll with audio" starts the scroll when audio '
      'starts, and only then', (t) async {
    final player = FakeChantPlayer();
    final c = await open(t, player: player);
    c.read(settingsProvider.notifier).setAutoScrollWithAudio(true);
    await t.pump();

    // Nothing starts it before the audio does.
    expect(scrollLabel(t), 'Start auto-scroll');
    await t.tap(_audioPlay);
    await t.pump();
    expect(scrollLabel(t), 'Pause auto-scroll');

    // Pausing audio does not stop it; pausing the scroll does not stop audio.
    await t.tap(_audioPlay);
    await t.pump();
    expect(scrollLabel(t), 'Pause auto-scroll');
    await t.tap(_scrollPlay);
    await t.pump();
    expect(scrollLabel(t), 'Resume auto-scroll');

    // Resuming the audio starts the scroll again.
    await t.tap(_audioPlay);
    await t.pump();
    expect(scrollLabel(t), 'Pause auto-scroll');

    // Scroll paused while audio plays: time passing does not restart it.
    await t.tap(_scrollPlay);
    await t.pump();
    player.advance(const Duration(seconds: 1));
    await t.pump();
    expect(scrollLabel(t), 'Resume auto-scroll');
    expect(t.takeException(), isNull);
  });

  testWidgets('with the setting off, audio does not start the scroll', (
    t,
  ) async {
    await open(t, player: FakeChantPlayer());
    await t.tap(_audioPlay);
    await t.pump();
    expect(scrollLabel(t), 'Start auto-scroll');
  });

  testWidgets('a recording that fails to load shows the message; '
      'auto-scroll still works', (t) async {
    await open(t, player: FakeChantPlayer(failOnLoad: true));
    expect(find.text(_failed), findsOneWidget);
    expect(_audioPlay, findsNothing);
    expect(_audioRestart, findsNothing);

    await t.tap(_scrollPlay);
    await t.pump();
    expect(scrollLabel(t), 'Pause auto-scroll');
    final before = scroll(t).offset;
    await runFor(t, const Duration(seconds: 1));
    expect(scroll(t).offset, greaterThan(before));
    expect(t.takeException(), isNull);
  });

  testWidgets('going to the background pauses the audio', (t) async {
    final player = FakeChantPlayer();
    await open(t, player: player);
    await t.tap(_audioPlay);
    await t.pump();
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await t.pump();
    expect(player.state.status, ChantStatus.paused);
    expect(audioLabel(t), 'Play recording');
  });

  testWidgets('leaving the reader disposes the player', (t) async {
    final player = FakeChantPlayer();
    final c = await open(t, player: player);
    await t.tap(_audioPlay);
    await t.pump();
    c.read(routerProvider).go(Routes.contents('r1'));
    await t.pumpAndSettle();
    expect(find.byType(AudioControls), findsNothing);
    expect(player.disposed, isTrue);
    expect(t.takeException(), isNull);
  });
}
