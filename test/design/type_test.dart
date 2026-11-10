import 'package:buddhist_gatha/design/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const c = Color(0xFF123456);
  final scale = <String, (TextStyle, String, double, double, double)>{
    'wordmark': (NamoType.wordmark(c), 'Lora', 28, 1.2, 500),
    'screenTitle': (NamoType.screenTitle(c), 'Lora', 26, 1.25, 500),
    'sectionTitle': (NamoType.sectionTitle(c), 'Lora', 20, 1.3, 500),
    'sectionTitleSinhala':
        (NamoType.sectionTitleSinhala(c), 'NotoSansSinhala', 20, 1.3, 600),
    'cardTitle': (NamoType.cardTitle(c), 'Lora', 18, 1.3, 500),
    'body': (NamoType.body(c), 'NotoSansSinhala', 15, 1.5, 400),
    'label': (NamoType.label(c), 'NotoSansSinhala', 14, 1.3, 500),
    'caption': (NamoType.caption(c), 'NotoSansSinhala', 13, 1.4, 400),
    'overline': (NamoType.overline(c), 'NotoSansSinhala', 12, 1.3, 600),
  };

  test('every style matches the scale', () {
    for (final e in scale.entries) {
      final (s, family, size, height, weight) = e.value;
      expect(s.fontFamily, family, reason: e.key);
      expect(s.fontSize, size, reason: e.key);
      expect(s.height, height, reason: e.key);
      expect(s.color, c, reason: e.key);
      expect(s.fontVariations!.single.value, weight, reason: e.key);
      expect(s.fontSize!, greaterThanOrEqualTo(12), reason: e.key);
    }
  });

  test('overline is tracked, the rest are not', () {
    expect(NamoType.overline(c).letterSpacing, 0.8);
    expect(NamoType.body(c).letterSpacing, isNull);
  });

  test('font names and fallbacks are the other bundled families', () {
    expect(NamoFonts.serif, 'Lora');
    expect(NamoFonts.sans, 'NotoSansSinhala');
    expect(NamoType.wordmark(c).fontFamilyFallback, [NamoFonts.sans]);
    expect(NamoType.body(c).fontFamilyFallback, [NamoFonts.serif]);
  });
}
