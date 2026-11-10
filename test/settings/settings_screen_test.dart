import 'package:buddhist_gatha/content/content_repository.dart';
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

Future<ProviderContainer> openSettings(
  WidgetTester t, {
  Size size = const Size(390, 844),
}) async {
  await pumpApp(t,
      overrides: [
        contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      ],
      location: '/settings',
      size: size);
  return ProviderScope.containerOf(t.element(find.byType(Scaffold).first));
}

Finder row(String label) => find.bySemanticsLabel(RegExp('^$label'));

void main() {
  const third = 'Two languages at most. Switch one off first.';
  const last = 'One language always stays on.';

  testWidgets(
      'Settings: choosing a third language shows the message and changes nothing',
      (t) async {
    final c = await openSettings(t);
    await t.tap(row('English'));
    await t.pump();
    expect(find.text(third), findsOneWidget);
    expect(c.read(settingsProvider).languages.languages,
        [ReadingLanguage.pali, ReadingLanguage.sinhala]);
  });

  testWidgets('Settings: switching one off then another on changes the selection',
      (t) async {
    final c = await openSettings(t);
    await t.tap(row('Pali'));
    await t.pump();
    await t.tap(row('English'));
    await t.pump();
    expect(c.read(settingsProvider).languages.languages,
        [ReadingLanguage.sinhala, ReadingLanguage.english]);
  });

  testWidgets('Settings: a new message replaces the one showing', (t) async {
    await openSettings(t);
    await t.tap(row('Pali'));
    await t.pump();
    await t.tap(row('Sinhala'));
    await t.pump();
    expect(find.text(last), findsOneWidget);
    await t.tap(row('English'));
    await t.pump();
    await t.tap(row('Pali'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text(last), findsNothing);
    expect(find.text(third), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Settings: layout chooser is disabled with one language',
      (t) async {
    final c = await openSettings(t);
    final h = t.ensureSemantics();
    await t.tap(row('Section by section'));
    await t.pump();
    expect(c.read(settingsProvider).layout, TwoLanguageLayout.section);

    await t.tap(row('Pali'));
    await t.pump();
    for (final l in ['Section by section', 'Verse by verse']) {
      final node = t.getSemantics(row(l));
      expect(node.hint, 'Needs two languages');
    }
    await t.tap(row('Verse by verse'), warnIfMissed: false);
    await t.pump();
    expect(c.read(settingsProvider).layout, TwoLanguageLayout.section);
    h.dispose();
  });

  testWidgets('Settings: the reason for a disabled layout is visible text',
      (t) async {
    await openSettings(t);
    expect(find.text('Needs two languages'), findsNothing);
    await t.tap(row('Pali'));
    await t.pump();
    expect(find.text('Needs two languages'), findsOneWidget);
    await t.tap(row('English'));
    await t.pump();
    expect(find.text('Needs two languages'), findsNothing);
  });

  testWidgets('Settings: every chooser row is at least 48 tall', (t) async {
    await openSettings(t);
    for (final label in [
      'Sinhala',
      'English',
      'Pali',
      'Section by section',
      'Verse by verse'
    ]) {
      final size = t.getSize(row(label).first);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
  });

  testWidgets('NamoApp follows the saved theme mode', (t) async {
    final c = await openSettings(t);
    c.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
    await t.pumpAndSettle();
    expect(t.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark);
  });

  testWidgets('every Settings control changes the saved setting', (t) async {
    final c = await openSettings(t, size: const Size(390, 2400));
    AppSettings now() => c.read(settingsProvider);
    const d = AppSettings();

    // Languages and layout.
    await t.tap(row('Pali'));
    await t.pump();
    await t.tap(row('English'));
    await t.pump();
    expect(now().languages.languages,
        [ReadingLanguage.sinhala, ReadingLanguage.english]);
    await t.tap(row('Section by section'));
    await t.pump();
    expect(now().layout, TwoLanguageLayout.section);

    // Text size and line spacing.
    await t.drag(find.byKey(const ValueKey('setting-text-size')),
        const Offset(120, 0));
    await t.pump();
    expect(now().fontScale, greaterThan(d.fontScale));
    await t.drag(find.byKey(const ValueKey('setting-line-spacing')),
        const Offset(120, 0));
    await t.pump();
    expect(now().lineSpacing, greaterThan(d.lineSpacing));

    // Scroll speed: presets, then the slider.
    await t.tap(row('Fast'));
    await t.pump();
    expect(now().scrollSpeed, AutoScrollEngine.fast);
    await t.tap(row('Slow'));
    await t.pump();
    expect(now().scrollSpeed, AutoScrollEngine.slow);
    await t.drag(find.byKey(const ValueKey('setting-scroll-speed')),
        const Offset(60, 0));
    await t.pump();
    expect(now().scrollSpeed, greaterThan(AutoScrollEngine.slow));
    expect(find.text('Custom'), findsOneWidget);

    // Audio preference.
    expect(now().autoScrollWithAudio, isFalse);
    await t.tap(find.text('Start auto-scroll when a recording starts'));
    await t.pump();
    expect(now().autoScrollWithAudio, isTrue);

    // Theme.
    await t.tap(row('Light'));
    await t.pump();
    expect(now().themeMode, ThemeMode.light);
    await t.tap(row('Dark'));
    await t.pump();
    expect(now().themeMode, ThemeMode.dark);
    await t.tap(row('Same as device'));
    await t.pump();
    expect(now().themeMode, ThemeMode.system);
  });

  testWidgets('Settings shows its parts in order', (t) async {
    await openSettings(t, size: const Size(390, 2400));
    var last = -1.0;
    for (final label in [
      'Languages',
      'Layout',
      'Text size',
      'Line spacing',
      'Scroll speed',
      'Start auto-scroll when a recording starts',
      'Theme',
      'Sources',
    ]) {
      final y = t.getTopLeft(find.text(label).first).dy;
      expect(y, greaterThan(last), reason: label);
      last = y;
    }
  });

  testWidgets('choosing a theme changes the app theme at once', (t) async {
    await openSettings(t, size: const Size(390, 2400));
    ThemeMode mode() =>
        t.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
    Brightness shown() =>
        Theme.of(t.element(find.byType(Scaffold).first)).brightness;
    expect(mode(), ThemeMode.dark);
    await t.tap(row('Light'));
    await t.pumpAndSettle();
    expect(mode(), ThemeMode.light);
    expect(shown(), Brightness.light);
    await t.tap(row('Dark'));
    await t.pumpAndSettle();
    expect(mode(), ThemeMode.dark);
    expect(shown(), Brightness.dark);
  });

  testWidgets('Sources opens from Settings', (t) async {
    await openSettings(t, size: const Size(390, 2400));
    await t.tap(find.text('Sources'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-sources')), findsOneWidget);
    expect(Routes.sources, '/settings/sources');
  });

  testWidgets('on a wide screen the Settings column is capped and centred',
      (t) async {
    await openSettings(t, size: const Size(1600, 2400));
    final box = t.getRect(find.byKey(const ValueKey('settings-column')));
    expect(box.width, 680);
  });
}
