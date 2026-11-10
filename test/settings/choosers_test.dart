import 'dart:convert';

import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/tokens.dart';
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

void main() {
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
}
