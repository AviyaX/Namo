import 'dart:convert';

import 'package:buddhist_gatha/settings/auto_download.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer containerOn(KeyValueStore store) {
  final c = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('defaults', () {
    final s = containerOn(InMemoryKeyValueStore()).read(settingsProvider);
    expect(s.languages.languages,
        [ReadingLanguage.pali, ReadingLanguage.sinhala]);
    expect(s.layout, TwoLanguageLayout.verse);
    expect(s.fontScale, 1.0);
    expect(s.lineSpacing, 1.6);
    expect(s.scrollSpeed, 22.0);
    expect(s.chantSpeed, 1.0);
    expect(s.autoScrollWithAudio, isFalse);
    expect(s.themeMode, ThemeMode.dark);
  });

  test('settings survive a round trip through the store', () {
    final store = InMemoryKeyValueStore();
    final a = containerOn(store);
    final n = a.read(settingsProvider.notifier);
    expect(n.toggleLanguage(ReadingLanguage.pali), ToggleOutcome.changed);
    expect(n.toggleLanguage(ReadingLanguage.english), ToggleOutcome.changed);
    n.setLayout(TwoLanguageLayout.section);
    n.setFontScale(1.3);
    n.setLineSpacing(2.0);
    n.setScrollSpeed(40);
    n.setChantSpeed(1.25);
    n.setAutoScrollWithAudio(true);
    n.setThemeMode(ThemeMode.dark);

    final s = containerOn(store).read(settingsProvider);
    expect(s.languages.languages,
        [ReadingLanguage.sinhala, ReadingLanguage.english]);
    expect(s.layout, TwoLanguageLayout.section);
    expect(s.fontScale, 1.3);
    expect(s.lineSpacing, 2.0);
    expect(s.scrollSpeed, 40);
    expect(s.chantSpeed, 1.25);
    expect(s.autoScrollWithAudio, isTrue);
    expect(s.themeMode, ThemeMode.dark);
    expect(jsonDecode(store.read('namo.settings.v1')!)['languages'],
        ['si', 'en']);
  });

  test('a refused toggle writes nothing', () {
    final store = InMemoryKeyValueStore();
    final n = containerOn(store).read(settingsProvider.notifier);
    expect(
        n.toggleLanguage(ReadingLanguage.english), ToggleOutcome.refusedThird);
    expect(store.read('namo.settings.v1'), isNull);
  });

  test('numbers are clamped when set', () {
    final c = containerOn(InMemoryKeyValueStore());
    c.read(settingsProvider.notifier).setFontScale(5);
    expect(c.read(settingsProvider).fontScale, 1.6);
  });

  test('damaged saved settings fall back field by field', () {
    final store = InMemoryKeyValueStore()
      ..write('namo.settings.v1',
          '{"fontScale": "big", "lineSpacing": 9, "layout": "section", "languages": ["en"]}');
    final s = containerOn(store).read(settingsProvider);
    expect(s.fontScale, 1.0);
    expect(s.lineSpacing, 2.2);
    expect(s.layout, TwoLanguageLayout.section);
    expect(s.languages.languages, [ReadingLanguage.english]);
  });

  test('text that is not JSON gives all defaults', () {
    final store = InMemoryKeyValueStore()..write('namo.settings.v1', 'not json');
    final s = containerOn(store).read(settingsProvider);
    expect(s.fontScale, 1.0);
    expect(s.layout, TwoLanguageLayout.verse);
    expect(s.languages.languages, LanguageSelection.initial.languages);
  });

  test('JSON that is not an object gives all defaults', () {
    final store = InMemoryKeyValueStore()..write('namo.settings.v1', '[1,2]');
    expect(
        containerOn(store).read(settingsProvider).themeMode, ThemeMode.dark);
  });

  test('an unknown layout or theme name falls back alone', () {
    final s = AppSettings.fromJson(
        {'layout': 'zigzag', 'themeMode': 'sepia', 'fontScale': 1.2});
    expect(s.layout, TwoLanguageLayout.verse);
    expect(s.themeMode, ThemeMode.dark);
    expect(s.fontScale, 1.2);
  });

  test('every stored theme name reads back, and garbage gives dark', () {
    ThemeMode read(Object? j) => AppSettings.fromJson(j).themeMode;
    expect(const AppSettings().themeMode, ThemeMode.dark);
    expect(read({'themeMode': 'system'}), ThemeMode.system);
    expect(read({'themeMode': 'light'}), ThemeMode.light);
    expect(read({'themeMode': 'dark'}), ThemeMode.dark);
    expect(read({}), ThemeMode.dark);
    expect(read({'themeMode': 7}), ThemeMode.dark);
    expect(read({'themeMode': 'sepia'}), ThemeMode.dark);
    expect(read('nonsense'), ThemeMode.dark);
    final store = InMemoryKeyValueStore()
      ..write('namo.settings.v1', '"nonsense"');
    expect(containerOn(store).read(settingsProvider).themeMode, ThemeMode.dark);
  });

  test('chant speed snaps to the nearest allowed value', () {
    expect(AppSettings.snapChantSpeed(1.1), 1.0);
    expect(AppSettings.snapChantSpeed(1.2), 1.25);
    expect(AppSettings.snapChantSpeed(3), 1.5);
    expect(AppSettings.snapChantSpeed(0.1), 0.75);
    expect(AppSettings.snapChantSpeed(0.875), 0.75); // a tie goes down
    expect(AppSettings.snapChantSpeed('fast'), 1.0);
    expect(AppSettings.snapChantSpeed(null), 1.0);
    expect(AppSettings.snapChantSpeed(double.nan), 1.0);
  });

  test('the next chant speed cycles 1, 1.25, 1.5, 0.75, 1', () {
    var s = 1.0;
    final seen = <double>[];
    for (var i = 0; i < 5; i++) {
      s = AppSettings.nextChantSpeed(s);
      seen.add(s);
    }
    expect(seen, [1.25, 1.5, 0.75, 1.0, 1.25]);
    expect(AppSettings.nextChantSpeed(1.1), 1.25); // snapped first
  });

  test('a damaged saved chant speed falls back alone', () {
    final s = AppSettings.fromJson({'chantSpeed': 'x', 'fontScale': 1.2});
    expect(s.chantSpeed, 1.0);
    expect(s.fontScale, 1.2);
    expect(AppSettings.fromJson({'chantSpeed': 1.5}).chantSpeed, 1.5);
    expect(
        jsonDecode(jsonEncode(const AppSettings(chantSpeed: 1.25).toJson()))[
            'chantSpeed'],
        1.25);
  });

  test('side by side is refused for a pair that is not Pali and Sinhala', () {
    final store = InMemoryKeyValueStore();
    final c = containerOn(store);
    final n = c.read(settingsProvider.notifier);
    expect(n.setLayout(TwoLanguageLayout.sideBySide), LayoutOutcome.changed);
    expect(c.read(settingsProvider).layout, TwoLanguageLayout.sideBySide);
    n.toggleLanguage(ReadingLanguage.sinhala); // now Pali alone
    n.toggleLanguage(ReadingLanguage.english); // Pali + English
    expect(c.read(settingsProvider).layout, TwoLanguageLayout.sideBySide,
        reason: 'kept');
    expect(c.read(settingsProvider).effectiveLayout, TwoLanguageLayout.verse);
    expect(n.setLayout(TwoLanguageLayout.verse), LayoutOutcome.changed);
    expect(n.setLayout(TwoLanguageLayout.sideBySide), LayoutOutcome.refusedPair);
    expect(c.read(settingsProvider).layout, TwoLanguageLayout.verse);
  });

  test('effectiveLayout is the saved layout for Pali and Sinhala', () {
    const s = AppSettings(layout: TwoLanguageLayout.sideBySide);
    expect(s.effectiveLayout, TwoLanguageLayout.sideBySide);
    expect(AppSettings.fromJson({'layout': 'sideBySide'}).layout,
        TwoLanguageLayout.sideBySide);
  });

  test('auto download defaults to Wi-Fi only', () {
    expect(const AppSettings().autoDownload, AutoDownload.wifiOnly);
  });
  test('auto download is saved by name and read back', () {
    final store = InMemoryKeyValueStore();
    final c = containerOn(store);
    c.read(settingsProvider.notifier).setAutoDownload(AutoDownload.off);
    expect((jsonDecode(store.read(settingsKey)!) as Map)['autoDownload'], 'off');
    expect(containerOn(store).read(settingsProvider).autoDownload, AutoDownload.off);
  });
  test('an unknown auto download value falls back alone', () {
    final s = AppSettings.fromJson({'autoDownload': 'sometimes', 'fontScale': 1.2});
    expect(s.autoDownload, AutoDownload.wifiOnly);
    expect(s.fontScale, 1.2);
  });
}
