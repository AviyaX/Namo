import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/design/widgets/sheet_frame.dart';
import 'package:buddhist_gatha/reader/auto_scroll.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';

Future<ProviderContainer> openSheet(
  WidgetTester t, {
  Size size = const Size(390, 1400),
}) async {
  await pumpApp(
    t,
    size: size,
    overrides: [
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
    ],
    location: Routes.reader('r1'),
  );
  await t.tap(find.byKey(const ValueKey('reader-settings')));
  await t.pumpAndSettle();
  return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
}

void main() {
  testWidgets('shows its title and the controls in order', (t) async {
    await openSheet(t);
    expect(find.byType(SheetFrame), findsOneWidget);
    var last = -1.0;
    for (final f in [
      find.text('Reading settings'),
      find.text('Languages'),
      find.text('When two languages show'),
      find.text('Text size'),
      find.text('Line spacing'),
      find.text('Scroll speed'),
      find.text('Back to the beginning'),
    ]) {
      expect(f, findsOneWidget);
      final y = t.getTopLeft(f).dy;
      expect(y, greaterThan(last), reason: '$f');
      last = y;
    }
    expect(find.byType(QuietButton), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the three sliders change the settings', (t) async {
    final c = await openSheet(t);
    await t.drag(
      find.byKey(const ValueKey('reader-text-size')),
      const Offset(1000, 0),
    );
    await t.pumpAndSettle();
    expect(c.read(settingsProvider).fontScale, 1.6);
    await t.drag(
      find.byKey(const ValueKey('reader-line-spacing')),
      const Offset(-1000, 0),
    );
    await t.pumpAndSettle();
    expect(c.read(settingsProvider).lineSpacing, 1.3);
    await t.drag(
      find.byKey(const ValueKey('reader-scroll-speed')),
      const Offset(1000, 0),
    );
    await t.pumpAndSettle();
    expect(c.read(settingsProvider).scrollSpeed, 60);
  });

  testWidgets('the speed choices set the preset speeds', (t) async {
    final c = await openSheet(t);
    await t.tap(find.text('Fast'));
    await t.pumpAndSettle();
    expect(c.read(settingsProvider).scrollSpeed, AutoScrollEngine.fast);
    await t.tap(find.text('Slow'));
    await t.pumpAndSettle();
    expect(c.read(settingsProvider).scrollSpeed, AutoScrollEngine.slow);
  });

  testWidgets('Back to the beginning closes the sheet', (t) async {
    await openSheet(t);
    await t.tap(find.text('Back to the beginning'));
    await t.pumpAndSettle();
    expect(find.byType(SheetFrame), findsNothing);
  });

  testWidgets('a tap above the sheet closes it', (t) async {
    await openSheet(t, size: const Size(390, 844));
    await t.tapAt(const Offset(195, 20));
    await t.pumpAndSettle();
    expect(find.byType(SheetFrame), findsNothing);
  });

  testWidgets('the third-language message is visible, not behind the sheet', (
    t,
  ) async {
    final c = await openSheet(t);
    expect(c.read(settingsProvider).languages.languages, hasLength(2));
    final third = ReadingLanguage.values.firstWhere(
      (l) => !c.read(settingsProvider).languages.has(l),
    );
    await t.tap(
      find.descendant(
        of: find.byType(SheetFrame),
        matching: find.text(third.label),
      ),
    );
    await t.pumpAndSettle();
    final message = find.text('Two languages at most. Switch one off first.');
    expect(message, findsOneWidget);
    expect(message.hitTestable(), findsOneWidget);
    expect(c.read(settingsProvider).languages.languages, hasLength(2));
  });

  testWidgets('sliders have a sage track and thumb on a border track', (
    t,
  ) async {
    await openSheet(t);
    final p = NamoPalette.dark;
    for (final key in [
      'reader-text-size',
      'reader-line-spacing',
      'reader-scroll-speed',
    ]) {
      final theme = SliderTheme.of(t.element(find.byKey(ValueKey(key))));
      expect(theme.activeTrackColor, p.sage, reason: key);
      expect(theme.thumbColor, p.sage, reason: key);
      expect(theme.inactiveTrackColor, p.border, reason: key);
    }
  });
}
