import 'dart:async';

import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/widgets/empty_state.dart';
import 'package:buddhist_gatha/design/tokens.dart';
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

  testWidgets('the error state is an empty-state with the same wording',
      (t) async {
    await pumpApp(t, overrides: [
      contentRepositoryProvider
          .overrideWithValue(FakeContentRepository(failWith: Exception('x'))),
    ]);
    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.text('The text could not be loaded.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('while loading, a centred 24 sage ring shows', (t) async {
    final pending = Completer<Library>();
    await pumpApp(t, overrides: [
      contentRepositoryProvider
          .overrideWithValue(_PendingRepository(pending.future)),
    ], settle: false);
    final ring = find.byType(CircularProgressIndicator);
    expect(ring, findsWidgets);
    final indicator = t.widget<CircularProgressIndicator>(ring.first);
    expect(indicator.color, NamoPalette.dark.sage);
    expect(t.getSize(find.ancestor(
      of: ring.first,
      matching: find.byType(SizedBox),
    ).first), const Size(24, 24));
    expect(find.text('The text could not be loaded.'), findsNothing);
    pending.complete(testLibrary());
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

class _PendingRepository implements ContentRepository {
  _PendingRepository(this.library);
  final Future<Library> library;
  @override
  Future<Library> load() => library;
}
