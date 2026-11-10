import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/home/featured_card.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';

Future<ProviderContainer> openAt(WidgetTester t, String location) async {
  await t.pumpWidget(const SizedBox());
  await pumpApp(
    t,
    overrides: [
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
    ],
    location: location,
  );
  return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
}

/// The two ways back: the system Back (Android button or gesture, browser
/// Back handled by the router) and the arrow in the reader's top bar.
enum Way { system, arrow }

Future<void> goBack(WidgetTester t, Way way) async {
  expect(find.byType(ReaderBody), findsOneWidget);
  switch (way) {
    case Way.system:
      await t.binding.handlePopRoute();
    case Way.arrow:
      await t.tap(find.byTooltip('Back'));
  }
  await t.pumpAndSettle();
  expect(find.byType(ReaderBody), findsNothing);
  expect(t.takeException(), isNull);
}

/// The Library, with the sections of the reading's category showing.
void expectLibraryWithListOpen() {
  expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
  expect(find.bySemanticsLabel('1, heading 1'), findsOneWidget);
}

void main() {
  for (final way in Way.values) {
    testWidgets('${way.name} Back: opened from a Home card, back to Home', (
      t,
    ) async {
      await openAt(t, Routes.home);
      await t.tap(find.byType(FeaturedCard));
      await t.pumpAndSettle();
      await goBack(t, way);
      expect(find.byKey(const ValueKey('screen-home')), findsOneWidget);
    });

    testWidgets('${way.name} Back: opened from Continue reading, back to '
        'Home', (t) async {
      final c = await openAt(t, Routes.home);
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
      await t.tap(find.text('Continue reading'));
      await t.pumpAndSettle();
      await goBack(t, way);
      expect(find.byKey(const ValueKey('screen-home')), findsOneWidget);
    });

    testWidgets('${way.name} Back: opened from a Library section row, back '
        'to the Library with the list open', (t) async {
      await openAt(t, Routes.library);
      await t.tap(find.text('category 1'));
      await t.pumpAndSettle();
      await t.tap(find.text('heading 2'));
      await t.pumpAndSettle();
      await goBack(t, way);
      expectLibraryWithListOpen();
    });

    testWidgets('${way.name} Back: opened from Saved, back to Saved', (
      t,
    ) async {
      final c = await openAt(t, Routes.saved);
      c.read(savedProvider.notifier).toggleBookmark('r1', 's02');
      c.read(savedProvider.notifier).toggleFavourite('r1');
      await t.pumpAndSettle();

      await t.tap(find.text('heading 2'));
      await t.pumpAndSettle();
      await goBack(t, way);
      expect(find.byKey(const ValueKey('screen-saved')), findsOneWidget);

      await t.tap(find.text('reading 1').last);
      await t.pumpAndSettle();
      await goBack(t, way);
      expect(find.byKey(const ValueKey('screen-saved')), findsOneWidget);
    });

    testWidgets('${way.name} Back: opened by address, back to the Library '
        'with the list open', (t) async {
      await openAt(t, Routes.reader('r1'));
      await goBack(t, way);
      expectLibraryWithListOpen();
    });
  }
}
