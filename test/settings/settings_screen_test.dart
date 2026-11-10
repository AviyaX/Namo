import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/design/widgets/page_header.dart';
import 'package:buddhist_gatha/reader/auto_scroll.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/choosers.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/settings/setting_controls.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart' show PlaceholderCatalogue;
import '../support/pump_app.dart';
import '../support/test_content.dart';

Future<ProviderContainer> openSettings(
  WidgetTester t, {
  Size size = const Size(390, 2400),
  List<Override> extra = const [],
}) async {
  await pumpApp(t,
      overrides: [
        ...extra,
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

  const groupLabels = [
    'Appearance',
    'Reading',
    'Languages',
    'Audio',
    'Auto-scroll',
    'About Namo',
  ];

  // The card a group's label sits in.
  Finder group(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(SettingsGroup),
  );
  Finder inGroup(String label, Finder what) =>
      find.descendant(of: group(label), matching: what);
  Finder keyed(String key) => find.byKey(ValueKey(key));

  testWidgets('a label and its control are one row: no line between them',
      (t) async {
    await openSettings(t, size: const Size(390, 2400));
    Finder lines(String g) =>
        inGroup(g, find.byType(Divider));
    // Appearance and Reading hold one or three rows; Theme and its chooser
    // are a single row, so Appearance has no line at all.
    expect(lines('Appearance'), findsNothing);
    expect(lines('Languages'), findsNothing);
    // Reading: three rows, two lines; the layout label and chooser add none.
    expect(lines('Reading'), findsNWidgets(2));
  });

  testWidgets('Settings shows its six groups in order', (t) async {
    await openSettings(t, size: const Size(390, 2400));
    expect(find.byType(SettingsGroup), findsNWidgets(6));
    var last = -1.0;
    for (final label in groupLabels) {
      final y = t.getTopLeft(find.text(label)).dy;
      expect(y, greaterThan(last), reason: label);
      last = y;
    }
    expect(
      find.descendant(
        of: find.byType(PageHeader),
        matching: find.text('Settings'),
      ),
      findsOneWidget,
    );
    // Groups are 16 apart.
    final rects = [for (final l in groupLabels) t.getRect(group(l))];
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].top - rects[i - 1].bottom, 16);
    }
  });

  testWidgets('each control is inside its group', (t) async {
    await openSettings(t, size: const Size(390, 2400));
    expect(inGroup('Appearance', find.byType(ThemeChooser)), findsOneWidget);
    expect(inGroup('Appearance', find.text('Theme')), findsOneWidget);
    expect(inGroup('Reading', keyed('setting-text-size')), findsOneWidget);
    expect(inGroup('Reading', keyed('setting-line-spacing')), findsOneWidget);
    expect(inGroup('Reading', find.byType(LayoutChooser)), findsOneWidget);
    expect(
      inGroup('Reading', find.text('When two languages show')),
      findsOneWidget,
    );
    expect(inGroup('Languages', find.byType(LanguageChooser)), findsOneWidget);
    expect(inGroup('Languages', find.text('Choose one or two.')), findsOneWidget);
    expect(inGroup('Audio', find.byType(Switch)), findsOneWidget);
    expect(
      inGroup('Audio', find.text('Start auto-scroll when a recording starts')),
      findsOneWidget,
    );
    expect(
      inGroup('Auto-scroll', keyed('setting-scroll-speed')),
      findsOneWidget,
    );
    expect(
      inGroup('About Namo', find.text('Free. No ads. Works offline.')),
      findsOneWidget,
    );
    expect(inGroup('About Namo', find.text('Sources')), findsOneWidget);
  });

  testWidgets('Settings uses no SwitchListTile, Card or AppBar', (t) async {
    await openSettings(t, size: const Size(390, 2400));
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('the audio switch is one toggle with its label', (t) async {
    final h = t.ensureSemantics();
    final c = await openSettings(t, size: const Size(390, 2400));
    final node = find.bySemanticsLabel('Start auto-scroll when a recording starts');
    expect(node, findsOneWidget);
    expect(t.getSemantics(node), isSemantics(isToggled: false));
    expect(t.getSize(node).height, greaterThanOrEqualTo(48));
    await t.tap(node);
    await t.pump();
    expect(c.read(settingsProvider).autoScrollWithAudio, isTrue);
    expect(t.getSemantics(node), isSemantics(isToggled: true));
    h.dispose();
  });

  testWidgets('the group labels are headers for screen readers', (t) async {
    final h = t.ensureSemantics();
    await openSettings(t, size: const Size(390, 2400));
    for (final label in groupLabels) {
      expect(
        t.getSemantics(find.text(label)),
        isSemantics(label: label, isHeader: true),
        reason: label,
      );
    }
    h.dispose();
  });

  testWidgets('rows in a group are evenly padded, sliders not cramped',
      (t) async {
    await openSettings(t, size: const Size(390, 2400));
    final text = t.getRect(keyed('setting-text-size'));
    final line = t.getRect(keyed('setting-line-spacing'));
    // The gap between two sliders holds a divider and padding on both sides.
    expect(line.top - text.bottom, greaterThanOrEqualTo(24));
  });

  testWidgets('"No recordings are included yet." shows with the bundled content',
      (t) async {
    await openSettings(t, size: const Size(390, 2400));
    expect(find.text('No recordings are included yet.'), findsOneWidget);
    expect(inGroup('Audio', find.text('No recordings are included yet.')),
        findsOneWidget);
  });

  testWidgets('"No recordings are included yet." hides when a reading has one',
      (t) async {
    await openSettings(
      t,
      size: const Size(390, 2400),
      extra: [audioCatalogueProvider.overrideWithValue(PlaceholderCatalogue())],
    );
    expect(find.text('No recordings are included yet.'), findsNothing);
  });

  testWidgets('the last group scrolls clear of the navigation bar', (t) async {
    await openSettings(t, size: const Size(390, 844));
    await t.scrollUntilVisible(find.text('Sources'), 200,
        scrollable: find.byType(Scrollable).first);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await t.pump();
    final bar = t.getRect(find.byKey(const ValueKey('nav-bar')));
    expect(t.getRect(group('About Namo')).bottom, lessThan(bar.top));
  });

  for (final dark in [false, true]) {
    for (final w in [320.0, 360.0, 390.0, 600.0]) {
      testWidgets('Settings does not overflow at $w, ${dark ? 'dark' : 'light'}',
          (t) async {
        t.platformDispatcher.textScaleFactorTestValue = w == 320 ? 2.0 : 1.0;
        t.platformDispatcher.platformBrightnessTestValue =
            dark ? Brightness.dark : Brightness.light;
        addTearDown(() {
          t.platformDispatcher.clearTextScaleFactorTestValue();
          t.platformDispatcher.clearPlatformBrightnessTestValue();
        });
        await openSettings(t, size: Size(w, 800));
        for (var i = 0; i < 6; i++) {
          await t.drag(find.byType(Scrollable).first, const Offset(0, -400));
          await t.pump();
        }
        expect(t.takeException(), isNull);
      });
    }
  }

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
