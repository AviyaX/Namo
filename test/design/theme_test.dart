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
          expect(s!.fontFamily, isIn([NamoFonts.serif, NamoFonts.sans]),
              reason: role);
          // Either it is the Sinhala family or it falls back to it.
          expect(
            s.fontFamily == NamoFonts.sinhala ||
                (s.fontFamilyFallback ?? const []).contains(NamoFonts.sinhala),
            isTrue,
            reason: role,
          );
          expect(s.fontSize, lessThanOrEqualTo(28), reason: role);
          expect(s.fontSize, greaterThanOrEqualTo(12), reason: role);
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

  test('the theme is built from the palette for its brightness', () {
    for (final (b, p) in [
      (Brightness.dark, NamoPalette.dark),
      (Brightness.light, NamoPalette.light),
    ]) {
      final t = namoTheme(b);
      expect(t.extension<NamoPalette>(), p);
      expect(t.scaffoldBackgroundColor, p.background);
      expect(t.splashFactory, NoSplash.splashFactory);
      expect(t.colorScheme.primary, p.sage);
      expect(t.colorScheme.error, p.error);
      expect(t.colorScheme.onError, p.onError);
    }
  });

  test('page margin steps with width', () {
    expect(NamoSizes.pageMargin(359), 16);
    expect(NamoSizes.pageMargin(360), 20);
    expect(NamoSizes.pageMargin(839), 20);
    expect(NamoSizes.pageMargin(840), 32);
  });

  testWidgets('NamoMotion.of is zero when animations are disabled', (t) async {
    Duration? got;
    Future<void> pump(bool disabled) => t.pumpWidget(MediaQuery(
          data: MediaQueryData(disableAnimations: disabled),
          child: Builder(builder: (context) {
            got = NamoMotion.of(context, NamoMotion.open);
            return const SizedBox();
          }),
        ));
    await pump(true);
    expect(got, Duration.zero);
    await pump(false);
    expect(got, NamoMotion.open);
  });
}
