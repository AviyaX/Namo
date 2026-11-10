import 'package:buddhist_gatha/app.dart';
import 'package:buddhist_gatha/reader/screen_awake.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_screen_awake.dart';

/// Starts the app. The screen is never really kept on in tests: pass a
/// [screenAwake] to see the calls, otherwise a fresh fake is used.
Future<void> pumpApp(
  WidgetTester t, {
  List<Override> overrides = const [],
  String? location,
  Size size = const Size(390, 844),
  ScreenAwake? screenAwake,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        screenAwakeProvider.overrideWithValue(screenAwake ?? FakeScreenAwake()),
        if (location != null)
          routerProvider.overrideWith(
            (ref) => buildRouter(initialLocation: location),
          ),
      ],
      child: const NamoApp(),
    ),
  );
  await t.pumpAndSettle();
}
