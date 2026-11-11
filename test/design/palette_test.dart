import 'dart:math' as math;

import 'package:buddhist_gatha/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Map<String, Color> roles(NamoPalette p) => {
      'background': p.background,
      'backgroundAlt': p.backgroundAlt,
      'surface': p.surface,
      'border': p.border,
      'text': p.text,
      'textSecondary': p.textSecondary,
      'textMuted': p.textMuted,
      'sage': p.sage,
      'gold': p.gold,
      'onSage': p.onSage,
      'shadow': p.shadow,
      'error': p.error,
      'onError': p.onError,
    };

void main() {
  test("dark palette is the owner's values", () {
    final expected = {
      'background': 0xFF151714,
      'backgroundAlt': 0xFF1C1F1B,
      'surface': 0xFF232720,
      'border': 0xFF34382F,
      'text': 0xFFEAE6DC,
      'textSecondary': 0xFFA9A698,
      'textMuted': 0xFF77776D,
      'sage': 0xFFA8B99F,
      'gold': 0xFFC6A879,
      'onSage': 0xFF151714,
      'shadow': 0x4D000000,
      'error': 0xFFE08A7C,
      'onError': 0xFF151714,
    };
    final actual = roles(NamoPalette.dark);
    for (final e in expected.entries) {
      expect(actual[e.key]!.toARGB32(), e.value, reason: e.key);
    }
  });

  test('light palette values', () {
    final expected = {
      'background': 0xFFF7F4EC,
      'backgroundAlt': 0xFFEFEBE1,
      'surface': 0xFFFDFBF6,
      'border': 0xFFD5CFC0,
      'text': 0xFF22251F,
      'textSecondary': 0xFF4F5248,
      'textMuted': 0xFF72736A,
      'sage': 0xFF4F6447,
      'gold': 0xFF7F6130,
      'onSage': 0xFFFDFBF6,
      'shadow': 0x1F22251F,
      'error': 0xFF9B3B2F,
      'onError': 0xFFFDFBF6,
    };
    final actual = roles(NamoPalette.light);
    for (final e in expected.entries) {
      expect(actual[e.key]!.toARGB32(), e.value, reason: e.key);
    }
  });

  for (final (name, p) in [
    ('dark', NamoPalette.dark),
    ('light', NamoPalette.light),
  ]) {
    test('$name palette meets contrast', () {
      final grounds = [p.background, p.backgroundAlt, p.surface];
      for (final g in grounds) {
        for (final c in [p.text, p.textSecondary, p.sage, p.gold]) {
          expect(contrast(c, g), greaterThanOrEqualTo(4.5));
        }
        expect(contrast(p.textMuted, g), greaterThanOrEqualTo(3.0));
        expect(contrast(p.sage, g), greaterThanOrEqualTo(3.0));
      }
      expect(contrast(p.onSage, p.sage), greaterThanOrEqualTo(4.5));
      expect(contrast(p.onError, p.error), greaterThanOrEqualTo(4.5));
      expect(contrast(p.error, p.background), greaterThanOrEqualTo(3.0));
    });
  }

  test('text on a picture is readable', () {
    expect(contrast(NamoPalette.onPicture, NamoPalette.pictureScrim),
        greaterThanOrEqualTo(4.5));
  });

  test('derived colours and the float shadow', () {
    final p = NamoPalette.dark;
    expect(p.pressed, p.text.withValues(alpha: 0.08));
    expect(p.hovered, p.text.withValues(alpha: 0.04));
    expect(p.sageTint, p.sage.withValues(alpha: 0.14));
    expect(p.floatShadow, hasLength(1));
    expect(p.floatShadow.single.blurRadius, 24);
    expect(p.floatShadow.single.offset, const Offset(0, 8));
    expect(p.floatShadow.single.color, p.shadow);
  });

  test('lerp at 0 and 1 gives the ends', () {
    final a = roles(NamoPalette.dark.lerp(NamoPalette.light, 0));
    final b = roles(NamoPalette.dark.lerp(NamoPalette.light, 1));
    final d = roles(NamoPalette.dark), l = roles(NamoPalette.light);
    for (final k in d.keys) {
      expect(a[k], d[k], reason: k);
      expect(b[k], l[k], reason: k);
    }
  });

  test('spacing, radius and sizes', () {
    expect(NamoSpace.xxxl, 48);
    expect(NamoRadius.lg, 24);
    expect(NamoSizes.homeColumn, 1040);
    expect(NamoSizes.navBarHeight, 64);
  });
}
