import 'dart:convert';

import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/audio/recording_store.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/flows/flows.dart';
import 'package:buddhist_gatha/reader/chant_bar.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/reader/reader_bottom_bar.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../support/fake_chant_player.dart';
import '../support/fake_recording_store.dart';
import '../support/passages.dart';

const _karaniyaId = 'pirith-10-karaniya';
const _rathanaId = 'pirith-09-rathana';
const _saranaId = 'pirith-02-saranagamanam';

final _play = find.byKey(const ValueKey('chant-play'));
final _restart = find.byKey(const ValueKey('chant-restart'));
final _slider = find.byKey(const ValueKey('chant-slider'));
final _coverage = find.byKey(const ValueKey('chant-coverage'));
final _row = find.byKey(const ValueKey('recording-row'));
final _download = find.byKey(const ValueKey('recording-download'));
final _scrollButton = find.byKey(const ValueKey('reader-autoscroll'));
final _blockActive = find.byKey(const ValueKey('block-active'));
final _prev = find.byKey(const ValueKey('reader-prev'));
final _next = find.byKey(const ValueKey('reader-next'));

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

  /// The reading of every recording loaded, in order.
  List<String> get ids => [for (final r in loaded) r.readingId];

  /// Lets the loaded recording run to its end.
  void finish() => advance(length - state.position);

  /// Lets the loaded recording run to [to] (forwards only).
  void runTo(Duration to) => advance(to - state.position);
}

RecordingStatus _status(Availability a, {double progress = 0, String? reason}) =>
    RecordingStatus(
      availability: a,
      progress: progress,
      reason: reason,
      bytes: 1046598,
    );

FlowRef _whole(String readingId) => FlowRef(readingId: readingId, sectionId: 'p');

/// The first three sections of Buddha Wandanawa, as flow-1 "Evening" has.
Future<List<FlowRef>> _buddha(WidgetTester t, [int count = 3]) async {
  final buddha = (await realLibrary(t)).reading(realReadingId)!;
  return [
    for (final s in buddha.sections.take(count))
      FlowRef(readingId: buddha.id, sectionId: s.id),
  ];
}

Future<Recording> _recording(WidgetTester t, String readingId) async =>
    ContentAudioCatalogue(await realLibrary(t)).recordingFor(readingId)!;

/// Opens flow-1 holding [sections] in the reader.
Future<_Player> _open(
  WidgetTester t,
  List<FlowRef> sections, {
  FakeRecordingStore? store,
  AppSettings settings = const AppSettings(),
  Size size = const Size(390, 844),
}) async {
  final player = _Player();
  await openReal(
    t,
    Routes.reader('flow-1'),
    player: player,
    recordingStore: store,
    settings: settings,
    size: size,
    storeExtras: {
      flowsKey: jsonEncode(
        FlowsState(
          flows: [Flow(id: 'flow-1', name: 'Evening', sections: sections)],
          nextNumber: 2,
        ).toJson(),
      ),
    },
  );
  return player;
}

/// The block of verse [i] of [readingId]'s only section, in a flow.
Future<Finder> _block(WidgetTester t, String readingId, int i) async {
  final reading = (await realLibrary(t)).reading(readingId)!;
  final verse = reading.sections.single.verses[i];
  return find.byKey(ValueKey('block-$readingId~${verse.id}'));
}

Duration _middle(BlockTime b) => b.start + (b.end - b.start) ~/ 2;

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

double _offset(WidgetTester t) =>
    t.state<ReaderBodyState>(find.byType(ReaderBody)).controller.offset;

/// The words in the recording row.
String _rowText(WidgetTester t) => t
    .widget<Text>(find.descendant(of: _row, matching: find.byType(Text)).first)
    .data!;

bool _enabled(WidgetTester t, Finder f) =>
    t.widget<NamoIconButton>(f).onPressed != null;

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f);
  await t.pump();
  await t.pump();
}

/// Lets the loaded recording run out, and the next one load.
Future<void> _finish(WidgetTester t, _Player player) async {
  player.finish();
  await t.pump();
  await t.pump();
  await t.pump();
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('a flow of two pirith chants both in order', (t) async {
    final first = await _recording(t, mangalaReadingId);
    final second = await _recording(t, _karaniyaId);
    final player = await _open(t, [
      _whole(mangalaReadingId),
      _whole(_karaniyaId),
    ]);

    await _tap(t, _play);
    expect(player.ids, [first.readingId]);
    expect(player.state.status, ChantStatus.playing);

    await _finish(t, player);
    expect(player.ids, [first.readingId, second.readingId]);
    expect(player.state.status, ChantStatus.playing);

    player.runTo(_middle(second.blockTimes[3]!));
    await _settle(t);
    expect(
      find.descendant(
        of: await _block(t, _karaniyaId, 3),
        matching: _blockActive,
      ),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('a mixed flow shows the coverage line until Play, then the '
      'slider', (t) async {
    await _open(t, [
      ...await _buddha(t),
      _whole(mangalaReadingId),
      _whole(_karaniyaId),
    ]);
    expect(_coverage, findsOneWidget);
    expect(t.widget<Text>(_coverage).data, 'Chant plays 2 of 5 sections');
    expect(_slider, findsNothing);

    await _tap(t, _play);
    expect(_slider, findsOneWidget);
    expect(_coverage, findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('a mixed flow whose first recording is not downloaded shows '
      'its row and Download before Play, not the coverage line', (t) async {
    final store = FakeRecordingStore()
      ..set(mangalaReadingId, _status(Availability.notDownloaded));
    await _open(t, [
      ...await _buddha(t),
      _whole(mangalaReadingId),
      _whole(_karaniyaId),
    ], store: store);
    expect(_coverage, findsNothing);
    expect(_row, findsOneWidget);
    expect(_rowText(t), 'Recording not downloaded · 1.0 MB');
    expect(
      find.descendant(of: _download, matching: find.text('Download')),
      findsOneWidget,
    );

    store.set(mangalaReadingId, _status(Availability.downloaded));
    await t.pump();
    expect(_row, findsNothing);
    expect(t.widget<Text>(_coverage).data, 'Chant plays 2 of 5 sections');
    expect(t.takeException(), isNull);
  });

  testWidgets('the page stays until the first recorded block starts', (
    t,
  ) async {
    final rathana = await _recording(t, _rathanaId);
    final player = await _open(t, [...await _buddha(t), _whole(_rathanaId)]);
    expect(_offset(t), 0);

    await _tap(t, _play);
    await _settle(t);
    expect(player.state.status, ChantStatus.playing);
    expect(_offset(t), 0);

    final start = rathana.blockTimes.first!.start;
    player.runTo(start - const Duration(milliseconds: 100));
    await _settle(t);
    expect(_offset(t), 0);

    player.runTo(_middle(rathana.blockTimes.first!));
    await _settle(t);
    expect(_offset(t), greaterThan(0));
  });

  testWidgets('a tap on a line of the second pirith seeks into it', (t) async {
    final first = await _recording(t, mangalaReadingId);
    final second = await _recording(t, _karaniyaId);
    final player = await _open(t, [
      _whole(mangalaReadingId),
      _whole(_karaniyaId),
    ], size: const Size(390, 2400));
    await _tap(t, _play);
    player.runTo(_middle(first.blockTimes[1]!));
    await _settle(t);

    final block = await _block(t, _karaniyaId, 2);
    await t.scrollUntilVisible(
      block,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pump();
    await t.tap(find.descendant(of: block, matching: passages).first);
    await t.pump();
    await t.pump();
    await t.pump();
    expect(player.ids, [first.readingId, second.readingId]);
    expect(player.seeks.last, second.blockTimes[2]!.start);
    expect(player.state.status, ChantStatus.playing);
  });

  testWidgets('Restart goes to the first recording', (t) async {
    final first = await _recording(t, mangalaReadingId);
    final second = await _recording(t, _karaniyaId);
    final player = await _open(t, [
      _whole(mangalaReadingId),
      _whole(_karaniyaId),
    ]);
    await _tap(t, _play);
    await _finish(t, player);
    player.runTo(const Duration(seconds: 30));
    await t.pump();
    expect(player.ids.last, second.readingId);

    await _tap(t, _restart);
    expect(player.ids.last, first.readingId);
    expect(player.state.status, ChantStatus.playing);
    expect(player.state.position, Duration.zero);
  });

  testWidgets('the second recording not downloaded is queued at Play and '
      'awaited when the first ends', (t) async {
    final first = await _recording(t, mangalaReadingId);
    final second = await _recording(t, _karaniyaId);
    final store = FakeRecordingStore()
      ..set(_karaniyaId, _status(Availability.waiting));
    final player = await _open(t, [
      _whole(mangalaReadingId),
      _whole(_karaniyaId),
    ], store: store);

    await _tap(t, _play);
    expect(store.downloads, [second.path]);
    expect(player.ids, [first.readingId]);

    await _finish(t, player);
    expect(player.ids, [first.readingId]);
    expect(_row, findsOneWidget);
    expect(_rowText(t), 'Waiting to download · 1.0 MB');
    expect(find.byTooltip('Play chanting'), findsOneWidget);
    expect(_enabled(t, _restart), isTrue);

    store.set(_karaniyaId, _status(Availability.downloading));
    await t.pump();
    expect(_rowText(t), 'Downloading recording… 0%');
    expect(_enabled(t, _restart), isTrue);
    expect(player.ids, [first.readingId]);

    store.set(_karaniyaId, _status(Availability.downloaded));
    await t.pump();
    await t.pump();
    await t.pump();
    expect(player.ids, [first.readingId, second.readingId]);
    expect(player.state.status, ChantStatus.playing);
    expect(player.state.position, Duration.zero);
    expect(_slider, findsOneWidget);
    expect(_row, findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Scroll disarms the wait and Play arms it again', (t) async {
    final first = await _recording(t, mangalaReadingId);
    final second = await _recording(t, _karaniyaId);
    final third = await _recording(t, _saranaId);
    final store = FakeRecordingStore()
      ..set(_karaniyaId, _status(Availability.waiting))
      ..set(_saranaId, _status(Availability.waiting));
    final player = await _open(t, [
      _whole(mangalaReadingId),
      _whole(_karaniyaId),
      _whole(_saranaId),
    ], store: store);
    await _tap(t, _play);
    await _finish(t, player);
    expect(player.ids, [first.readingId]);

    // Scroll: the second arrives and is loaded, but does not play.
    await _tap(t, _scrollButton);
    store.set(_karaniyaId, _status(Availability.downloaded));
    await t.pump();
    await t.pump();
    await t.pump();
    expect(player.ids, [first.readingId, second.readingId]);
    expect(player.state.status, isNot(ChantStatus.playing));

    // Play goes on with it, and on its end waits for the third.
    await _tap(t, _play);
    expect(player.state.status, ChantStatus.playing);
    await _finish(t, player);
    expect(player.ids, [first.readingId, second.readingId]);

    // Scroll, then Play again while waiting: the third plays on arrival.
    await _tap(t, _scrollButton);
    await _tap(t, _play);
    store.set(_saranaId, _status(Availability.downloaded));
    await t.pump();
    await t.pump();
    await t.pump();
    expect(player.ids, [first.readingId, second.readingId, third.readingId]);
    expect(player.state.status, ChantStatus.playing);
  });

  testWidgets('a failed download shows Try again and Play downloads again', (
    t,
  ) async {
    final first = await _recording(t, mangalaReadingId);
    final second = await _recording(t, _karaniyaId);
    final store = FakeRecordingStore()
      ..set(_karaniyaId, _status(Availability.waiting));
    final player = await _open(t, [
      _whole(mangalaReadingId),
      _whole(_karaniyaId),
    ], store: store);
    await _tap(t, _play);
    await _finish(t, player);

    store.set(
      _karaniyaId,
      _status(Availability.failed, reason: notOnServerMessage),
    );
    await t.pump();
    expect(_rowText(t), notOnServerMessage);
    expect(
      find.descendant(of: _download, matching: find.text('Try again')),
      findsOneWidget,
    );

    final before = store.downloads.length;
    await _tap(t, _play);
    expect(store.downloads, hasLength(before + 1));
    expect(store.downloads.last, second.path);

    store.set(_karaniyaId, _status(Availability.downloaded));
    await t.pump();
    await t.pump();
    await t.pump();
    expect(player.ids, [first.readingId, second.readingId]);
    expect(player.state.status, ChantStatus.playing);
  });

  testWidgets('a drag into an undownloaded leg waits at that point', (
    t,
  ) async {
    final first = await _recording(t, mangalaReadingId);
    final second = await _recording(t, _karaniyaId);
    final store = FakeRecordingStore()
      ..set(_karaniyaId, _status(Availability.waiting));
    final player = await _open(t, [
      _whole(mangalaReadingId),
      _whole(_karaniyaId),
    ], store: store);
    await _tap(t, _play);
    player.runTo(const Duration(seconds: 10));
    await t.pump();

    const into = Duration(seconds: 30);
    t
        .widget<ReaderBottomBar>(find.byType(ReaderBottomBar))
        .onChantSeek!(first.duration + into);
    await t.pump();
    await t.pump();
    expect(player.ids, [first.readingId]);
    expect(_row, findsOneWidget);
    expect(find.byTooltip('Play chanting'), findsOneWidget);

    store.set(_karaniyaId, _status(Availability.downloaded));
    await t.pump();
    await t.pump();
    await t.pump();
    expect(player.ids, [first.readingId, second.readingId]);
    expect(player.seeks.last, into);
    expect(player.state.position, into);
    expect(player.state.status, ChantStatus.playing);
  });

  testWidgets('leaving while waiting plays nothing', (t) async {
    final first = await _recording(t, mangalaReadingId);
    final store = FakeRecordingStore()
      ..set(_karaniyaId, _status(Availability.waiting));
    final player = await _open(t, [
      _whole(mangalaReadingId),
      _whole(_karaniyaId),
    ], store: store);
    await _tap(t, _play);
    await _finish(t, player);

    ProviderScope.containerOf(
      t.element(find.byType(Scaffold).first),
    ).read(routerProvider).go(Routes.settings);
    await t.pumpAndSettle();

    store.set(_karaniyaId, _status(Availability.downloaded));
    await t.pump();
    await t.pump();
    expect(player.ids, [first.readingId]);
    expect(player.state.status, isNot(ChantStatus.playing));
    expect(t.takeException(), isNull);
  });

  testWidgets('going to the background while waiting disarms the wait', (
    t,
  ) async {
    final first = await _recording(t, mangalaReadingId);
    final second = await _recording(t, _karaniyaId);
    final store = FakeRecordingStore()
      ..set(_karaniyaId, _status(Availability.waiting));
    final player = await _open(t, [
      _whole(mangalaReadingId),
      _whole(_karaniyaId),
    ], store: store);
    await _tap(t, _play);
    await _finish(t, player);
    expect(player.ids, [first.readingId]);

    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();

    store.set(_karaniyaId, _status(Availability.downloaded));
    await t.pump();
    await t.pump();
    await t.pump();
    expect(player.ids, [first.readingId, second.readingId]);
    expect(player.state.status, isNot(ChantStatus.playing));
    expect(find.byTooltip('Play chanting'), findsOneWidget);

    await _tap(t, _play);
    expect(player.state.status, ChantStatus.playing);
    expect(player.ids, [first.readingId, second.readingId]);
  });

  testWidgets('a failed load of the second recording says so and Play '
      'tries again', (t) async {
    final first = await _recording(t, mangalaReadingId);
    final second = await _recording(t, _karaniyaId);
    final player = await _open(t, [
      _whole(mangalaReadingId),
      _whole(_karaniyaId),
    ]);
    await _tap(t, _play);
    player.failOnLoad = true;
    await _finish(t, player);
    await t.pump();
    expect(player.ids, [first.readingId, second.readingId]);
    expect(find.text(chantFailedMessage), findsOneWidget);

    player.failOnLoad = false;
    await _tap(t, _play);
    await t.pump();
    expect(player.ids, [first.readingId, second.readingId, second.readingId]);
    expect(player.state.status, ChantStatus.playing);
    expect(find.text(chantFailedMessage), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('speed survives the leg change', (t) async {
    final second = await _recording(t, _karaniyaId);
    final player = await _open(t, [
      _whole(mangalaReadingId),
      _whole(_karaniyaId),
    ]);
    await _tap(t, _play);
    await _tap(t, find.byKey(const ValueKey('chant-speed')));
    expect(player.speed, 1.25);
    final set = player.speeds.length;

    await _finish(t, player);
    expect(player.ids.last, second.readingId);
    expect(player.speed, 1.25);
    expect(player.speeds, hasLength(set + 1), reason: 'applied on the load');
    expect(player.speeds.last, 1.25);
    expect(find.text('1.25×'), findsOneWidget);
  });

  testWidgets('the Vandana chants inside a flow', (t) async {
    final vandana = await _recording(t, spVandanaId);
    expect(vandana.lineTimes, isNotEmpty);
    final player = await _open(t, [
      ...await _buddha(t, 1),
      _whole(spVandanaId),
    ], size: const Size(390, 2400));
    expect(_coverage, findsOneWidget);
    expect(find.text('Chant plays 1 of 2 sections'), findsOneWidget);

    await _tap(t, _play);
    expect(player.ids, [vandana.readingId]);
    final line = vandana.lineTimes[1][2]!;
    player.runTo(line + const Duration(milliseconds: 500));
    await _settle(t);
    final block = await _block(t, spVandanaId, 1);
    expect(find.descendant(of: block, matching: _blockActive), findsOneWidget);
    expect(markCount(t, block), greaterThan(0));
    expect(markCount(t), markCount(t, block));
    expect(t.takeException(), isNull);
  });

  testWidgets('Previous and Next still move between headings', (t) async {
    final buddha = await _buddha(t);
    await _open(t, [...buddha, _whole(mangalaReadingId)]);
    expect(_play, findsOneWidget);
    expect(t.widget<NamoIconButton>(_prev).tooltip, 'Previous section');
    expect(t.widget<NamoIconButton>(_next).tooltip, 'Next section');

    final heading = find.byKey(
      ValueKey('heading-$realReadingId~${buddha[1].sectionId}'),
    );
    await t.tap(_next);
    await t.pumpAndSettle();
    expect(
      t.getTopLeft(heading).dy,
      closeTo(t.getTopLeft(find.byType(ReaderBody)).dy, 1),
    );
    await t.tap(_prev);
    await t.pumpAndSettle();
    expect(_offset(t), 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('a flow with no recorded section is unchanged', (t) async {
    await _open(t, await _buddha(t));
    expect(_play, findsNothing);
    expect(_coverage, findsNothing);
    expect(_slider, findsNothing);
    expect(find.byKey(const ValueKey('reader-play')), findsOneWidget);
  });
}
