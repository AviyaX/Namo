import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/theme.dart';
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
    );
  }
}
