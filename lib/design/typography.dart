import 'package:flutter/material.dart';

import '../settings/reading_language.dart';

abstract final class NamoFonts {
  static const sinhala = 'NotoSansSinhala';
  static const romanPali = 'NotoSerif';
  static const english = 'Lora';
  static const serif = 'Lora';
  static const sans = 'NotoSansSinhala';
}

/// Every text style in the app comes from here, so each one carries the
/// bundled Sinhala fallback and the web build never fetches a font.
TextStyle namoText(
  String family, {
  required double size,
  required Color color,
  double height = 1.4,
  int weight = 400,
  double? letterSpacing,
}) =>
    TextStyle(
      fontFamily: family,
      fontFamilyFallback: [
        for (final f in const [NamoFonts.sans, NamoFonts.serif])
          if (f != family) f,
      ],
      letterSpacing: letterSpacing,
      fontSize: size,
      height: height,
      color: color,
      fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
      fontVariations: [FontVariation.weight(weight.toDouble())],
    );

/// The app's text scale. Each style takes only its colour.
abstract final class NamoType {
  static TextStyle wordmark(Color color) => namoText(NamoFonts.serif,
      size: 28, height: 1.2, weight: 500, color: color);
  static TextStyle screenTitle(Color color) => namoText(NamoFonts.serif,
      size: 26, height: 1.25, weight: 500, color: color);
  static TextStyle sectionTitle(Color color) => namoText(NamoFonts.serif,
      size: 20, height: 1.3, weight: 500, color: color);
  static TextStyle sectionTitleSinhala(Color color) => namoText(NamoFonts.sans,
      size: 20, height: 1.3, weight: 600, color: color);
  static TextStyle cardTitle(Color color) => namoText(NamoFonts.serif,
      size: 18, height: 1.3, weight: 500, color: color);
  static TextStyle body(Color color) => namoText(NamoFonts.sans,
      size: 15, height: 1.5, weight: 400, color: color);
  static TextStyle label(Color color) => namoText(NamoFonts.sans,
      size: 14, height: 1.3, weight: 500, color: color);
  static TextStyle caption(Color color) => namoText(NamoFonts.sans,
      size: 13, height: 1.4, weight: 400, color: color);
  static TextStyle overline(Color color) => namoText(NamoFonts.sans,
      size: 12, height: 1.3, weight: 600, letterSpacing: 0.8, color: color);
}

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
