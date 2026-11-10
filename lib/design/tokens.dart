import 'package:flutter/material.dart';

abstract final class NamoSizes {
  static const readingColumn = 680.0;
  static const wideBreakpoint = 840.0;

  /// The reading column of a phrased reading (a pirith): wide enough for a
  /// phrase and its meaning side by side.
  static const phraseColumn = 920.0;
  static const touchTarget = 48.0;
  static const homeColumn = 1040.0;
  static const iconSmall = 20.0;
  static const icon = 24.0;
  static const navBarHeight = 64.0;

  /// The side margin of a page at [width].
  static double pageMargin(double width) => width < 360
      ? 16
      : width < wideBreakpoint
          ? 20
          : 32;
}

abstract final class NamoSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

abstract final class NamoRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
}

abstract final class NamoMotion {
  static const press = Duration(milliseconds: 120);
  static const quick = Duration(milliseconds: 200);
  static const open = Duration(milliseconds: 300);
  static const close = Duration(milliseconds: 200);
  static const curve = Curves.easeOutCubic;

  /// [d], or zero when the person has asked for no animation.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// Semantic colour roles, one set per brightness.
@immutable
class NamoPalette extends ThemeExtension<NamoPalette> {
  const NamoPalette({
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.sage,
    required this.gold,
    required this.onSage,
    required this.shadow,
    required this.error,
    required this.onError,
  });

  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color sage;
  final Color gold;
  final Color onSage;
  final Color shadow;
  final Color error;
  final Color onError;

  static const dark = NamoPalette(
    background: Color(0xFF151714),
    backgroundAlt: Color(0xFF1C1F1B),
    surface: Color(0xFF232720),
    border: Color(0xFF34382F),
    text: Color(0xFFEAE6DC),
    textSecondary: Color(0xFFA9A698),
    textMuted: Color(0xFF77776D),
    sage: Color(0xFFA8B99F),
    gold: Color(0xFFC6A879),
    onSage: Color(0xFF151714),
    shadow: Color(0x4D000000),
    error: Color(0xFFE08A7C),
    onError: Color(0xFF151714),
  );

  static const light = NamoPalette(
    background: Color(0xFFF7F4EC),
    backgroundAlt: Color(0xFFEFEBE1),
    surface: Color(0xFFFDFBF6),
    border: Color(0xFFD5CFC0),
    text: Color(0xFF22251F),
    textSecondary: Color(0xFF4F5248),
    textMuted: Color(0xFF72736A),
    sage: Color(0xFF4F6447),
    gold: Color(0xFF7F6130),
    onSage: Color(0xFFFDFBF6),
    shadow: Color(0x1F22251F),
    error: Color(0xFF9B3B2F),
    onError: Color(0xFFFDFBF6),
  );

  /// Text drawn over a picture, and the scrim colour it sits on.
  static const onPicture = Color(0xFFEAE6DC);
  static const pictureScrim = Color(0xFF151714);

  Color get pressed => text.withValues(alpha: 0.08);
  Color get hovered => text.withValues(alpha: 0.04);
  Color get sageTint => sage.withValues(alpha: 0.14);

  /// The only shadow in the app.
  List<BoxShadow> get floatShadow =>
      [BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8))];

  static NamoPalette of(BuildContext context) =>
      Theme.of(context).extension<NamoPalette>()!;

  @override
  NamoPalette copyWith({
    Color? background,
    Color? backgroundAlt,
    Color? surface,
    Color? border,
    Color? text,
    Color? textSecondary,
    Color? textMuted,
    Color? sage,
    Color? gold,
    Color? onSage,
    Color? shadow,
    Color? error,
    Color? onError,
  }) =>
      NamoPalette(
        background: background ?? this.background,
        backgroundAlt: backgroundAlt ?? this.backgroundAlt,
        surface: surface ?? this.surface,
        border: border ?? this.border,
        text: text ?? this.text,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        sage: sage ?? this.sage,
        gold: gold ?? this.gold,
        onSage: onSage ?? this.onSage,
        shadow: shadow ?? this.shadow,
        error: error ?? this.error,
        onError: onError ?? this.onError,
      );

  @override
  NamoPalette lerp(ThemeExtension<NamoPalette>? other, double t) {
    if (other is! NamoPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return NamoPalette(
      background: mix(background, other.background),
      backgroundAlt: mix(backgroundAlt, other.backgroundAlt),
      surface: mix(surface, other.surface),
      border: mix(border, other.border),
      text: mix(text, other.text),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      sage: mix(sage, other.sage),
      gold: mix(gold, other.gold),
      onSage: mix(onSage, other.onSage),
      shadow: mix(shadow, other.shadow),
      error: mix(error, other.error),
      onError: mix(onError, other.onError),
    );
  }
}
