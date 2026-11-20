import 'dart:convert';

import 'package:buddhist_gatha/audio/recording_store.dart';
import 'package:buddhist_gatha/audio/recording_store_provider.dart';
import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/widgets/progress_line.dart';
import 'package:buddhist_gatha/settings/recordings_group.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_recording_store.dart';

const _bytes = 2563097;

RecordingsSnapshot snapshot({
  int downloaded = 0,
  int downloading = 0,
  int waiting = 0,
  int failed = 0,
}) {
  final statuses = <String, RecordingStatus>{};
  var i = 0;
  void add(int n, Availability a, double progress) {
    for (var k = 0; k < n; k++) {
      statuses['r${i++}'] = RecordingStatus(
        availability: a,
        progress: progress,
        bytes: _bytes,
      );
    }
  }

  add(downloaded, Availability.downloaded, 1);
  add(downloading, Availability.downloading, 0.5);
  add(waiting, Availability.waiting, 0);
  add(failed, Availability.failed, 0);
  return RecordingsSnapshot(statuses);
}

Future<(FakeRecordingStore, InMemoryKeyValueStore)> _pump(
  WidgetTester t, {
  bool web = false,
  RecordingsSnapshot? initial,
}) async {
  t.view.physicalSize = const Size(390, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final kv = InMemoryKeyValueStore();
  final store = FakeRecordingStore();
  if (initial != null) store.snapshot.value = initial;
  final c = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(kv),
      recordingStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(c.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: namoTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(child: RecordingsGroup(web: web)),
        ),
      ),
    ),
  );
  return (store, kv);
}

const _summary = ValueKey('recordings-summary');
const _downloadAll = ValueKey('recordings-download-all');
const _remove = ValueKey('recordings-remove');

void main() {
  group('recordingsSummary', () {
    test('partly downloaded', () {
      expect(
        recordingsSummary(snapshot(downloaded: 12, waiting: 28)),
        '12 of 40 downloaded · 31 MB of 103 MB',
      );
    });

    test('everything downloaded', () {
      expect(
        recordingsSummary(snapshot(downloaded: 40)),
        'All 40 recordings downloaded · 103 MB',
      );
    });

    test('failed ones are counted', () {
      expect(
        recordingsSummary(snapshot(downloaded: 12, waiting: 25, failed: 3)),
        '12 of 40 downloaded · 31 MB of 103 MB · 3 could not be downloaded',
      );
    });

    test('nothing known is empty', () {
      expect(recordingsSummary(RecordingsSnapshot.empty), '');
    });
  });

  testWidgets('the chooser saves the setting', (t) async {
    final (_, kv) = await _pump(t, initial: snapshot(waiting: 40));
    await t.tap(find.text('Any connection'));
    await t.pump();
    final saved = kv.read(settingsKey);
    expect(jsonDecode(saved!)['autoDownload'], 'any');
  });

  testWidgets(
    'Download all now calls the store and disappears when everything is downloaded',
    (t) async {
      final (store, _) = await _pump(t, initial: snapshot(waiting: 40));
      expect(find.byKey(_downloadAll), findsOneWidget);
      await t.tap(find.byKey(_downloadAll));
      await t.pump();
      expect(store.downloadAllCalls, 1);
      store.snapshot.value = snapshot(downloaded: 40);
      await t.pump();
      expect(find.byKey(_downloadAll), findsNothing);
      expect(
        t.widget<Text>(find.byKey(_summary)).data,
        'All 40 recordings downloaded · 103 MB',
      );
    },
  );

  testWidgets('the progress bar shows only while downloading', (t) async {
    final (store, _) = await _pump(t, initial: snapshot(waiting: 40));
    expect(find.byType(ProgressLine), findsNothing);
    store.snapshot.value = snapshot(downloading: 1, waiting: 39);
    await t.pump();
    expect(find.byType(ProgressLine), findsOneWidget);
  });

  testWidgets('Remove asks first and then removes', (t) async {
    final (store, _) = await _pump(t, initial: snapshot(downloaded: 12, waiting: 28));
    await t.tap(find.byKey(_remove));
    await t.pumpAndSettle();
    expect(find.textContaining('of recordings from this device?'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('recordings-remove-keep')));
    await t.pumpAndSettle();
    expect(store.removeAllCalls, 0);
    await t.tap(find.byKey(_remove));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('recordings-remove-confirm')));
    await t.pumpAndSettle();
    expect(store.removeAllCalls, 1);
  });

  testWidgets('with nothing downloaded yet Remove offers to stop the queue', (
    t,
  ) async {
    final (store, _) = await _pump(t, initial: snapshot(waiting: 40));
    await t.tap(find.byKey(_remove));
    await t.pumpAndSettle();
    expect(
      find.text('Stop the queued downloads? Nothing has been downloaded yet.'),
      findsOneWidget,
    );
    final confirm = find.byKey(const ValueKey('recordings-remove-confirm'));
    expect(find.descendant(of: confirm, matching: find.text('Stop')),
        findsOneWidget);
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(store.removeAllCalls, 1);
  });

  testWidgets('on the web the group has only the sentence', (t) async {
    await _pump(t, web: true, initial: snapshot(waiting: 40));
    expect(
      find.text('In the browser, recordings play from the internet when you press play.'),
      findsOneWidget,
    );
    expect(find.text('Any connection'), findsNothing);
    expect(find.byKey(_downloadAll), findsNothing);
    expect(find.byKey(_remove), findsNothing);
    expect(find.byKey(_summary), findsNothing);
  });

  testWidgets('with no recordings known there is no summary and no buttons', (t) async {
    await _pump(t);
    expect(find.byKey(_summary), findsNothing);
    expect(find.byKey(_downloadAll), findsNothing);
    expect(find.byKey(_remove), findsNothing);
    expect(find.text('Any connection'), findsOneWidget);
  });
}
