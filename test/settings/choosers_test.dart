import 'dart:convert';

import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/reader/reader_settings_sheet.dart';
import 'package:buddhist_gatha/settings/auto_download.dart';
import 'package:buddhist_gatha/settings/choosers.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _third = 'Two languages at most. Switch one off first.';
const _last = 'One language always stays on.';

Future<(ProviderContainer, InMemoryKeyValueStore)> _pump(
  WidgetTester t,
  Widget child,
) async {
  t.view.physicalSize = const Size(390, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final store = InMemoryKeyValueStore();
  final c = ProviderContainer(overrides: [keyValueStoreProvider.overrideWithValue(store)]);
  addTearDown(c.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: namoTheme(Brightness.light),
          darkTheme: namoTheme(Brightness.dark),
          themeMode: ref.watch(settingsProvider).themeMode,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
  return (c, store);
}

Finder _tapLabel(String l) => find.text(l);

Future<ProviderContainer> _openSheet(WidgetTester t, {required bool bookMode}) async {
  final (c, _) = await _pump(
    t,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => showReaderSettingsSheet(
          context,
          onBackToBeginning: () {},
          textOnly: true,
          bookMode: bookMode,
        ),
        child: const Text('open'),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('the book reader sheet shows Pages / Scroll above text size',
      (t) async {
    final c = await _openSheet(t, bookMode: true);
    expect(find.text('Pages'), findsOneWidget);
    expect(find.text('Scroll'), findsOneWidget);
    expect(
      t.getTopLeft(find.byKey(const ValueKey('book-reading-mode'))).dy,
      lessThan(t.getTopLeft(find.byKey(const ValueKey('reader-text-size'))).dy),
    );
    await t.tap(find.text('Scroll'));
    await t.pumpAndSettle();
    expect(c.read(settingsProvider).bookReadingMode, BookReadingMode.scroll);
  });

  testWidgets('the book sheet shows Paper: Cream / Dark under Pages / Scroll',
      (t) async {
    final c = await _openSheet(t, bookMode: true);
    expect(find.text('Paper'), findsOneWidget);
    final paper = find.byKey(const ValueKey('book-paper'));
    final cream = find.descendant(of: paper, matching: find.text('Cream'));
    final dark = find.descendant(of: paper, matching: find.text('Dark'));
    expect(cream, findsOneWidget);
    expect(dark, findsOneWidget);
    expect(
      t.getTopLeft(find.byKey(const ValueKey('book-paper'))).dy,
      greaterThan(
          t.getTopLeft(find.byKey(const ValueKey('book-reading-mode'))).dy),
    );
    await t.tap(dark);
    await t.pumpAndSettle();
    expect(c.read(settingsProvider).bookPaper, BookPaper.dark);
  });

  testWidgets('the Tripitaka sheet has no Paper chooser', (t) async {
    await _openSheet(t, bookMode: false);
    expect(find.text('Paper'), findsNothing);
    expect(find.byKey(const ValueKey('book-paper')), findsNothing);
  });

  test('bookColours gives the cream tokens for cream in both palettes', () {
    for (final p in [NamoPalette.dark, NamoPalette.light]) {
      final c = bookColours(p, BookPaper.cream);
      expect(c.paper, const Color(0xFFF7EFDC));
      expect(c.ink, const Color(0xFF2A2A22));
      expect(c.inkSoft, const Color(0xFF8A7A55));
      expect(c.inkSecondary, const Color(0xFF6E6042));
      expect(c.cover, const Color(0xFF5B3A22));
      expect(c.rule, const Color(0xFFD2B26C));
      final d = bookColours(p, BookPaper.dark);
      expect(d.paper, NamoPalette.dark.surface);
      expect(d.ink, NamoPalette.dark.text);
      expect(d.cover, const Color(0xFF3A2616));
      expect(d.rule, const Color(0x99D2B26C));
    }
  });

  testWidgets('the Tripitaka sheet has no Pages / Scroll', (t) async {
    await _openSheet(t, bookMode: false);
    expect(find.text('Pages'), findsNothing);
    expect(find.byKey(const ValueKey('book-reading-mode')), findsNothing);
  });

  group('LanguageChooser', () {
    testWidgets('a third language is refused with the message', (t) async {
      final (c, _) = await _pump(t, const LanguageChooser());
      await t.tap(_tapLabel('English'));
      await t.pump();
      expect(find.text(_third), findsOneWidget);
      expect(c.read(settingsProvider).languages.languages,
          [ReadingLanguage.pali, ReadingLanguage.sinhala]);
    });

    testWidgets('the last language cannot be switched off', (t) async {
      final (c, _) = await _pump(t, const LanguageChooser());
      await t.tap(_tapLabel('Sinhala'));
      await t.pump();
      await t.tap(_tapLabel('Pali'));
      await t.pump();
      expect(find.text(_last), findsOneWidget);
      expect(c.read(settingsProvider).languages.languages, [ReadingLanguage.pali]);
    });

    testWidgets('switching one off then another on stores the pair', (t) async {
      final (c, _) = await _pump(t, const LanguageChooser());
      await t.tap(_tapLabel('Sinhala'));
      await t.pump();
      await t.tap(_tapLabel('English'));
      await t.pump();
      expect(c.read(settingsProvider).languages.languages,
          [ReadingLanguage.pali, ReadingLanguage.english]);
    });
  });

  group('LayoutChooser', () {
    testWidgets('is disabled with one language and says why', (t) async {
      final (c, _) = await _pump(t, const LayoutChooser());
      expect(find.text('Needs two languages'), findsNothing);
      c.read(settingsProvider.notifier).toggleLanguage(ReadingLanguage.sinhala);
      await t.pump();
      expect(find.text('Needs two languages'), findsOneWidget);
      final before = c.read(settingsProvider).layout;
      await t.tap(_tapLabel('Section by section'), warnIfMissed: false);
      await t.pump();
      expect(c.read(settingsProvider).layout, before);
      expect(t.widget<Text>(find.text('Needs two languages')).style!.color,
          NamoPalette.of(t.element(find.byType(LayoutChooser))).textSecondary);
    });

    testWidgets('three segments; side by side stores for Pali and Sinhala', (t) async {
      final (c, _) = await _pump(t, const LayoutChooser());
      for (final l in ['Section by section', 'Verse by verse', 'Side by side']) {
        expect(_tapLabel(l), findsOneWidget, reason: l);
      }
      await t.tap(_tapLabel('Side by side'));
      await t.pump();
      expect(c.read(settingsProvider).layout, TwoLanguageLayout.sideBySide);
    });

    testWidgets('side by side is refused with the message for Pali and English', (t) async {
      final (c, _) = await _pump(t, const Column(children: [LanguageChooser(), LayoutChooser()]));
      await t.tap(_tapLabel('Sinhala'));
      await t.pump();
      await t.tap(_tapLabel('English'));
      await t.pump();
      await t.tap(_tapLabel('Side by side'));
      await t.pump();
      expect(find.text('Side by side needs Pali and Sinhala.'), findsOneWidget);
      expect(c.read(settingsProvider).layout, TwoLanguageLayout.verse);
    });

    testWidgets('the chooser shows the effective layout when the pair changes', (t) async {
      final (c, _) = await _pump(t, const Column(children: [LanguageChooser(), LayoutChooser()]));
      c.read(settingsProvider.notifier).setLayout(TwoLanguageLayout.sideBySide);
      await t.pump();
      await t.tap(_tapLabel('Sinhala'));
      await t.pump();
      await t.tap(_tapLabel('English'));
      await t.pump();
      expect(c.read(settingsProvider).layout, TwoLanguageLayout.sideBySide);
      // The thumb sits on Verse by verse: segment index 1 of the layout selector.
      final thumb = t.getRect(find.byKey(const ValueKey('selector-thumb')).last);
      final verse = t.getRect(_tapLabel('Verse by verse'));
      expect(thumb.left, lessThanOrEqualTo(verse.left));
      expect(thumb.right, greaterThanOrEqualTo(verse.right));
    });

    testWidgets('the pirith chooser has Meaning below and Side by side', (t) async {
      final (c, _) = await _pump(t, const LayoutChooser(pirith: true));
      expect(_tapLabel('Meaning below'), findsOneWidget);
      expect(_tapLabel('Side by side'), findsOneWidget);
      expect(_tapLabel('Verse by verse'), findsNothing);
      await t.tap(_tapLabel('Side by side'));
      await t.pump();
      expect(c.read(settingsProvider).layout, TwoLanguageLayout.sideBySide);
      await t.tap(_tapLabel('Meaning below'));
      await t.pump();
      expect(c.read(settingsProvider).layout, TwoLanguageLayout.verse);
      c.read(settingsProvider.notifier).setLayout(TwoLanguageLayout.section);
      await t.pump();
      await t.tap(_tapLabel('Meaning below'));
      await t.pump();
      expect(c.read(settingsProvider).layout, TwoLanguageLayout.section, reason: 'left alone');
    });

    testWidgets('with two languages a tap stores the layout', (t) async {
      final (c, _) = await _pump(t, const LayoutChooser());
      await t.tap(_tapLabel('Section by section'));
      await t.pump();
      expect(c.read(settingsProvider).layout, TwoLanguageLayout.section);
      await t.tap(_tapLabel('Verse by verse'));
      await t.pump();
      expect(c.read(settingsProvider).layout, TwoLanguageLayout.verse);
    });
  });

  group('ThemeChooser', () {
    testWidgets('stores the mode and the app theme follows', (t) async {
      final (c, store) = await _pump(t, const ThemeChooser());
      Brightness shown() => Theme.of(t.element(find.byType(ThemeChooser))).brightness;
      String? saved() =>
          (jsonDecode(store.read(settingsKey)!) as Map)['themeMode'] as String?;

      expect(shown(), Brightness.dark);
      await t.tap(_tapLabel('Light'));
      await t.pumpAndSettle();
      expect(c.read(settingsProvider).themeMode, ThemeMode.light);
      expect(saved(), 'light');
      expect(shown(), Brightness.light);

      await t.tap(_tapLabel('Same as device'));
      await t.pumpAndSettle();
      expect(saved(), 'system');

      await t.tap(_tapLabel('Dark'));
      await t.pumpAndSettle();
      expect(saved(), 'dark');
      expect(shown(), Brightness.dark);
    });

    testWidgets('lists Dark, Light, Same as device in that order', (t) async {
      await _pump(t, const ThemeChooser());
      final xs = [
        for (final l in ['Dark', 'Light', 'Same as device']) t.getTopLeft(find.text(l)).dx,
      ];
      expect(xs[0], lessThan(xs[1]));
      expect(xs[1], lessThan(xs[2]));
    });
  });

  group('AutoDownloadChooser', () {
    testWidgets('choosing a label stores it', (t) async {
      final (c, store) = await _pump(t, const AutoDownloadChooser());
      expect(c.read(settingsProvider).autoDownload, AutoDownload.wifiOnly);
      await t.tap(_tapLabel('Off'));
      await t.pump();
      expect(c.read(settingsProvider).autoDownload, AutoDownload.off);
      expect(store.read(settingsKey), contains('"autoDownload":"off"'));
    });
  });
}
