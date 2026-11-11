import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/design/widgets/empty_state.dart';
import 'package:buddhist_gatha/design/widgets/floating_bar.dart';
import 'package:buddhist_gatha/design/widgets/not_found.dart';
import 'package:buddhist_gatha/library/library_screen.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';
import 'support/test_content.dart';

// The library loads at once; while it loads, a ring turns and never settles.
final _loaded = [
  contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
];

void main() {
  test('the flow editor\'s address', () {
    expect(Routes.flowEditor('flow-3'), '/library/flow/flow-3');
  });

  test("the Library's search address", () {
    expect(Routes.librarySearch, '/library?focus=search');
  });

  testWidgets('focus=search asks the Library to focus its search; other '
      'addresses do not', (t) async {
    await pumpApp(
      t,
      overrides: _loaded,
      location: Routes.librarySearch,
      settle: false,
    );
    expect(t.widget<LibraryScreen>(find.byType(LibraryScreen)).focusSearch, isTrue);
    await pumpApp(
      t,
      overrides: _loaded,
      location: '/library?focus=other',
      settle: false,
    );
    expect(t.widget<LibraryScreen>(find.byType(LibraryScreen)).focusSearch, isFalse);
  });

  testWidgets('four tabs switch screens', (t) async {
    await pumpApp(t, overrides: _loaded);
    for (final label in ['Home', 'Library', 'Saved', 'Settings']) {
      await t.tap(find.descendant(
        of: find.byKey(ValueKey('nav-${label.toLowerCase()}')),
        matching: find.text(label),
      ));
      await t.pumpAndSettle();
      expect(find.byKey(ValueKey('screen-${label.toLowerCase()}')), findsOneWidget);
    }
  });
  testWidgets('wide screens move the tabs to the side', (t) async {
    await pumpApp(t, overrides: _loaded, size: const Size(1280, 800));
    expect(find.byKey(const ValueKey('nav-rail')), findsOneWidget);
    expect(find.byType(FloatingBar), findsNothing);
  });
  testWidgets('an unknown address shows the not-found page, not an error', (t) async {
    await pumpApp(t, overrides: _loaded, location: '/no/such/place');
    expect(find.text('This page could not be found.'), findsOneWidget);
    await t.tap(find.text('Go to Home'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-home')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the not-found page is an empty-state with a Go to Home button',
      (t) async {
    await pumpApp(t, location: '/no/such/place');
    expect(find.byType(NotFoundScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.text('This page could not be found.'),
      ),
      findsOneWidget,
    );
    expect(find.byType(OutlinedButton), findsNothing);
  });
  for (final dark in [false, true]) {
    for (final w in [320.0, 360.0, 390.0, 840.0]) {
      testWidgets('not-found does not overflow at $w, ${dark ? 'dark' : 'light'}',
          (t) async {
        t.platformDispatcher.textScaleFactorTestValue = w == 320 ? 2.0 : 1.0;
        t.platformDispatcher.platformBrightnessTestValue =
            dark ? Brightness.dark : Brightness.light;
        addTearDown(() {
          t.platformDispatcher.clearTextScaleFactorTestValue();
          t.platformDispatcher.clearPlatformBrightnessTestValue();
        });
        await pumpApp(t, location: '/no/such/place', size: Size(w, 700));
        expect(find.text('Go to Home'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
