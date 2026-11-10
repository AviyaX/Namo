import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';

void main() {
  testWidgets(
    'Home shows Continue reading only after something was read, and reopens at that place',
    (t) async {
      await pumpApp(
        t,
        overrides: [
          contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );
      expect(find.text('Continue reading'), findsNothing);
      expect(find.text('category 1'), findsOneWidget);

      final c = ProviderScope.containerOf(t.element(find.byType(Scaffold).first));
      c
          .read(positionProvider.notifier)
          .save(
            const ReadingPosition(
              readingId: 'r1',
              sectionId: 's02',
              fraction: 0,
            ),
            0.5,
          );
      await t.pumpAndSettle();

      expect(find.text('Continue reading'), findsOneWidget);
      expect(find.text('reading 1'), findsOneWidget);
      expect(find.text('heading 2'), findsOneWidget);
      final line = t.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(line.value, 0.5);
      expect(
        find.bySemanticsLabel(RegExp('^Continue reading, reading 1')),
        findsOneWidget,
      );

      await t.tap(find.text('reading 1'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('heading-s02')), findsOneWidget);
    },
  );

  testWidgets('Continue reading is absent when the reading is not in the content',
      (t) async {
    final store = InMemoryKeyValueStore();
    await pumpApp(
      t,
      overrides: [
        contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
        keyValueStoreProvider.overrideWithValue(store),
      ],
    );
    final c = ProviderScope.containerOf(t.element(find.byType(Scaffold).first));
    c
        .read(positionProvider.notifier)
        .save(
          const ReadingPosition(
            readingId: 'gone',
            sectionId: 's01',
            fraction: 0,
          ),
          0.2,
        );
    await t.pumpAndSettle();
    expect(find.text('Continue reading'), findsNothing);
  });
}
