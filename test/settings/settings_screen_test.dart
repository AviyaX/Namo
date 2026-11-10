import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';

Future<ProviderContainer> openSettings(WidgetTester t) async {
  await pumpApp(t,
      overrides: [
        contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      ],
      location: '/settings');
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
}
