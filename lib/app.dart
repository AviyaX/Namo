import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/theme.dart';
import 'design/tokens.dart';
import 'router.dart';
import 'settings/settings.dart';

class NamoApp extends ConsumerWidget {
  const NamoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Namo',
      theme: namoTheme(Brightness.light),
      darkTheme: namoTheme(Brightness.dark),
      themeMode: ref.watch(settingsProvider.select((s) => s.themeMode)),
      routerConfig: ref.watch(routerProvider),
      // Here Theme.of is the theme in use, so the system bars and the
      // browser's theme colour follow it.
      builder: (context, child) {
        final theme = Theme.of(context);
        final palette = NamoPalette.of(context);
        final icons = theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: icons,
            statusBarBrightness: theme.brightness,
            systemNavigationBarColor: palette.background,
            systemNavigationBarIconBrightness: icons,
            systemNavigationBarDividerColor: palette.background,
          ),
          child: Title(
            title: 'Namo',
            color: palette.background,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
