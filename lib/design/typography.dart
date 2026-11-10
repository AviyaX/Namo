import 'package:flutter/material.dart';

import '../settings/reading_language.dart';

abstract final class NamoFonts {
  static const sinhala = 'NotoSansSinhala';
  static const romanPali = 'NotoSerif';
  static const english = 'Lora';
}

/// Every text style in the app comes from here, so each one carries the
/// bundled Sinhala fallback and the web build never fetches a font.
TextStyle namoText(
  String family, {
  required double size,
  required Color color,
  double height = 1.4,
  int weight = 400,
}) =>
    TextStyle(
      fontFamily: family,
      fontFamilyFallback: const [NamoFonts.sinhala],
      fontSize: size,
      height: height,
      color: color,
      fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
      fontVariations: [FontVariation.weight(weight.toDouble())],
    );

/// The style of verse text in [l]. Pali is in Sinhala letters, so it uses the
/// Sinhala family.
TextStyle readingStyle(
  ReadingLanguage l, {
  required double fontScale,
  required double lineSpacing,
  required Color color,
}) {
  final (family, base) = switch (l) {
    ReadingLanguage.sinhala || ReadingLanguage.pali => (NamoFonts.sinhala, 18.0),
    ReadingLanguage.english => (NamoFonts.english, 17.0),
  };
  return namoText(family,
      size: base * fontScale, height: lineSpacing, color: color);
}
