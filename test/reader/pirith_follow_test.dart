
import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../design/palette_test.dart' show contrast;
import '../quality/quality_support.dart';
import '../support/fake_chant_player.dart';
import '../support/passages.dart';

const _alavakaId = 'pirith-25-alavaka-suttam';

final _play = find.byKey(const ValueKey('chant-play'));
final _scrollButton = find.byKey(const ValueKey('reader-autoscroll'));
final _blockActive = find.byKey(const ValueKey('block-active'));
final _followButton = find.byKey(const ValueKey('follow-chanting'));

/// Counts the seeks it is asked for.
class _SpyPlayer extends FakeChantPlayer {
  _SpyPlayer({super.length});

  final seeks = <Duration>[];

  @override
  Future<void> seek(Duration to) {
    seeks.add(to);
    return super.seek(to);
  }
}

class _Chant {
  _Chant(this.reading, this.recording, this.player);

  final Reading reading;
  final Recording recording;
  final _SpyPlayer player;

  List<Verse> get blocks => reading.sections.first.verses;

  Finder block(int i) => find.byKey(ValueKey('block-${blocks[i].id}'));
  /// The block's first passage, to tap.
  Finder text(int b) =>
      find.descendant(of: block(b), matching: passages).first;

  BlockTime time(int i) => recording.blockTimes[i]!;
  Duration get end => recording.blockTimes.whereType<BlockTime>().last.end;

  Duration middleOf(int i) =>
      time(i).start + (time(i).end - time(i).start) ~/ 2;

  /// Lets the recording run to [to] (forwards only).
  Future<void> advanceTo(WidgetTester t, Duration to) async {
    player.advance(to - player.state.position);
    await t.pump();
  }
}

Future<_Chant> _open(
  WidgetTester t, {
  String id = mangalaReadingId,
  Size size = const Size(390, 844),
  bool? dark,
  bool play = true,
  bool reducedMotion = false,
}) async {
  final lib = await realLibrary(t);
  final reading = lib.reading(id)!;
  final recording = ContentAudioCatalogue(lib).recordingFor(id)!;
  final last = recording.blockTimes.whereType<BlockTime>().last.end;
  final player = _SpyPlayer(length: last + const Duration(seconds: 2));
  if (reducedMotion) {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await openReal(t, Routes.reader(id), player: player, size: size, dark: dark);
  final chant = _Chant(reading, recording, player);
  if (play) {
    await t.tap(_play);
    await t.pump();
  }
  return chant;
}

/// The index of the block that [_blockActive] is in.
int _activeBlock(WidgetTester t, _Chant c) {
  expect(_blockActive, findsOneWidget);
  for (var i = 0; i < c.blocks.length; i++) {
    if (find
        .descendant(of: c.block(i), matching: _blockActive)
        .evaluate()
        .isNotEmpty) {
      return i;
    }
  }
  fail('the active block is not a block of the reading');
}

double _scrollOffset(WidgetTester t) =>
    t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

Rect _text(WidgetTester t) => t.getRect(find.byType(CustomScrollView));

/// How far the top of the line the phrase starts on is from one third down the text area.
double _offThird(WidgetTester t, double top) {
  final area = _text(t);
  return (top - area.top - area.height / 3).abs();
}

Future<void> _settleMotion(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('before play nothing is marked; a tap does nothing and loads '
      'nothing', (t) async {
    final c = await _open(t, play: false);
    expect(_blockActive, findsNothing);
    expect(markCount(t), 0);
    expect(
      find.descendant(
        of: c.block(0),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
      reason: 'no tap behaviour before the chanting has been started',
    );
    await t.tap(c.text(0));
    await t.pump();
    expect(c.player.loaded, isEmpty);
    expect(c.player.state.status, ChantStatus.idle);
    expect(c.player.seeks, isEmpty);
    expect(_blockActive, findsNothing);
  });

  testWidgets('the block and phrase being chanted are marked and never '
      'go back', (t) async {
    final c = await _open(t);
    await c.advanceTo(t, c.middleOf(3));
    await _settleMotion(t);
    expect(_activeBlock(t, c), 3);
    expect(markCount(t, c.block(3)), greaterThan(0));
    expect(markCount(t), markCount(t, c.block(3)));

    var last = 3;
    var position = c.player.state.position;
    while (position + const Duration(seconds: 1) < c.player.length) {
      position += const Duration(seconds: 1);
      await c.advanceTo(t, position);
      await t.pump(const Duration(milliseconds: 300));
      if (_blockActive.evaluate().isEmpty) continue; // between blocks' times
      final b = _activeBlock(t, c);
      expect(b, greaterThanOrEqualTo(last), reason: 'at $position');
      expect(markCount(t, c.block(b)), greaterThan(0), reason: 'at $position');
      expect(markCount(t), markCount(t, c.block(b)), reason: 'at $position');
      last = b;
    }
    expect(last, c.blocks.length - 1);
    // The recording ends: the highlight clears.
    await c.advanceTo(t, c.player.length);
    await t.pump();
    expect(c.player.state.status, ChantStatus.completed);
    expect(_blockActive, findsNothing);
    expect(markCount(t), 0);
  });

  testWidgets('the page follows: the active phrase sits a third of the way '
      'down', (t) async {
    final c = await _open(t);
    await c.advanceTo(t, c.middleOf(10));
    await _settleMotion(t);
    final active = _activeBlock(t, c);
    expect(active, 10);
    expect(_offThird(t, markTop(t, c.block(10))!), lessThan(24));

    // And on, into a block far from the first.
    await c.advanceTo(t, c.middleOf(25));
    await _settleMotion(t);
    expect(_activeBlock(t, c), 25);
    expect(_offThird(t, markTop(t, c.block(25))!), lessThan(24));
  });

  testWidgets('a hand on the text pauses following until it is asked for', (
    t,
  ) async {
    final c = await _open(t);
    await c.advanceTo(t, c.middleOf(6));
    await _settleMotion(t);
    expect(_followButton, findsNothing);

    await t.drag(find.byType(CustomScrollView), const Offset(0, -150));
    await t.pump();
    expect(c.player.state.status, ChantStatus.playing, reason: 'sound goes on');
    expect(_followButton, findsOneWidget);
    expect(find.text('Follow the chanting'), findsOneWidget);
    final held = _scrollOffset(t);

    await c.advanceTo(t, c.middleOf(14));
    await _settleMotion(t);
    expect(_scrollOffset(t), held, reason: 'the page no longer moves');
    expect(_followButton, findsOneWidget);
    expect(c.player.state.status, ChantStatus.playing);

    await t.tap(_followButton);
    await _settleMotion(t);
    expect(_followButton, findsNothing);
    expect(_activeBlock(t, c), 14);
    expect(_offThird(t, markTop(t, c.block(14))!), lessThan(24));

    // It follows again from now on.
    await c.advanceTo(t, c.middleOf(18));
    await _settleMotion(t);
    expect(_followButton, findsNothing);
    expect(_activeBlock(t, c), 18);
  });

  testWidgets('a tap on the text while chanting pauses following; it does '
      'not come back by itself', (t) async {
    final c = await _open(t, size: const Size(390, 2400));
    await c.advanceTo(t, c.middleOf(2));
    await _settleMotion(t);
    // A tap on the title area: a hand on the text, not on a block.
    await t.tapAt(t.getTopLeft(find.byType(CustomScrollView)) + const Offset(4, 4));
    await t.pump();
    expect(_followButton, findsOneWidget);
    await c.advanceTo(t, c.middleOf(4));
    await c.advanceTo(t, c.middleOf(5));
    await _settleMotion(t);
    expect(_followButton, findsOneWidget);
  });

  testWidgets('a tap on a block while chanting seeks to its start and follows',
      (t) async {
    final c = await _open(t, size: const Size(390, 2400));
    await c.advanceTo(t, c.middleOf(1));
    await _settleMotion(t);
    await t.tap(c.text(3));
    await t.pump();
    await _settleMotion(t);
    expect(c.player.seeks, [c.time(3).start]);
    expect(_followButton, findsNothing, reason: 'following is on');
    expect(c.player.state.position, c.time(3).start);
    expect(_activeBlock(t, c), 3);
    expect(c.player.state.status, ChantStatus.playing);
  });

  testWidgets('a tap on a block while paused seeks too', (t) async {
    final c = await _open(t, size: const Size(390, 2400));
    await c.advanceTo(t, c.middleOf(1));
    await t.tap(_play);
    await t.pump();
    expect(c.player.state.status, ChantStatus.paused);
    await t.tap(c.text(2));
    await t.pump();
    expect(c.player.seeks, [c.time(2).start]);
    expect(c.player.state.status, ChantStatus.paused,
        reason: 'a tap never starts sound');
  });

  testWidgets('paused at the very start: the mark stays and taps still seek',
      (t) async {
    final c = await _open(t, size: const Size(390, 2400));
    await c.advanceTo(t, const Duration(seconds: 1));
    await t.tap(_play);
    await t.pump();
    expect(c.player.state.status, ChantStatus.paused);
    await t.tap(c.text(0));
    await t.pump();
    expect(c.player.state.status, ChantStatus.paused);
    expect(c.player.state.position, c.time(0).start);
    expect(_activeBlock(t, c), 0, reason: 'the place is kept');
    await t.tap(c.text(2));
    await t.pump();
    expect(c.player.seeks, [c.time(0).start, c.time(2).start]);
    expect(c.player.state.status, ChantStatus.paused);
    expect(_activeBlock(t, c), 2);
  });

  testWidgets('a hand down before the frame stops the page being scrolled',
      (t) async {
    final c = await _open(t);
    await c.advanceTo(t, c.middleOf(1));
    await _settleMotion(t);
    final held = _scrollOffset(t);
    // The place moves; the hand comes down before the frame is drawn.
    c.player.advance(c.middleOf(12) - c.player.state.position);
    await t.binding.idle();
    final g = await t.startGesture(
        t.getTopLeft(find.byType(CustomScrollView)) + const Offset(4, 4));
    await t.pump();
    await g.up();
    await _settleMotion(t);
    expect(_scrollOffset(t), held);
    expect(_followButton, findsOneWidget);
  });

  testWidgets('Alavaka: its last block cannot be tapped and is never marked',
      (t) async {
    final c = await _open(t, id: _alavakaId, size: const Size(390, 2400));
    final lastIndex = c.blocks.length - 1;
    expect(c.recording.blockTimes[lastIndex], isNull);
    final state = t.state<ScrollableState>(find.byType(Scrollable).first);

    Future<void> toEnd() async {
      for (var i = 0; i < 3; i++) {
        state.position.jumpTo(state.position.maxScrollExtent);
        await t.pump();
      }
    }

    await toEnd();
    expect(c.text(lastIndex), findsOneWidget);
    await t.tap(c.text(lastIndex));
    await t.pump();
    expect(c.player.seeks, isEmpty);
    expect(find.descendant(of: c.block(lastIndex), matching: _blockActive),
        findsNothing);

    var position = Duration.zero;
    while (position < c.end + const Duration(seconds: 1)) {
      position += const Duration(seconds: 15);
      await c.advanceTo(t, position);
      await toEnd();
      expect(
        find.descendant(of: c.block(lastIndex), matching: _blockActive),
        findsNothing,
        reason: 'at $position',
      );
    }
    expect(c.player.seeks, isEmpty);
  });

  testWidgets('auto-scroll alone shows no mark and does not start the '
      'chanting', (t) async {
    final c = await _open(t, play: false);
    await t.tap(_scrollButton);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(_scrollOffset(t), greaterThan(0));
    expect(_blockActive, findsNothing);
    expect(markCount(t), 0);
    expect(c.player.loaded, isEmpty);
  });

  testWidgets('chanting paused by auto-scroll keeps its block mark; the page '
      'is moved by auto-scroll, not by following', (t) async {
    final c = await _open(t);
    await c.advanceTo(t, c.middleOf(3));
    await _settleMotion(t);
    final before = _activeBlock(t, c);
    await t.tap(_scrollButton);
    await t.pump();
    expect(c.player.state.status, ChantStatus.paused);
    final offset = _scrollOffset(t);
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(_scrollOffset(t), greaterThan(offset));
    expect(_activeBlock(t, c), before, reason: 'the mark stays');
    expect(c.player.state.status, ChantStatus.paused);
  });

  testWidgets('a place change rebuilds only the blocks it leaves and enters',
      (t) async {
    final c = await _open(t, size: const Size(390, 2400));
    await c.advanceTo(t, c.middleOf(1));
    await _settleMotion(t);
    expect(_activeBlock(t, c), 1);
    final built = {
      for (var i = 0; i < c.blocks.length; i++)
        if (c.block(i).evaluate().isNotEmpty) c.blocks[i].id: i,
    };
    expect(built.length, greaterThan(3), reason: 'several blocks are built');
    final before = Map<String, int>.of(blockBuildCounts);
    await c.advanceTo(t, c.middleOf(2));
    await _settleMotion(t);
    expect(_activeBlock(t, c), 2);
    final rebuilt = {
      for (final id in built.keys)
        if ((blockBuildCounts[id] ?? 0) != (before[id] ?? 0)) built[id]!,
    };
    expect(rebuilt, {1, 2});
  });

  group('contrast', () {
    for (final dark in [false, true]) {
      testWidgets('the marks are readable in the ${dark ? 'dark' : 'light'} '
          'theme', (t) async {
        final c = await _open(t, dark: dark);
        await c.advanceTo(t, c.middleOf(2));
        await _settleMotion(t);
        final p = dark ? NamoPalette.dark : NamoPalette.light;
        final bg = t.widget<DecoratedBox>(_blockActive);
        final tint = (bg.decoration as BoxDecoration).color!;
        expect(tint, p.sageTint);
        final shown = Color.alphaBlend(tint, p.background);
        expect(contrast(p.text, shown), greaterThanOrEqualTo(4.5));
        expect(contrast(p.textSecondary, shown), greaterThanOrEqualTo(4.5));
        final marked = Color.alphaBlend(p.sageMark, shown);
        expect(contrast(p.text, marked), greaterThanOrEqualTo(4.5));
        expect(contrast(p.sage, shown), greaterThanOrEqualTo(3.0));
        final spans = [
          for (final e in passages.evaluate())
            ...phraseSpans(t, find.byElementPredicate((x) => x == e)),
        ].where(isMarked);
        expect(spans, isNotEmpty);
        for (final s in spans) {
          expect(s.style!.backgroundColor, p.sageMark);
          expect(s.style!.decorationColor, p.sage);
          expect(s.style!.color, p.text);
        }
      });
    }
  });
}
