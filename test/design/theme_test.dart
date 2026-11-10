import 'dart:math' as math;

import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast ratio.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('palette holds the five spec colours', () {
    expect(NamoColors.ivory.toARGB32(), 0xFFF5F1E8);
    expect(NamoColors.sand.toARGB32(), 0xFFE8E0D2);
    expect(NamoColors.gold.toARGB32(), 0xFFA88B5B);
    expect(NamoColors.forest.toARGB32(), 0xFF354638);
    expect(NamoColors.charcoal.toARGB32(), 0xFF292A26);
    expect(NamoPalette.light.background, NamoColors.ivory);
    expect(NamoPalette.light.text, NamoColors.charcoal);
  });

  test('text roles meet contrast in both themes', () {
    for (final p in [NamoPalette.light, NamoPalette.dark]) {
      expect(contrastRatio(p.text, p.background), greaterThanOrEqualTo(7.0));
      expect(contrastRatio(p.heading, p.background), greaterThanOrEqualTo(4.5));
      expect(
        contrastRatio(p.textQuiet, p.background),
        greaterThanOrEqualTo(4.5),
      );
    }
    expect(
      contrastRatio(NamoPalette.dark.accent, NamoPalette.dark.background),
      greaterThanOrEqualTo(4.5),
    );
  });

  test(
    'every theme text style uses a bundled family and the Sinhala fallback',
    () {
      for (final b in Brightness.values) {
        final t = namoTheme(b).textTheme;
        // All 15 roles: a role without the fallback would make Flutter web
        // download a font.
        final roles = {
          'displayLarge': t.displayLarge,
          'displayMedium': t.displayMedium,
          'displaySmall': t.displaySmall,
          'headlineLarge': t.headlineLarge,
          'headlineMedium': t.headlineMedium,
          'headlineSmall': t.headlineSmall,
          'titleLarge': t.titleLarge,
          'titleMedium': t.titleMedium,
          'titleSmall': t.titleSmall,
          'bodyLarge': t.bodyLarge,
          'bodyMedium': t.bodyMedium,
          'bodySmall': t.bodySmall,
          'labelLarge': t.labelLarge,
          'labelMedium': t.labelMedium,
          'labelSmall': t.labelSmall,
        };
        expect(roles, hasLength(15));
        for (final MapEntry(key: role, value: s) in roles.entries) {
          expect(s, isNotNull, reason: role);
          expect(s!.fontFamily, NamoFonts.english, reason: role);
          expect(
            s.fontFamilyFallback,
            contains(NamoFonts.sinhala),
            reason: role,
          );
          expect(s.fontSize, lessThanOrEqualTo(22), reason: role);
        }
      }
    },
  );

  test('themes are flat', () {
    final t = namoTheme(Brightness.light);
    expect(t.appBarTheme.elevation, 0);
    expect(t.cardTheme.elevation, 0);
    expect(t.extension<NamoPalette>(), NamoPalette.light);
  });
}
