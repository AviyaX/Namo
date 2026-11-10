import 'package:flutter/material.dart';

/// The five brand colours.
abstract final class NamoColors {
  static const ivory = Color(0xFFF5F1E8);
  static const sand = Color(0xFFE8E0D2);
  static const gold = Color(0xFFA88B5B);
  static const forest = Color(0xFF354638);
  static const charcoal = Color(0xFF292A26);
}

abstract final class NamoSizes {
  static const readingColumn = 680.0;
  static const wideBreakpoint = 840.0;
  static const touchTarget = 48.0;
}

/// Semantic colour roles, one set per brightness.
@immutable
class NamoPalette extends ThemeExtension<NamoPalette> {
  const NamoPalette({
    required this.background,
    required this.surface,
    required this.divider,
    required this.text,
    required this.textQuiet,
    required this.heading,
    required this.accent,
  });

  final Color background;
  final Color surface;
  final Color divider;
  final Color text;
  final Color textQuiet;
  final Color heading;
  final Color accent;

  static const light = NamoPalette(
    background: NamoColors.ivory,
    surface: NamoColors.sand,
    divider: NamoColors.sand,
    text: NamoColors.charcoal,
    textQuiet: Color(0xFF5F5E57),
    heading: NamoColors.forest,
    accent: NamoColors.gold,
  );

  static const dark = NamoPalette(
    background: Color(0xFF1E1F1C),
    surface: NamoColors.charcoal,
    divider: Color(0xFF3A3B36),
    text: NamoColors.sand,
    textQuiet: Color(0xFFB5AD9E),
    heading: Color(0xFFA9BFA9),
    accent: Color(0xFFC9AE7C),
  );

  static NamoPalette of(BuildContext context) =>
      Theme.of(context).extension<NamoPalette>()!;

  @override
  NamoPalette copyWith({
    Color? background,
    Color? surface,
    Color? divider,
    Color? text,
    Color? textQuiet,
    Color? heading,
    Color? accent,
  }) =>
      NamoPalette(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        divider: divider ?? this.divider,
        text: text ?? this.text,
        textQuiet: textQuiet ?? this.textQuiet,
        heading: heading ?? this.heading,
        accent: accent ?? this.accent,
      );

  @override
  NamoPalette lerp(ThemeExtension<NamoPalette>? other, double t) {
    if (other is! NamoPalette) return this;
    return NamoPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      text: Color.lerp(text, other.text, t)!,
      textQuiet: Color.lerp(textQuiet, other.textQuiet, t)!,
      heading: Color.lerp(heading, other.heading, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}
