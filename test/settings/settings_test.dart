import 'dart:convert';

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
    expect(s.autoScrollWithAudio, isFalse);
    expect(s.themeMode, ThemeMode.system);
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
    n.setAutoScrollWithAudio(true);
    n.setThemeMode(ThemeMode.dark);

    final s = containerOn(store).read(settingsProvider);
    expect(s.languages.languages,
        [ReadingLanguage.sinhala, ReadingLanguage.english]);
    expect(s.layout, TwoLanguageLayout.section);
    expect(s.fontScale, 1.3);
    expect(s.lineSpacing, 2.0);
    expect(s.scrollSpeed, 40);
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
        containerOn(store).read(settingsProvider).themeMode, ThemeMode.system);
  });

  test('an unknown layout or theme name falls back alone', () {
    final s = AppSettings.fromJson(
        {'layout': 'zigzag', 'themeMode': 'sepia', 'fontScale': 1.2});
    expect(s.layout, TwoLanguageLayout.verse);
    expect(s.themeMode, ThemeMode.system);
    expect(s.fontScale, 1.2);
  });
}
