import 'package:flutter/material.dart';

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
