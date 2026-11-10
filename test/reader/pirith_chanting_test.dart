import 'dart:async';

import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../support/fake_chant_player.dart';

final _play = find.byKey(const ValueKey('chant-play'));
final _restart = find.byKey(const ValueKey('chant-restart'));
final _scrollButton = find.byKey(const ValueKey('reader-autoscroll'));
final _next = find.byKey(const ValueKey('reader-next'));
final _slider = find.byType(Slider);

String _scrollTip(WidgetTester t) => t
    .widget<Tooltip>(
      find.descendant(of: _scrollButton, matching: find.byType(Tooltip)),
    )
    .message!;

String _chantTip(WidgetTester t) => t.widget<Tooltip>(_play).message!;

Future<Recording> _recording(WidgetTester t, String id) async {
  final lib = await realLibrary(t);
  return ContentAudioCatalogue(lib).recordingFor(id)!;
}

Future<FakeChantPlayer> _open(
  WidgetTester t, {
  FakeChantPlayer? player,
  AppSettings settings = const AppSettings(),
  Size size = const Size(390, 844),
  double scale = 1.0,
  bool? dark,
}) async {
  final p = player ?? FakeChantPlayer();
  await openReal(
    t,
    Routes.reader(mangalaReadingId),
    player: p,
    settings: settings,
    size: size,
    deviceTextScale: scale,
    dark: dark,
  );
  return p;
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('nothing is loaded on opening; the first play loads once', (
    t,
  ) async {
    final player = await _open(t);
    final recording = await _recording(t, mangalaReadingId);
    expect(recording.timed, isTrue);
    expect(player.loaded, isEmpty);
    expect(_chantTip(t), 'Play chanting');

    await t.tap(_play);
    await t.pump();
    expect(player.loaded.map((r) => r.asset), [recording.asset]);
    expect(player.state.status, ChantStatus.playing);
    expect(_chantTip(t), 'Pause chanting');

    await t.tap(_play);
    await t.pump();
    expect(player.state.status, ChantStatus.paused);
    expect(_chantTip(t), 'Play chanting');

    await t.tap(_play);
    await t.pump();
    expect(player.state.status, ChantStatus.playing);
    expect(player.loaded, hasLength(1));
  });

  testWidgets('a pirith bar has its five controls', (
    t,
  ) async {
    await _open(t);
    for (final tip in [
      'Previous pirith',
      'Start auto-scroll',
      'Play chanting',
      'Restart chanting',
      'Next pirith',
    ]) {
      expect(find.byTooltip(tip), findsOneWidget, reason: tip);
    }
    expect(_slider, findsOneWidget);
    expect(t.widget<Slider>(_slider).onChanged, isNull, reason: 'not loaded');
  });

  testWidgets('Buddha Wandanawa has no chanting controls', (t) async {
    await openReal(t, Routes.reader(realReadingId));
    expect(find.byKey(const ValueKey('reader-play')), findsOneWidget);
    expect(_play, findsNothing);
    expect(_slider, findsNothing);
    expect(_scrollButton, findsNothing);
  });

  testWidgets('the slider and the time follow the player; a drag seeks once', (
    t,
  ) async {
    final player = await _open(t);
    await t.tap(_play);
    await t.pump();
    expect(find.text('0:00'), findsOneWidget);
    player.advance(const Duration(seconds: 5));
    await t.pump();
    expect(find.text('0:05'), findsOneWidget);
    expect(t.widget<Slider>(_slider).value, 5000);

    final g = await t.startGesture(t.getCenter(_slider));
    await g.moveBy(const Offset(4, 0));
    await t.pump();
    expect(player.state.position, const Duration(seconds: 5), reason: 'held');
    await g.up();
    await t.pump();
    // Half of the 20 seconds, within a pixel's worth.
    expect(player.state.position.inSeconds, inInclusiveRange(8, 12));
  });

  testWidgets('restart plays again from the start, and waits for a load', (
    t,
  ) async {
    final player = await _open(t);
    await t.tap(_restart, warnIfMissed: false);
    await t.pump();
    expect(player.loaded, isEmpty);
    expect(player.state.status, ChantStatus.idle);
    await t.tap(_play);
    await t.pump();
    player.advance(const Duration(seconds: 7));
    await t.pump();
    await t.tap(_restart);
    await t.pump();
    expect(player.state.position, Duration.zero);
    expect(player.state.status, ChantStatus.playing);
  });

  testWidgets('chanting then auto-scroll: only auto-scroll runs', (t) async {
    final player = await _open(t);
    await t.tap(_play);
    await t.pump();
    expect(player.state.status, ChantStatus.playing);
    await t.tap(_scrollButton);
    await t.pump();
    expect(player.state.status, ChantStatus.paused);
    expect(_scrollTip(t), 'Pause auto-scroll');
  });

  testWidgets('auto-scroll then chanting: only chanting runs', (t) async {
    final player = await _open(t);
    await t.tap(_scrollButton);
    await t.pump();
    expect(_scrollTip(t), 'Pause auto-scroll');
    await t.tap(_play);
    await t.pump();
    expect(_scrollTip(t), 'Resume auto-scroll');
    expect(player.state.status, ChantStatus.playing);
    // And back: resuming the scroll stops the chanting again.
    await t.tap(_scrollButton);
    await t.pump();
    expect(_scrollTip(t), 'Pause auto-scroll');
    expect(player.state.status, ChantStatus.paused);
  });

  testWidgets('autoScrollWithAudio does not start the scroll of a chant', (
    t,
  ) async {
    final player = await _open(
      t,
      settings: const AppSettings(autoScrollWithAudio: true),
    );
    await t.tap(_play);
    await t.pump();
    expect(player.state.status, ChantStatus.playing);
    expect(_scrollTip(t), 'Start auto-scroll');
  });

  testWidgets('autoScrollWithAudio still starts it for an untimed recording', (
    t,
  ) async {
    await openReal(
      t,
      Routes.reader(realReadingId),
      audio: true,
      settings: const AppSettings(autoScrollWithAudio: true),
    );
    await t.tap(find.byKey(const ValueKey('audio-play')));
    await t.pump();
    expect(
      t.widget<Tooltip>(find.byKey(const ValueKey('reader-play'))).message,
      'Pause auto-scroll',
    );
  });

  testWidgets('a recording that fails: message shown, text and scroll stay', (
    t,
  ) async {
    final player = await _open(t, player: FakeChantPlayer(failOnLoad: true));
    await t.tap(_play);
    await t.pump();
    expect(player.loaded, hasLength(1));
    expect(find.text('The recording could not be played.'), findsOneWidget);
    expect(_slider, findsNothing);
    final reading = (await realLibrary(t)).reading(mangalaReadingId)!;
    expect(find.text(reading.title), findsWidgets);
    await t.tap(_scrollButton);
    await t.pump();
    expect(_scrollTip(t), 'Pause auto-scroll');
  });

  testWidgets('Next pirith while playing pauses; the next is not loaded', (
    t,
  ) async {
    final player = await _open(t);
    await t.tap(_play);
    await t.pump();
    await t.tap(_next);
    await t.pumpAndSettle();
    expect(player.state.status, ChantStatus.paused);
    expect(player.loaded, hasLength(1));
    expect(_chantTip(t), 'Play chanting');
    // Its own recording, asked for at its own first play.
    await t.tap(_play);
    await t.pump();
    expect(player.loaded, hasLength(2));
    expect(player.loaded[1].readingId, isNot(player.loaded[0].readingId));
    expect(player.state.status, ChantStatus.playing);
  });

  testWidgets('going to the background pauses the chanting', (t) async {
    final player = await _open(t);
    await t.tap(_play);
    await t.pump();
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await t.pump();
    expect(player.state.status, ChantStatus.paused);
  });

  testWidgets('leaving the reader pauses the chanting', (t) async {
    final player = await _open(t);
    await t.tap(_play);
    await t.pump();
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(player.state.status, ChantStatus.paused);
  });

  testWidgets('a second tap while loading loads once', (t) async {
    final player = await _open(t, player: FakeChantPlayer()..gate = Completer());
    await t.tap(_play);
    await t.pump();
    expect(player.state.status, ChantStatus.loading);
    await t.tap(_play, warnIfMissed: false);
    await t.pump();
    player.gate!.complete();
    await t.pump();
    expect(player.loaded, hasLength(1));
    expect(player.state.status, ChantStatus.playing);
  });

  testWidgets('auto-scroll asked for while loading wins over the chanting', (
    t,
  ) async {
    final player = await _open(t, player: FakeChantPlayer()..gate = Completer());
    await t.tap(_play);
    await t.pump();
    await t.tap(_scrollButton);
    await t.pump();
    expect(_scrollTip(t), 'Pause auto-scroll');
    player.gate!.complete();
    await t.pump();
    expect(player.state.status, ChantStatus.ready);
    expect(_scrollTip(t), 'Pause auto-scroll');
    expect(_chantTip(t), 'Play chanting');
  });

  testWidgets('Next pirith while loading: the old one never starts', (t) async {
    final player = await _open(t, player: FakeChantPlayer()..gate = Completer());
    await t.tap(_play);
    await t.pump();
    await t.tap(_next);
    // The load ends while the old reader is still on the stack.
    await t.pump(const Duration(milliseconds: 20));
    player.gate!.complete();
    await t.pumpAndSettle();
    expect(player.state.status, isNot(ChantStatus.playing));
    expect(_chantTip(t), 'Play chanting');
  });

  testWidgets('the old reader leaving does not silence the next pirith', (
    t,
  ) async {
    final player = await _open(t);
    await t.tap(_play);
    await t.pump();
    await t.tap(_next);
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(_play);
    await t.pump();
    await t.pumpAndSettle();
    expect(player.state.status, ChantStatus.playing);
    expect(_chantTip(t), 'Pause chanting');
  });

  testWidgets('leaving a reader with an untimed recording pauses it', (
    t,
  ) async {
    final player = FakeChantPlayer();
    await openReal(
      t,
      Routes.reader(realReadingId),
      audio: true,
      player: player,
    );
    await t.tap(find.byKey(const ValueKey('audio-play')));
    await t.pump();
    expect(player.state.status, ChantStatus.playing);
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(player.state.status, ChantStatus.paused);
  });

  testWidgets('after a failure, play asks again and plays', (t) async {
    final player = await _open(t, player: FakeChantPlayer(failOnLoad: true));
    await t.tap(_play);
    await t.pump();
    expect(find.text('The recording could not be played.'), findsOneWidget);
    player.failOnLoad = false;
    await t.tap(_play);
    await t.pump();
    expect(player.loaded, hasLength(2));
    expect(player.state.status, ChantStatus.playing);
    expect(find.text('The recording could not be played.'), findsNothing);
  });

  for (final dark in [false, true]) {
    for (final shape in [
      (const Size(320, 568), 2.0),
      (const Size(1280, 800), 1.0),
    ]) {
      testWidgets('layout and guidelines: dark $dark, ${shape.$1}, '
          'text ${shape.$2}', (t) async {
        final handle = t.ensureSemantics();
        await _open(t, size: shape.$1, scale: shape.$2, dark: dark);
        await t.tap(_play);
        await t.pump();
        expect(t.takeException(), isNull);
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  }
}
