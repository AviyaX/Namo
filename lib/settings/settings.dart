import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';
import 'reading_language.dart';

const settingsKey = 'namo.settings.v1';

class AppSettings {
  const AppSettings({
    this.languages = LanguageSelection.initial,
    this.layout = TwoLanguageLayout.verse,
    this.fontScale = 1.0,
    this.lineSpacing = 1.6,
    this.scrollSpeed = 22.0,
    this.autoScrollWithAudio = false,
    this.themeMode = ThemeMode.dark,
  });

  static const fontScaleRange = (min: 0.85, max: 1.6);
  static const lineSpacingRange = (min: 1.3, max: 2.2);
  static const scrollSpeedRange = (min: 6.0, max: 60.0);

  final LanguageSelection languages;
  final TwoLanguageLayout layout;
  final double fontScale;
  final double lineSpacing;
  final double scrollSpeed;
  final bool autoScrollWithAudio;
  final ThemeMode themeMode;

  AppSettings copyWith({
    LanguageSelection? languages,
    TwoLanguageLayout? layout,
    double? fontScale,
    double? lineSpacing,
    double? scrollSpeed,
    bool? autoScrollWithAudio,
    ThemeMode? themeMode,
  }) =>
      AppSettings(
        languages: languages ?? this.languages,
        layout: layout ?? this.layout,
        fontScale: fontScale ?? this.fontScale,
        lineSpacing: lineSpacing ?? this.lineSpacing,
        scrollSpeed: scrollSpeed ?? this.scrollSpeed,
        autoScrollWithAudio: autoScrollWithAudio ?? this.autoScrollWithAudio,
        themeMode: themeMode ?? this.themeMode,
      );

  Map<String, dynamic> toJson() => {
        'languages': [for (final l in languages.languages) l.code],
        'layout': layout.name,
        'fontScale': fontScale,
        'lineSpacing': lineSpacing,
        'scrollSpeed': scrollSpeed,
        'autoScrollWithAudio': autoScrollWithAudio,
        'themeMode': themeMode.name,
      };

  /// Each field is read alone: a missing, wrongly typed or out-of-range value
  /// falls back to that field's default (numbers are clamped).
  factory AppSettings.fromJson(Object? json) {
    const d = AppSettings();
    if (json is! Map) return d;
    double number(String key, double fallback, ({double min, double max}) r) {
      final v = json[key];
      if (v is! num || !v.isFinite) return fallback;
      return v.toDouble().clamp(r.min, r.max);
    }

    final langs = json['languages'];
    final auto = json['autoScrollWithAudio'];
    return AppSettings(
      languages:
          langs is List ? LanguageSelection.fromCodes(langs) : d.languages,
      layout: TwoLanguageLayout.values.asNameMap()[json['layout']] ?? d.layout,
      fontScale: number('fontScale', d.fontScale, fontScaleRange),
      lineSpacing: number('lineSpacing', d.lineSpacing, lineSpacingRange),
      scrollSpeed: number('scrollSpeed', d.scrollSpeed, scrollSpeedRange),
      autoScrollWithAudio: auto is bool ? auto : d.autoScrollWithAudio,
      themeMode:
          ThemeMode.values.asNameMap()[json['themeMode']] ?? d.themeMode,
    );
  }
}

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final text = ref.read(keyValueStoreProvider).read(settingsKey);
    if (text == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(text));
    } on FormatException {
      return const AppSettings();
    }
  }

  void _set(AppSettings next) {
    state = next;
    ref
        .read(keyValueStoreProvider)
        .save(settingsKey, jsonEncode(next.toJson()));
  }

  ToggleOutcome toggleLanguage(ReadingLanguage l) {
    final (next, outcome) = state.languages.toggle(l);
    if (outcome == ToggleOutcome.changed) {
      _set(state.copyWith(languages: next));
    }
    return outcome;
  }

  void setLayout(TwoLanguageLayout v) => _set(state.copyWith(layout: v));

  void setFontScale(double v) => _set(state.copyWith(
      fontScale: v.clamp(
          AppSettings.fontScaleRange.min, AppSettings.fontScaleRange.max)));

  void setLineSpacing(double v) => _set(state.copyWith(
      lineSpacing: v.clamp(
          AppSettings.lineSpacingRange.min, AppSettings.lineSpacingRange.max)));

  void setScrollSpeed(double v) => _set(state.copyWith(
      scrollSpeed: v.clamp(
          AppSettings.scrollSpeedRange.min, AppSettings.scrollSpeedRange.max)));

  void setAutoScrollWithAudio(bool v) =>
      _set(state.copyWith(autoScrollWithAudio: v));

  void setThemeMode(ThemeMode v) => _set(state.copyWith(themeMode: v));
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
