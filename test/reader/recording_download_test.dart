import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/audio/recording_store.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/widgets/pressable.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../support/fake_chant_player.dart';
import '../support/fake_recording_store.dart';

final _play = find.byKey(const ValueKey('chant-play'));
final _row = find.byKey(const ValueKey('recording-row'));
final _download = find.byKey(const ValueKey('recording-download'));
final _slider = find.byKey(const ValueKey('chant-slider'));

const _bytes = 1046598;

RecordingStatus _status(
  Availability a, {
  double progress = 0,
  String? reason,
}) => RecordingStatus(
  availability: a,
  progress: progress,
  reason: reason,
  bytes: _bytes,
);

Future<Recording> _recording(WidgetTester t) async {
  final lib = await realLibrary(t);
  return ContentAudioCatalogue(lib).recordingFor(mangalaReadingId)!;
}

/// Opens the Mahamangala pirith with [store] (its status for the reading is
/// set by the caller, before or after).
Future<FakeChantPlayer> _open(
  WidgetTester t,
  FakeRecordingStore store, {
  String id = mangalaReadingId,
  FakeChantPlayer? player,
  Library? library,
}) async {
  player ??= FakeChantPlayer();
  await openReal(
    t,
    Routes.reader(id),
    library: library ?? await realLibrary(t),
    player: player,
    recordingStore: store,
  );
  return player;
}

/// The words in the recording row.
String _rowText(WidgetTester t) => t
    .widget<Text>(find.descendant(of: _row, matching: find.byType(Text)).first)
    .data!;

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('a downloaded recording shows the slider and plays', (t) async {
    final store = FakeRecordingStore()
      ..set(mangalaReadingId, _status(Availability.downloaded));
    final player = await _open(t, store);
    expect(_slider, findsOneWidget);
    expect(_row, findsNothing);

    await t.tap(_play);
    await t.pump();
    expect(player.loaded, hasLength(1));
    expect(player.state.status, ChantStatus.playing);
  });

  testWidgets('a waiting recording shows the line and a Download button', (
    t,
  ) async {
    final store = FakeRecordingStore()
      ..set(mangalaReadingId, _status(Availability.waiting));
    await _open(t, store);
    expect(_row, findsOneWidget);
    expect(_rowText(t), 'Waiting to download · 1.0 MB');
    expect(_download, findsOneWidget);
    expect(find.descendant(of: _download, matching: find.text('Download')),
        findsOneWidget);
    expect(_slider, findsNothing);
  });

  testWidgets('Download asks the store for this recording', (t) async {
    final store = FakeRecordingStore()
      ..set(mangalaReadingId, _status(Availability.notDownloaded));
    final player = await _open(t, store);
    expect(_rowText(t), 'Recording not downloaded · 1.0 MB');

    await t.tap(_download);
    await t.pump();
    expect(store.downloads, [(await _recording(t)).path]);
    expect(player.loaded, isEmpty);
  });

  testWidgets('Download alone never plays when the file arrives', (t) async {
    final store = FakeRecordingStore()
      ..set(mangalaReadingId, _status(Availability.waiting));
    final player = await _open(t, store);

    await t.tap(_download);
    await t.pump();
    expect(store.downloads, [(await _recording(t)).path]);

    store.set(mangalaReadingId, _status(Availability.downloaded));
    await t.pump();
    await t.pump();
    expect(player.loaded, isEmpty);
  });

  testWidgets('play on a waiting recording downloads it and plays when it '
      'arrives', (t) async {
    final store = FakeRecordingStore()
      ..set(mangalaReadingId, _status(Availability.waiting));
    final player = await _open(t, store);

    await t.tap(_play);
    await t.pump();
    expect(store.downloads, [(await _recording(t)).path]);
    expect(player.loaded, isEmpty);

    store.set(mangalaReadingId, _status(Availability.downloaded));
    await t.pump();
    await t.pump();
    expect(player.loaded, hasLength(1));
    expect(player.state.status, ChantStatus.playing);
    expect(_slider, findsOneWidget);
    expect(_row, findsNothing);
  });

  testWidgets('while downloading the play button is busy and the row shows '
      'the percentage', (t) async {
    final store = FakeRecordingStore()
      ..set(mangalaReadingId, _status(Availability.waiting));
    final player = await _open(t, store);
    // Set after opening: the spinner never settles.
    store.set(
      mangalaReadingId,
      _status(Availability.downloading, progress: 0.426),
    );
    await t.pump();

    final tappable = t.widget<Pressable>(
      find.descendant(of: _play, matching: find.byType(Pressable)),
    );
    expect(tappable.onTap, isNull);
    expect(_rowText(t), contains('42%'));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_download, findsNothing);

    await t.tap(_play, warnIfMissed: false);
    await t.pump();
    expect(store.downloads, isEmpty);
    expect(player.loaded, isEmpty);
  });

  testWidgets('a failed recording shows its reason and Try again', (t) async {
    final store = FakeRecordingStore()
      ..set(
        mangalaReadingId,
        _status(Availability.failed, reason: notOnServerMessage),
      );
    await _open(t, store);
    expect(_rowText(t), notOnServerMessage);
    expect(find.descendant(of: _download, matching: find.text('Try again')),
        findsOneWidget);

    await t.tap(_download);
    await t.pump();
    expect(store.downloads, [(await _recording(t)).path]);
  });

  testWidgets('a recording whose load failed plays when it arrives after '
      'Play', (t) async {
    final store = FakeRecordingStore()
      ..set(mangalaReadingId, _status(Availability.downloaded));
    final player = await _open(
      t,
      store,
      player: FakeChantPlayer(failOnLoad: true),
    );
    await t.tap(_play);
    await t.pump();
    expect(player.state.status, ChantStatus.failed);

    // The file went missing; Play asks for it again.
    store.set(mangalaReadingId, _status(Availability.waiting));
    await t.pump();
    await t.tap(_play);
    await t.pump();
    expect(store.downloads, hasLength(1));

    player.failOnLoad = false;
    store.set(mangalaReadingId, _status(Availability.downloaded));
    await t.pump();
    await t.pump();
    expect(player.loaded, hasLength(2));
    expect(player.state.status, ChantStatus.playing);
  });

  testWidgets('a failed load is not retried by every change in the store', (
    t,
  ) async {
    final store = FakeRecordingStore()
      ..set(mangalaReadingId, _status(Availability.downloaded));
    final player = await _open(
      t,
      store,
      player: FakeChantPlayer(failOnLoad: true),
    );
    await t.tap(_play);
    await t.pump();
    expect(player.loaded, hasLength(1));

    // Another recording downloading in the background.
    store.set('another-reading', _status(Availability.downloading));
    await t.pump();
    store.set('another-reading', _status(Availability.downloaded));
    await t.pump();
    expect(player.loaded, hasLength(1));
  });

  testWidgets('leaving the reader before the file arrives plays nothing', (
    t,
  ) async {
    final store = FakeRecordingStore()
      ..set(mangalaReadingId, _status(Availability.waiting));
    final player = await _open(t, store);

    await t.tap(_play);
    await t.pump();
    expect(store.downloads, hasLength(1));

    ProviderScope.containerOf(
      t.element(find.byType(Scaffold).first),
    ).read(routerProvider).go(Routes.settings);
    await t.pumpAndSettle();

    store.set(mangalaReadingId, _status(Availability.downloaded));
    await t.pump();
    await t.pump();
    expect(player.loaded, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('the bar of a reading without a recording is unchanged', (
    t,
  ) async {
    final store = FakeRecordingStore(everything: Availability.notDownloaded);
    await _open(
      t,
      store,
      id: realReadingId,
      library: await silentWandanaLibrary(t),
    );
    expect(find.byKey(const ValueKey('reader-play')), findsOneWidget);
    expect(_row, findsNothing);
  });
}
