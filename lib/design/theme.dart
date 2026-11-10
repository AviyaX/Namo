import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData namoTheme(Brightness brightness) {
  final p = brightness == Brightness.light
      ? NamoPalette.light
      : NamoPalette.dark;
  TextStyle style(double size, {int weight = 400, Color? color}) => namoText(
      NamoFonts.english,
      size: size,
      color: color ?? p.text,
      weight: weight);
  final hairline = BorderSide(color: p.divider, width: 1);
  const radius = BorderRadius.all(Radius.circular(8));

  final textTheme = TextTheme(
    displayLarge: style(22, weight: 600, color: p.heading),
    displayMedium: style(22, weight: 600, color: p.heading),
    displaySmall: style(22, weight: 600, color: p.heading),
    headlineLarge: style(22, weight: 600, color: p.heading),
    headlineMedium: style(22, weight: 600, color: p.heading),
    headlineSmall: style(20, weight: 600, color: p.heading),
    titleLarge: style(20, weight: 600, color: p.heading),
    titleMedium: style(16, weight: 600),
    titleSmall: style(14, weight: 600),
    bodyLarge: style(16),
    bodyMedium: style(16),
    bodySmall: style(14, color: p.textQuiet),
    labelLarge: style(16, weight: 500),
    labelMedium: style(14, weight: 500),
    labelSmall: style(12, weight: 500, color: p.textQuiet),
  );

  final scheme = ColorScheme.fromSeed(
    seedColor: NamoColors.forest,
    brightness: brightness,
  ).copyWith(
    surface: p.background,
    onSurface: p.text,
    primary: p.heading,
    onPrimary: p.background,
    secondary: p.accent,
    outline: p.divider,
    outlineVariant: p.divider,
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
    dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: p.background,
      foregroundColor: p.heading,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: p.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: hairline),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(NamoSizes.touchTarget, NamoSizes.touchTarget),
        shape: RoundedRectangleBorder(borderRadius: radius, side: hairline),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(NamoSizes.touchTarget, NamoSizes.touchTarget),
        side: hairline,
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(NamoSizes.touchTarget, NamoSizes.touchTarget),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: p.surface,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? p.heading
              : p.textQuiet)),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => style(12,
          weight: 500,
          color: states.contains(WidgetState.selected)
              ? p.heading
              : p.textQuiet)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      elevation: 0,
      backgroundColor: p.background,
      indicatorColor: p.surface,
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: IconThemeData(color: p.heading),
      unselectedIconTheme: IconThemeData(color: p.textQuiet),
      selectedLabelTextStyle: style(12, weight: 500, color: p.heading),
      unselectedLabelTextStyle: style(12, weight: 500, color: p.textQuiet),
    ),
    snackBarTheme: SnackBarThemeData(
      elevation: 0,
      backgroundColor: p.surface,
      contentTextStyle: style(16),
      actionTextColor: p.heading,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius, side: hairline),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(NamoSizes.touchTarget, NamoSizes.touchTarget),
        foregroundColor: p.heading,
        disabledForegroundColor: p.textQuiet.withValues(alpha: 0.5),
        highlightColor: p.surface,
        hoverColor: p.surface,
      ),
    ),
    // Off must show: an outline and thumb in the quiet text colour (the
    // default is a pale grey on a pale track).
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? p.heading : p.background),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? p.heading : p.textQuiet),
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? p.background : p.textQuiet),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.heading,
      inactiveTrackColor: p.divider,
      thumbColor: p.heading,
      overlayColor: p.surface,
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      modalElevation: 0,
      backgroundColor: p.background,
      modalBackgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      dragHandleColor: p.divider,
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          side: hairline),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: hairline),
    ),
  );
}
