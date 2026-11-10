import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quality/quality_support.dart';

SystemUiOverlayStyle _style(WidgetTester t) {
  final region = find
      .ancestor(
        of: find.byKey(const ValueKey('screen-settings')),
        matching: find.byWidgetPredicate(
          (w) => w is AnnotatedRegion<SystemUiOverlayStyle>,
        ),
      )
      .first;
  return t
      .widget<AnnotatedRegion<SystemUiOverlayStyle>>(region)
      .value;
}

void main() {
  testWidgets('dark theme: dark navigation bar, light icons', (t) async {
    await openReal(t, Routes.settings,
        dark: true, settings: const AppSettings(themeMode: ThemeMode.dark));
    final s = _style(t);
    expect(s.systemNavigationBarColor, NamoPalette.dark.background);
    expect(s.statusBarColor, Colors.transparent);
    expect(s.statusBarIconBrightness, Brightness.light);
    expect(s.systemNavigationBarIconBrightness, Brightness.light);
  });

  testWidgets('choosing Light in Settings switches the bars', (t) async {
    await openReal(t, Routes.settings,
        size: const Size(390, 2400),
        dark: true,
        settings: const AppSettings(themeMode: ThemeMode.dark));
    final handle = t.ensureSemantics();
    await t.tap(find.bySemanticsLabel(RegExp('^Light')));
    await t.pumpAndSettle();
    final s = _style(t);
    expect(s.systemNavigationBarColor, NamoPalette.light.background);
    expect(s.statusBarIconBrightness, Brightness.dark);
    expect(s.systemNavigationBarIconBrightness, Brightness.dark);
    handle.dispose();
  });

  testWidgets('Same as device follows the device brightness', (t) async {
    await openReal(t, Routes.settings,
        settings: const AppSettings(themeMode: ThemeMode.system));
    final s = _style(t);
    expect(s.systemNavigationBarColor, NamoPalette.light.background);
    expect(s.statusBarIconBrightness, Brightness.dark);
  });
}
