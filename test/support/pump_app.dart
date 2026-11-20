import 'package:buddhist_gatha/app.dart';
import 'package:buddhist_gatha/audio/recording_store.dart';
import 'package:buddhist_gatha/audio/recording_store_provider.dart';
import 'package:buddhist_gatha/books/books_repository.dart';
import 'package:buddhist_gatha/reader/screen_awake.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/tips/tips.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../books/books_support.dart';
import '../tipitaka/tipitaka_support.dart';
import 'fake_recording_store.dart';
import 'fake_screen_awake.dart';

/// Starts the app. The screen is never really kept on in tests: pass a
/// [screenAwake] to see the calls, otherwise a fresh fake is used. [books]
/// serves the books' files (by default [noBooks], so the Library has no
/// shelf), parsed on the test's own clock; no test reads the real bundle.
/// [openReal] serves the made-up [tinyBooks] instead.
Future<void> pumpApp(
  WidgetTester t, {
  List<Override> overrides = const [],
  String? location,
  Size size = const Size(390, 844),
  ScreenAwake? screenAwake,
  RecordingStore? recordingStore,
  bool settle = true,
  bool tips = false,
  AssetBytes? books,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        screenAwakeProvider.overrideWithValue(screenAwake ?? FakeScreenAwake()),
        tipsAllowedProvider.overrideWithValue(tips),
        recordingStoreProvider.overrideWithValue(
          recordingStore ?? FakeRecordingStore(),
        ),
        booksRepositoryProvider.overrideWithValue(
          BooksRepository(
            load: books ?? fakeAssets(noBooks()),
            inBackground: false,
          ),
        ),
        if (location != null)
          routerProvider.overrideWith(
            (ref) => buildRouter(initialLocation: location),
          ),
      ],
      child: const NamoApp(),
    ),
  );
  if (settle) await t.pumpAndSettle();
}
