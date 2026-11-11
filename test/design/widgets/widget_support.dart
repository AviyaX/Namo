import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] under the Namo theme, top-left aligned and loosely sized.
Future<void> pumpThemed(
  WidgetTester t,
  Widget child, {
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  bool disableAnimations = false,
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: namoTheme(brightness),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
          padding: padding,
        ),
        child: c!,
      ),
      home: Material(child: Align(alignment: Alignment.topLeft, child: child)),
    ),
  );
}

NamoPalette paletteOf(Brightness b) =>
    b == Brightness.dark ? NamoPalette.dark : NamoPalette.light;
