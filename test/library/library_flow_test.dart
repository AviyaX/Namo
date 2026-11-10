import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';

void main() {
  final fake = [
    contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
  ];

  testWidgets('Home -> category -> reading -> contents list shows every section',
      (t) async {
    await pumpApp(t, overrides: fake);
    expect(find.text('Namo'), findsOneWidget);
    await t.tap(find.text('category 1'));
    await t.pumpAndSettle();
    await t.tap(find.text('reading 1'));
    await t.pumpAndSettle();
    for (var i = 1; i <= 3; i++) {
      expect(find.text('heading $i'), findsOneWidget);
      expect(find.text('$i'), findsOneWidget);
    }
    expect(find.bySemanticsLabel('1, heading 1'), findsOneWidget);
    final row = t.getSize(find
        .ancestor(of: find.text('heading 1'), matching: find.byType(Container))
        .first);
    expect(row.height, greaterThanOrEqualTo(48));
  });

  testWidgets('the Library tab lists the category', (t) async {
    await pumpApp(t, overrides: fake, location: Routes.library);
    expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
    expect(find.text('category 1'), findsOneWidget);
  });

  testWidgets('tapping a section opens the reader placeholder', (t) async {
    await pumpApp(t, overrides: fake, location: Routes.contents('r1'));
    await t.tap(find.text('heading 2'));
    await t.pumpAndSettle();
    expect(find.text('The reader arrives in Stage 4.'), findsOneWidget);
  });

  testWidgets('a contents address for an unknown reading shows not-found',
      (t) async {
    await pumpApp(t, overrides: fake, location: Routes.contents('nope'));
    expect(find.text('This page could not be found.'), findsOneWidget);
  });

  testWidgets(
      'content that fails to load shows a plain message, not an error screen',
      (t) async {
    await pumpApp(t, overrides: [
      contentRepositoryProvider
          .overrideWithValue(FakeContentRepository(failWith: Exception('x'))),
    ]);
    expect(find.text('The text could not be loaded.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
