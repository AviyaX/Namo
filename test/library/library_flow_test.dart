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

  testWidgets('the Library tab lists the category', (t) async {
    await pumpApp(t, overrides: fake, location: Routes.library);
    expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
    expect(find.text('category 1'), findsOneWidget);
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
