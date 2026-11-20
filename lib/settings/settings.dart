import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';
import 'auto_download.dart';
import 'reading_language.dart';

const settingsKey = 'namo.settings.v1';

/// How a book reads: turning pages, or one long scroll.
enum BookReadingMode {
  pages('Pages'),
  scroll('Scroll');

  const BookReadingMode(this.label);

  final String label;
}

enum LayoutOutcome { changed, refusedPair }

class AppSettings {
  const AppSettings({
    this.languages = LanguageSelection.initial,
    this.layout = TwoLanguageLayout.verse,
    this.fontScale = 1.0,
    this.lineSpacing = 1.6,
    this.scrollSpeed = 22.0,
    this.autoScrollWithAudio = false,
    this.chantSpeed = 1.0,
    this.autoDownload = AutoDownload.wifiOnly,
    this.themeMode = ThemeMode.dark,
    this.bookReadingMode = BookReadingMode.pages,
  });

  static const fontScaleRange = (min: 0.85, max: 1.6);
  static const lineSpacingRange = (min: 1.3, max: 2.2);
  static const scrollSpeedRange = (min: 6.0, max: 60.0);

  /// The playback rates a chant can be set to; 1 is the recording's own.
  static const chantSpeeds = [0.75, 1.0, 1.25, 1.5];

  /// The allowed speed nearest [v] (a tie goes to the lower); 1 for anything
  /// that is not a finite number.
  static double snapChantSpeed(Object? v) {
    if (v is! num || !v.isFinite) return 1.0;
    var best = chantSpeeds.first;
    for (final s in chantSpeeds) {
      if ((s - v).abs() < (best - v).abs()) best = s;
    }
    return best;
  }

  /// The speed after [v] (snapped first), wrapping from the fastest to the
  /// slowest.
  static double nextChantSpeed(double v) {
    final i = chantSpeeds.indexOf(snapChantSpeed(v));
    return chantSpeeds[(i + 1) % chantSpeeds.length];
  }

  final LanguageSelection languages;
  final TwoLanguageLayout layout;
  final double fontScale;
  final double lineSpacing;
  final double scrollSpeed;
  final bool autoScrollWithAudio;
  final double chantSpeed;
  final AutoDownload autoDownload;
  final ThemeMode themeMode;
  final BookReadingMode bookReadingMode;

  /// The layout to draw: side by side only holds for Pali and Sinhala, so
  /// for any other pair the saved choice is kept but verse by verse is shown.
  TwoLanguageLayout get effectiveLayout =>
      layout == TwoLanguageLayout.sideBySide && !languages.isPaliAndSinhala
          ? TwoLanguageLayout.verse
          : layout;

  AppSettings copyWith({
    LanguageSelection? languages,
    TwoLanguageLayout? layout,
    double? fontScale,
    double? lineSpacing,
    double? scrollSpeed,
    bool? autoScrollWithAudio,
    double? chantSpeed,
    AutoDownload? autoDownload,
    ThemeMode? themeMode,
    BookReadingMode? bookReadingMode,
  }) =>
      AppSettings(
        languages: languages ?? this.languages,
        layout: layout ?? this.layout,
        fontScale: fontScale ?? this.fontScale,
        lineSpacing: lineSpacing ?? this.lineSpacing,
        scrollSpeed: scrollSpeed ?? this.scrollSpeed,
        autoScrollWithAudio: autoScrollWithAudio ?? this.autoScrollWithAudio,
        chantSpeed: chantSpeed ?? this.chantSpeed,
        autoDownload: autoDownload ?? this.autoDownload,
        themeMode: themeMode ?? this.themeMode,
        bookReadingMode: bookReadingMode ?? this.bookReadingMode,
      );

  Map<String, dynamic> toJson() => {
        'languages': [for (final l in languages.languages) l.code],
        'layout': layout.name,
        'fontScale': fontScale,
        'lineSpacing': lineSpacing,
        'scrollSpeed': scrollSpeed,
        'autoScrollWithAudio': autoScrollWithAudio,
        'chantSpeed': chantSpeed,
        'autoDownload': autoDownload.name,
        'themeMode': themeMode.name,
        'bookReadingMode': bookReadingMode.name,
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
      chantSpeed: snapChantSpeed(json['chantSpeed']),
      autoDownload: AutoDownload.values.asNameMap()[json['autoDownload']] ??
          d.autoDownload,
      themeMode:
          ThemeMode.values.asNameMap()[json['themeMode']] ?? d.themeMode,
      bookReadingMode: BookReadingMode.values
              .asNameMap()[json['bookReadingMode']] ??
          d.bookReadingMode,
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

  LayoutOutcome setLayout(TwoLanguageLayout v) {
    if (v == TwoLanguageLayout.sideBySide &&
        !state.languages.isPaliAndSinhala) {
      return LayoutOutcome.refusedPair;
    }
    _set(state.copyWith(layout: v));
    return LayoutOutcome.changed;
  }

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

  void setChantSpeed(double v) =>
      _set(state.copyWith(chantSpeed: AppSettings.snapChantSpeed(v)));

  void setAutoDownload(AutoDownload v) =>
      _set(state.copyWith(autoDownload: v));

  void setThemeMode(ThemeMode v) => _set(state.copyWith(themeMode: v));
  void setBookReadingMode(BookReadingMode v) =>
      _set(state.copyWith(bookReadingMode: v));
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
