import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../support/fake_chant_player.dart';

final _play = find.byKey(const ValueKey('chant-play'));
final _coverage = find.byKey(const ValueKey('chant-coverage'));
final _verseActive = find.byKey(const ValueKey('verse-active'));

/// A player with no sound whose recordings last as long as their listing
/// says, and which counts the seeks it is asked for.
class _Player extends FakeChantPlayer {
  Recording? _current;
  final seeks = <Duration>[];

  @override
  Duration get length => _current?.duration ?? super.length;

  @override
  Future<void> load(Recording r) {
    _current = r;
    return super.load(r);
  }

  @override
  Future<void> seek(Duration to) {
    seeks.add(to);
    return super.seek(to);
  }

  List<String> get ids => [for (final r in loaded) r.readingId];

  void runTo(Duration to) => advance(to - state.position);
}

/// Every item of verse [verseId] (one per language shown).
Finder _verse(String verseId) => find.byWidgetPredicate((w) {
  final key = w.key;
  return key is ValueKey<String> &&
      (key.value.startsWith('verse-$verseId-') || key.value == 'pair-$verseId');
});

Duration _middle(BlockTime b) => b.start + (b.end - b.start) ~/ 2;

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f);
  await t.pump();
  await t.pump();
}

Future<(Reading, ContentAudioCatalogue, _Player)> _open(
  WidgetTester t, {
  String? section,
  Size size = const Size(390, 844),
}) async {
  final lib = await realLibrary(t);
  final player = _Player();
  await openReal(
    t,
    section == null
        ? Routes.reader(realReadingId)
        : '${Routes.reader(realReadingId)}?section=$section',
    player: player,
    size: size,
  );
  return (lib.reading(realReadingId)!, ContentAudioCatalogue(lib), player);
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('Buddha Wandanawa chants 31 of its 33 sections', (t) async {
    await _open(t);
    expect(_play, findsOneWidget);
    expect(t.widget<Text>(_coverage).data, 'Chant plays 31 of 33 sections');
    expect(t.takeException(), isNull);
  });

  testWidgets('each recorded section names its chanting under its heading', (
    t,
  ) async {
    final (reading, _, _) = await _open(t, size: const Size(390, 40000));
    for (final s in reading.sections) {
      final heading = find.byKey(ValueKey('heading-${s.id}'));
      final label = s.audio?.label;
      if (label == null) {
        expect(s.number, anyOf(31, 32));
        continue;
      }
      expect(
        find.descendant(of: heading, matching: find.text(label)),
        findsOneWidget,
        reason: s.id,
      );
    }
    final computer = reading.sections.first.audio!.label;
    expect(computer, startsWith('Computer-made chanting'));
    expect(
      reading.sections[4].audio!.label,
      'Chanted by Ven. Nauyane Ariyadhamma Thero',
    );
  });

  testWidgets('Play goes section after section and marks the verse being '
      'chanted', (t) async {
    final (reading, catalogue, player) = await _open(t);
    final s01 = catalogue.recordingFor('namaskaraya#s01')!;
    await _tap(t, _play);
    expect(player.ids, ['namaskaraya#s01']);
    expect(player.state.status, ChantStatus.playing);

    player.runTo(_middle(s01.blockTimes[1]!));
    await _settle(t);
    final second = reading.sections.first.verses[1].id;
    expect(
      find.descendant(of: _verse(second), matching: _verseActive),
      findsWidgets,
    );
    expect(_verseActive, findsWidgets);
    expect(
      find.descendant(
        of: _verse(reading.sections.first.verses[0].id),
        matching: _verseActive,
      ),
      findsNothing,
    );

    player.runTo(s01.duration);
    await t.pump();
    await t.pump();
    await t.pump();
    expect(player.ids, ['namaskaraya#s01', 'namaskaraya#s02']);
    expect(player.state.status, ChantStatus.playing);
    expect(t.takeException(), isNull);
  });

  testWidgets('the page follows the chanting down', (t) async {
    final (_, catalogue, player) = await _open(t);
    await _tap(t, _play);
    double offset() =>
        t.state<ReaderBodyState>(find.byType(ReaderBody)).controller.offset;
    final s01 = catalogue.recordingFor('namaskaraya#s01')!;
    player.runTo(_middle(s01.blockTimes[4]!));
    await _settle(t);
    final early = offset();
    player.runTo(s01.duration);
    await t.pump();
    await t.pump();
    await t.pump();
    final s02 = catalogue.recordingFor('namaskaraya#s02')!;
    player.runTo(_middle(s02.blockTimes[0]!));
    await _settle(t);
    expect(offset(), greaterThan(early));
    expect(t.takeException(), isNull);
  });

  testWidgets('a tap on a verse while chanting goes to it', (t) async {
    final (reading, catalogue, player) = await _open(
      t,
      section: 's05',
      size: const Size(390, 2400),
    );
    await _tap(t, _play);
    final s05 = reading.sections[4];
    final target = s05.verses[2].id;
    await t.ensureVisible(_verse(target).first);
    await t.pump();
    await _tap(t, _verse(target).first);
    await _settle(t);
    expect(player.ids.last, 'namaskaraya#s05');
    final time = catalogue.recordingFor('namaskaraya#s05')!.blockTimes[2]!;
    expect(player.seeks.last, time.start);
    expect(
      find.descendant(of: _verse(target), matching: _verseActive),
      findsWidgets,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('starting the chant does not move the page', (t) async {
    final (reading, _, _) = await _open(t);
    final last = _verse(reading.sections[1].verses.first.id).first;
    final before = t.getTopLeft(last).dy;
    final short = _verse(reading.sections.first.verses.first.id).first;
    expect(t.getSize(short).height, greaterThanOrEqualTo(48));
    await _tap(t, _play);
    expect(t.getTopLeft(last).dy, before);
    expect(t.takeException(), isNull);
  });

  testWidgets('a verse the recordings lack is never marked', (t) async {
    final (reading, catalogue, player) = await _open(
      t,
      section: 's08',
      size: const Size(390, 4000),
    );
    final s08 = catalogue.recordingFor('namaskaraya#s08')!;
    expect(s08.blockTimes[2], isNull);
    await _tap(t, _play);
    // s08 is the eighth leg; let the chant reach it by tapping its first verse.
    final first = reading.sections[7].verses.first.id;
    await t.ensureVisible(_verse(first).first);
    await _tap(t, _verse(first).first);
    await _settle(t);
    expect(player.ids.last, 'namaskaraya#s08');
    for (final at in [s08.blockTimes[1]!.end, s08.blockTimes[3]!.start]) {
      player.runTo(at + const Duration(milliseconds: 100));
      await _settle(t);
      expect(
        find.descendant(
          of: _verse(reading.sections[7].verses[2].id),
          matching: _verseActive,
        ),
        findsNothing,
      );
    }
    expect(t.takeException(), isNull);
  });
}
