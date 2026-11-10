import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('four tabs switch screens', (t) async {
    await pumpApp(t);
    for (final label in ['Home', 'Library', 'Saved', 'Settings']) {
      await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
      await t.pumpAndSettle();
      expect(find.byKey(ValueKey('screen-${label.toLowerCase()}')), findsOneWidget);
    }
  });
  testWidgets('wide screens move the tabs to the side', (t) async {
    await pumpApp(t, size: const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
  testWidgets('an unknown address shows the not-found page, not an error', (t) async {
    await pumpApp(t, location: '/no/such/place');
    expect(find.text('This page could not be found.'), findsOneWidget);
    await t.tap(find.text('Go to Home'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-home')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
