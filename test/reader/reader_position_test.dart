import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';

/// Starts a fresh app at [location] on [store]; calling it again with the
/// same store is like opening the app again.
Future<ProviderContainer> openAt(
  WidgetTester t,
  String location,
  KeyValueStore store,
) async {
  await t.pumpWidget(const SizedBox());
  await pumpApp(
    t,
    overrides: [
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      keyValueStoreProvider.overrideWithValue(store),
    ],
    location: location,
  );
  return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
}

ScrollController scroll(WidgetTester t) =>
    t.state<ReaderBodyState>(find.byType(ReaderBody)).controller;

double bodyTop(WidgetTester t) => t.getTopLeft(find.byType(ReaderBody)).dy;

/// How far [key]'s top is from the top of the reading area.
double distanceFromTop(WidgetTester t, String key) =>
    t.getTopLeft(find.byKey(ValueKey(key))).dy - bodyTop(t);

void expectAtTop(WidgetTester t, String key, {double within = 2}) {
  expect(
    distanceFromTop(t, key).abs(),
    lessThan(within),
    reason: '$key should be at the top',
  );
}

/// Scrolls so the top of [key] is at the top of the reading area.
Future<void> scrollToTop(WidgetTester t, String key) async {
  final c = scroll(t);
  c.jumpTo(c.offset + distanceFromTop(t, key));
  await t.pump();
  expectAtTop(t, key, within: 1);
}

/// Lets the 400 ms save after scrolling happen.
Future<void> waitForSave(WidgetTester t) =>
    t.pump(const Duration(milliseconds: 500));

Finder inHeading(String sectionId, Finder f) => find.descendant(
  of: find.byKey(ValueKey('heading-$sectionId')),
  matching: f,
);

Icon iconOf(WidgetTester t, Finder button) =>
    t.widget<Icon>(find.descendant(of: button, matching: find.byType(Icon)));

void main() {
  testWidgets('changing text size keeps the same verse at the top', (t) async {
    final c = await openAt(t, Routes.reader('r1'), InMemoryKeyValueStore());
    await scrollToTop(t, 'verse-s02-v1-pi');
    final before = scroll(t).offset;

    c.read(settingsProvider.notifier).setFontScale(1.6);
    await t.pumpAndSettle();
    expect(scroll(t).offset, isNot(closeTo(before, 1)));
    expectAtTop(t, 'verse-s02-v1-pi');
    expect(t.takeException(), isNull);
  });

  testWidgets('changing line spacing and layout keeps the same verse at the '
      'top', (t) async {
    final c = await openAt(t, Routes.reader('r1'), InMemoryKeyValueStore());
    await scrollToTop(t, 'verse-s01-v2-pi');

    c.read(settingsProvider.notifier).setLineSpacing(2.2);
    await t.pumpAndSettle();
    expectAtTop(t, 'verse-s01-v2-pi');

    c.read(settingsProvider.notifier).setLayout(TwoLanguageLayout.section);
    await t.pumpAndSettle();
    expectAtTop(t, 'verse-s01-v2-pi');
    expect(t.takeException(), isNull);
  });

  testWidgets('the second language at the top stays at the top through text '
      'size and layout changes', (t) async {
    final c = await openAt(t, Routes.reader('r1'), InMemoryKeyValueStore());
    await scrollToTop(t, 'verse-s02-v1-si');

    c.read(settingsProvider.notifier).setFontScale(1.6);
    await t.pumpAndSettle();
    expectAtTop(t, 'verse-s02-v1-si');

    c.read(settingsProvider.notifier).setLayout(TwoLanguageLayout.section);
    await t.pumpAndSettle();
    expectAtTop(t, 'verse-s02-v1-si');

    c.read(settingsProvider.notifier).setLineSpacing(2.2);
    await t.pumpAndSettle();
    expectAtTop(t, 'verse-s02-v1-si');
    expect(t.takeException(), isNull);
  });

  testWidgets('a narrower window keeps the same verse at the top', (t) async {
    await openAt(t, Routes.reader('r1'), InMemoryKeyValueStore());
    await scrollToTop(t, 'verse-s02-v1-pi');
    final before = scroll(t).offset;

    // At this width the first heading wraps onto a second line.
    t.view.physicalSize = const Size(250, 844);
    await t.pumpAndSettle();
    expect(scroll(t).offset, isNot(closeTo(before, 1)));
    expectAtTop(t, 'verse-s02-v1-pi');
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'switching to a language the section lacks keeps the reader in that '
    'section',
    (t) async {
      final c = await openAt(t, Routes.reader('r1'), InMemoryKeyValueStore());
      await scrollToTop(t, 'verse-s02-v1-pi');

      final settings = c.read(settingsProvider.notifier);
      settings.toggleLanguage(ReadingLanguage.pali);
      settings.toggleLanguage(ReadingLanguage.english);
      settings.toggleLanguage(ReadingLanguage.sinhala);
      await t.pumpAndSettle();
      expect(c.read(settingsProvider).languages.languages, [
        ReadingLanguage.english,
      ]);
      expect(find.byKey(const ValueKey('verse-s02-v1-pi')), findsNothing);
      expectAtTop(t, 'heading-s02');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('leaving and reopening the reader restores the position', (
    t,
  ) async {
    final store = InMemoryKeyValueStore();
    var c = await openAt(t, Routes.reader('r1'), store);
    // Opening does not overwrite anything with the top of the page.
    await waitForSave(t);
    expect(c.read(positionProvider).byReading, isEmpty);

    await scrollToTop(t, 'verse-s02-v1-pi');
    await waitForSave(t);
    var saved = c.read(positionProvider);
    expect(saved.lastReadingId, 'r1');
    expect(saved.byReading['r1']!.position.verseId, 's02-v1');
    expect(saved.byReading['r1']!.progress, greaterThan(0));

    final router = c.read(routerProvider);
    router.go(Routes.contents('r1'));
    await t.pumpAndSettle();
    expect(find.byType(ReaderBody), findsNothing);
    router.go(Routes.reader('r1'));
    await t.pumpAndSettle();
    expectAtTop(t, 'verse-s02-v1-pi');

    // Leaving straight after scrolling still saves where the page is.
    await scrollToTop(t, 'verse-s01-v2-si');
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(find.byType(ReaderBody), findsNothing);
    saved = c.read(positionProvider);
    expect(saved.byReading['r1']!.position.verseId, 's01-v2');

    // The place is kept in the store: a new start of the app finds it.
    // It comes back to the same language's text of the verse.
    c = await openAt(t, Routes.reader('r1'), store);
    expectAtTop(t, 'verse-s01-v2-si');

    // Going to the background saves without waiting.
    await scrollToTop(t, 'heading-s03');
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(c.read(positionProvider).byReading['r1']!.position.sectionId, 's03');
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    // Opening at a section goes to that section, not the saved place.
    await openAt(t, Routes.reader('r1', sectionId: 's02'), store);
    expectAtTop(t, 'heading-s02');
    expect(t.takeException(), isNull);
  });

  testWidgets('the progress line follows the page and is announced', (t) async {
    await openAt(t, Routes.reader('r1'), InMemoryKeyValueStore());
    final line = find.bySemanticsLabel('Reading progress');
    expect(line, findsOneWidget);
    expect(t.getSemantics(line).value, '0%');

    final c = scroll(t);
    c.jumpTo(c.position.maxScrollExtent / 2);
    await t.pump();
    expect(t.getSemantics(line).value, '50%');
    c.jumpTo(c.position.maxScrollExtent);
    await t.pump();
    expect(t.getSemantics(line).value, '100%');
  });

  testWidgets(
    'bookmark and favourite buttons toggle and announce their state',
    (t) async {
      final c = await openAt(t, Routes.reader('r1'), InMemoryKeyValueStore());
      final palette = NamoPalette.light;
      expect(find.byTooltip('Bookmark this section'), findsNWidgets(3));
      expect(find.byTooltip('Remove bookmark'), findsNothing);

      final off = inHeading('s02', find.byTooltip('Bookmark this section'));
      final offButton = find.ancestor(
        of: off,
        matching: find.byType(IconButton),
      );
      final size = t.getSize(offButton);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      // To the right of the heading's words.
      expect(
        t.getTopLeft(offButton).dx,
        greaterThan(t.getTopRight(find.text('heading 2')).dx),
      );
      expect(iconOf(t, offButton).icon, Icons.bookmark_border);
      expect(iconOf(t, offButton).color, palette.textQuiet);
      expect(
        t.getSemantics(off),
        isSemantics(tooltip: 'Bookmark this section', isButton: true),
      );

      await t.tap(off);
      await t.pump();
      final on = inHeading('s02', find.byTooltip('Remove bookmark'));
      expect(on, findsOneWidget);
      final onButton = find.ancestor(of: on, matching: find.byType(IconButton));
      expect(iconOf(t, onButton).icon, Icons.bookmark);
      expect(iconOf(t, onButton).color, palette.accent);
      expect(
        t.getSemantics(on),
        isSemantics(tooltip: 'Remove bookmark', isButton: true),
      );
      expect(c.read(savedProvider).isBookmarked('r1', 's02'), isTrue);

      await t.tap(inHeading('s01', find.byTooltip('Bookmark this section')));
      await t.pump();
      expect(find.byTooltip('Remove bookmark'), findsNWidgets(2));
      expect(c.read(savedProvider).bookmarks.first.sectionId, 's01');

      await t.tap(on);
      await t.pump();
      expect(c.read(savedProvider).isBookmarked('r1', 's02'), isFalse);
      expect(
        inHeading('s02', find.byTooltip('Bookmark this section')),
        findsOneWidget,
      );

      // Favourite.
      final add = find.byTooltip('Add to favourites');
      expect(
        t.getSemantics(add),
        isSemantics(tooltip: 'Add to favourites', isButton: true),
      );
      expect(
        iconOf(
          t,
          find.ancestor(of: add, matching: find.byType(IconButton)),
        ).icon,
        Icons.favorite_border,
      );
      await t.tap(add);
      await t.pump();
      final remove = find.byTooltip('Remove from favourites');
      expect(remove, findsOneWidget);
      expect(find.byTooltip('Add to favourites'), findsNothing);
      expect(
        t.getSemantics(remove),
        isSemantics(tooltip: 'Remove from favourites', isButton: true),
      );
      final heart = iconOf(
        t,
        find.ancestor(of: remove, matching: find.byType(IconButton)),
      );
      expect(heart.icon, Icons.favorite);
      expect(heart.color, palette.accent);
      expect(c.read(savedProvider).isFavourite('r1'), isTrue);

      await t.tap(remove);
      await t.pump();
      expect(find.byTooltip('Add to favourites'), findsOneWidget);
      expect(c.read(savedProvider).isFavourite('r1'), isFalse);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Back to the beginning returns to the top and clears the saved position',
    (t) async {
      final store = InMemoryKeyValueStore();
      final c = await openAt(t, Routes.reader('r1'), store);
      await scrollToTop(t, 'heading-s03');
      await waitForSave(t);
      expect(c.read(positionProvider).byReading['r1'], isNotNull);

      await t.tap(find.byKey(const ValueKey('reader-settings')));
      await t.pumpAndSettle();
      final back = find.text('Back to the beginning');
      await t.ensureVisible(back);
      await t.pumpAndSettle();
      await t.tap(back);
      await t.pumpAndSettle();
      await waitForSave(t);

      expect(find.text('Back to the beginning'), findsNothing);
      expect(scroll(t).offset, 0);
      expectAtTop(t, 'heading-s01');
      expect(c.read(positionProvider).byReading['r1'], isNull);
      expect(c.read(positionProvider).lastReadingId, isNull);
      expect(
        t.getSemantics(find.bySemanticsLabel('Reading progress')).value,
        '0%',
      );

      // Leaving now does not bring the old place back.
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(c.read(positionProvider).byReading['r1'], isNull);
      await openAt(t, Routes.reader('r1'), store);
      expect(scroll(t).offset, 0);
      expect(t.takeException(), isNull);
    },
  );
}
