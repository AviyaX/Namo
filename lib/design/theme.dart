import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData namoTheme(Brightness brightness) {
  final p =
      brightness == Brightness.light ? NamoPalette.light : NamoPalette.dark;
  final hairline = BorderSide(color: p.border, width: 1);
  const radius = BorderRadius.all(Radius.circular(NamoRadius.sm));
  const minSize = Size(NamoSizes.touchTarget, NamoSizes.touchTarget);

  final textTheme = TextTheme(
    displayLarge: NamoType.screenTitle(p.text),
    displayMedium: NamoType.screenTitle(p.text),
    displaySmall: NamoType.screenTitle(p.text),
    headlineLarge: NamoType.screenTitle(p.text),
    headlineMedium: NamoType.sectionTitle(p.text),
    headlineSmall: NamoType.sectionTitle(p.text),
    titleLarge: NamoType.sectionTitle(p.text),
    titleMedium: NamoType.cardTitle(p.text),
    titleSmall: NamoType.label(p.text),
    bodyLarge: NamoType.body(p.text),
    bodyMedium: NamoType.body(p.text),
    bodySmall: NamoType.caption(p.textSecondary),
    labelLarge: NamoType.label(p.text),
    labelMedium: NamoType.label(p.textSecondary),
    labelSmall: NamoType.overline(p.textSecondary),
  );

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.sage,
    onPrimary: p.onSage,
    secondary: p.gold,
    onSecondary: p.onSage,
    error: p.error,
    onError: p.onError,
    surface: p.surface,
    onSurface: p.text,
    outline: p.textMuted,
    outlineVariant: p.border,
    surfaceTint: Colors.transparent,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    textTheme: textTheme,
    extensions: [p],
    splashFactory: NoSplash.splashFactory,
    highlightColor: p.pressed,
    hoverColor: p.hovered,
    focusColor: p.sageTint,
    iconTheme: IconThemeData(color: p.text, weight: 300),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: p.background,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minSize,
        side: hairline,
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: minSize,
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      elevation: 0,
      backgroundColor: p.surface,
      contentTextStyle: NamoType.body(p.text),
      actionTextColor: p.sage,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius, side: hairline),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: radius,
        border: Border.fromBorderSide(hairline),
      ),
      textStyle: NamoType.caption(p.text),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: minSize,
        foregroundColor: p.text,
        disabledForegroundColor: p.textMuted,
        highlightColor: p.pressed,
        hoverColor: p.hovered,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.sage,
      inactiveTrackColor: p.border,
      thumbColor: p.sage,
      overlayColor: p.sageTint,
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      modalElevation: 0,
      backgroundColor: p.surface,
      modalBackgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      dragHandleColor: p.border,
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(NamoRadius.lg)),
          side: hairline),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: hairline),
    ),
  );
}
