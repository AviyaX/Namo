import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../support/fake_chant_player.dart';
import '../support/passages.dart';

final _play = find.byKey(const ValueKey('chant-play'));
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

  List<Verse> get units => reading.sections.single.verses;

  int indexOf(String id) => units.indexWhere((v) => v.id == id);

  Finder block(String id) => find.byKey(ValueKey('block-$id'));

  BlockTime time(String id) => recording.blockTimes[indexOf(id)]!;

  Duration lineTime(String id, int line) =>
      recording.lineTimes[indexOf(id)][line]!;

  /// The middle of line [line] of unit [id]: halfway to the next timed line
  /// (or to the unit's end).
  Duration middleOfLine(String id, int line) {
    final times = recording.lineTimes[indexOf(id)];
    final start = times[line]!;
    var end = time(id).end;
    for (var i = line + 1; i < times.length; i++) {
      if (times[i] != null) {
        end = times[i]!;
        break;
      }
    }
    return start + (end - start) ~/ 2;
  }

  /// Lets the recording run to [to] (forwards only).
  Future<void> advanceTo(WidgetTester t, Duration to) async {
    player.advance(to - player.state.position);
    await t.pump();
  }
}

Future<_Chant> _open(
  WidgetTester t, {
  Size size = const Size(390, 844),
  AppSettings settings = const AppSettings(),
  bool play = true,
}) async {
  final lib = await realLibrary(t);
  final reading = lib.reading(spVandanaId)!;
  final recording = ContentAudioCatalogue(lib).recordingFor(spVandanaId)!;
  final last = recording.blockTimes.whereType<BlockTime>().last.end;
  final player = _SpyPlayer(length: last + const Duration(seconds: 2));
  await openReal(
    t,
    Routes.reader(spVandanaId),
    player: player,
    size: size,
    settings: settings,
  );
  final chant = _Chant(reading, recording, player);
  if (play) {
    await t.tap(_play);
    await t.pump();
  }
  return chant;
}

Future<void> _settleMotion(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Whether [_blockActive] is inside unit [id].
bool _isActive(_Chant c, String id) => find
    .descendant(of: c.block(id), matching: _blockActive)
    .evaluate()
    .isNotEmpty;

/// The global centre of line [line] of unit [id]'s Pali passage.
Offset _lineCentre(WidgetTester t, _Chant c, String id, int line) {
  final pali = passage(id, 'pali');
  final paragraph = t.renderObject<RenderParagraph>(
    find.descendant(of: pali, matching: find.byType(RichText)),
  );
  final lines = c.units[c.indexOf(id)].phrases.map((p) => p.pali).toList();
  var start = 0;
  for (var i = 0; i < line; i++) {
    start += lines[i].length + 1;
  }
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(
          baseOffset: start,
          extentOffset: start + lines[line].length,
        ),
      )
      .first;
  return paragraph.localToGlobal(box.toRect().center);
}

AppSettings _only(List<ReadingLanguage> languages) =>
    AppSettings(languages: LanguageSelection(languages));

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('the middle of the third line of part 1 marks exactly that '
      'line, in an active unit', (t) async {
    final c = await _open(t);
    await c.advanceTo(t, c.middleOfLine('u-part-1', 2));
    await _settleMotion(t);
    expect(_isActive(c, 'u-part-1'), isTrue);
    final pali = passage('u-part-1', 'pali');
    expect(markedIn(t, pali), [2]);
    expect(markCount(t), 1);
    final marked = phraseSpans(t, pali).where(isMarked).single;
    expect(marked.text, c.units[c.indexOf('u-part-1')].phrases[2].pali);

    // Each line is marked from its own time, not from a length estimate.
    final times = c.recording.lineTimes[c.indexOf('u-part-1')];
    for (var line = 3; line < times.length; line++) {
      if (times[line] == null) continue;
      await c.advanceTo(t, times[line]! + const Duration(milliseconds: 100));
      await t.pump();
      expect(markedIn(t, pali), [line], reason: 'line $line');
    }
  });

  testWidgets('stepping through a part, the marked line never goes back', (
    t,
  ) async {
    final c = await _open(t);
    const id = 'u-part-2';
    final end = c.time(id).end;
    var position = c.time(id).start;
    var last = -1;
    var seen = 0;
    while (position < end) {
      await c.advanceTo(t, position);
      await t.pump(const Duration(milliseconds: 300));
      expect(_isActive(c, id), isTrue, reason: 'at $position');
      final marks = markedIn(t, passage(id, 'pali'));
      expect(marks.length, 1, reason: 'at $position');
      expect(marks.single, greaterThanOrEqualTo(last), reason: 'at $position');
      if (marks.single > last) seen++;
      last = marks.single;
      position += const Duration(seconds: 2);
    }
    expect(seen, greaterThan(10), reason: 'the mark moved line by line');
  });

  testWidgets('every timed line of part 2 is marked from its own time', (
    t,
  ) async {
    final c = await _open(t);
    const id = 'u-part-2';
    final times = c.recording.lineTimes[c.indexOf(id)];
    for (var line = 0; line < times.length; line++) {
      if (times[line] == null) continue;
      await c.advanceTo(t, times[line]! + const Duration(milliseconds: 100));
      await t.pump();
      expect(markedIn(t, passage(id, 'pali')), [line], reason: 'line $line');
    }
  });

  testWidgets('during the homage the unit is active and no line is marked', (
    t,
  ) async {
    final c = await _open(t);
    final homage = c.time('u-homage');
    final span = homage.end - homage.start;
    for (final at in [homage.start + span ~/ 6, homage.start + span * 2 ~/ 3]) {
      await c.advanceTo(t, at);
      await _settleMotion(t);
      expect(_isActive(c, 'u-homage'), isTrue, reason: 'at $at');
      expect(markCount(t), 0, reason: 'at $at');
    }
  });

  testWidgets('the page follows the marked line; a hand drag pauses it', (
    t,
  ) async {
    final c = await _open(t);
    final text = t.getRect(find.byType(CustomScrollView));
    await c.advanceTo(t, c.middleOfLine('u-part-2', 20));
    await _settleMotion(t);
    final top = markTop(t, c.block('u-part-2'));
    expect(top, isNotNull);
    expect((top! - text.top - text.height / 3).abs(), lessThan(24));
    expect(_followButton, findsNothing);

    await t.drag(find.byType(CustomScrollView), const Offset(0, -150));
    await t.pump();
    expect(_followButton, findsOneWidget);
    expect(c.player.state.status, ChantStatus.playing);
  });

  testWidgets('a tap on the fifth line of part 2 seeks to that line', (
    t,
  ) async {
    final c = await _open(t);
    await c.advanceTo(t, c.middleOfLine('u-part-2', 1));
    await _settleMotion(t);
    await t.tapAt(_lineCentre(t, c, 'u-part-2', 4));
    await t.pump();
    await _settleMotion(t);
    expect(c.player.seeks, [c.lineTime('u-part-2', 4)]);
    expect(markedIn(t, passage('u-part-2', 'pali')), [4]);
    expect(_followButton, findsNothing, reason: 'following is on');
  });

  testWidgets('a tap on the homage seeks to its start', (t) async {
    final c = await _open(t);
    await c.advanceTo(t, c.middleOfLine('u-list', 3));
    await _settleMotion(t);
    final state = t.state<ScrollableState>(find.byType(Scrollable).first);
    state.position.jumpTo(0);
    await t.pump();
    await t.tapAt(_lineCentre(t, c, 'u-homage', 1));
    await t.pump();
    expect(c.player.seeks, [c.time('u-homage').start]);
  });

  testWidgets('a tap on the meaning seeks to the unit start', (t) async {
    final c = await _open(
      t,
      settings: _only([ReadingLanguage.pali, ReadingLanguage.sinhala]),
    );
    await c.advanceTo(t, c.middleOfLine('u-part-1', 1));
    await _settleMotion(t);
    final meaning = passage('u-part-1', 'sinhala');
    await t.ensureVisible(meaning);
    await t.pump();
    await t.tapAt(t.getRect(meaning).topLeft + const Offset(8, 8));
    await t.pump();
    expect(c.player.seeks, [c.time('u-part-1').start]);
  });

  testWidgets('the semantic tap on a unit seeks to its start', (t) async {
    final semantics = t.ensureSemantics();
    final c = await _open(t);
    await c.advanceTo(t, c.middleOfLine('u-part-1', 3));
    await _settleMotion(t);
    final node = t.getSemantics(c.block('u-part-1'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await t.pump();
    expect(c.player.seeks, [c.time('u-part-1').start]);
    semantics.dispose();
  });

  testWidgets('before play a tap does not seek', (t) async {
    final c = await _open(t, play: false);
    await t.tapAt(_lineCentre(t, c, 'u-homage', 1));
    await t.pump();
    expect(c.player.seeks, isEmpty);
    expect(c.player.loaded, isEmpty);
    expect(c.player.state.status, ChantStatus.idle);
    expect(_blockActive, findsNothing);
  });

  testWidgets('with Sinhala alone the chanting plays, the unit is active and '
      'nothing is marked', (t) async {
    final c = await _open(t, settings: _only([ReadingLanguage.sinhala]));
    await c.advanceTo(t, c.middleOfLine('u-part-1', 2));
    await _settleMotion(t);
    expect(c.player.state.status, ChantStatus.playing);
    expect(passage('u-part-1', 'pali'), findsNothing);
    expect(_isActive(c, 'u-part-1'), isTrue);
    expect(markCount(t), 0);
  });

  group('with Sinhala alone the opening verses, which have no meaning, show '
      'their Pali lines', () {
    testWidgets('the active block holds the lines and the line is marked', (
      t,
    ) async {
      final c = await _open(t, settings: _only([ReadingLanguage.sinhala]));
      await c.advanceTo(t, c.middleOfLine('u-verses', 1));
      await _settleMotion(t);
      expect(_isActive(c, 'u-verses'), isTrue);
      final pali = passage('u-verses', 'pali');
      expect(
        find.descendant(of: c.block('u-verses'), matching: pali),
        findsOneWidget,
      );
      expect(
        passageText(t, pali),
        c.units[c.indexOf('u-verses')].phrases.map((p) => p.pali).join('\n'),
      );
      final box = t.getRect(
        find.descendant(of: c.block('u-verses'), matching: _blockActive),
      );
      final lines = t.getRect(pali);
      expect(box.contains(lines.topLeft), isTrue);
      expect(box.contains(lines.bottomRight - const Offset(1, 1)), isTrue);
      expect(markedIn(t, pali), [1]);
    });

    testWidgets('a tap on a line seeks to that line', (t) async {
      final c = await _open(t, settings: _only([ReadingLanguage.sinhala]));
      await c.advanceTo(t, c.middleOfLine('u-verses', 0));
      await _settleMotion(t);
      await t.tapAt(_lineCentre(t, c, 'u-verses', 2));
      await t.pump();
      await _settleMotion(t);
      expect(c.player.seeks, [c.lineTime('u-verses', 2)]);
      expect(markedIn(t, passage('u-verses', 'pali')), [2]);
    });
  });
}
