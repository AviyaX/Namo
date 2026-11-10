import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/home/card_art.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../quality/quality_support.dart';

const _panel = ValueKey('card-art-panel');
const _picture = ValueKey('card-art-picture');

Future<void> _pumpArt(
  WidgetTester t, {
  Map<String, String> pictures = const {},
  Brightness brightness = Brightness.light,
}) async {
  await t.pumpWidget(
    MaterialApp(
      theme: namoTheme(brightness),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CardArt(categoryId: 'c1', pictures: pictures),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets(
    'with no registered picture the drawn panel shows; the picture slot is 16:9',
    (t) async {
      expect(cardPictures, isEmpty);
      await openReal(t, Routes.home);
      expect(find.byKey(_panel), findsOneWidget);
      expect(find.byKey(_picture), findsNothing);
      final slot = find.ancestor(
        of: find.byType(CardArt),
        matching: find.byType(AspectRatio),
      );
      expect(slot, findsOneWidget);
      expect(t.widget<AspectRatio>(slot).aspectRatio, closeTo(16 / 9, 1e-9));
      final size = t.getSize(slot);
      expect(size.width / size.height, closeTo(16 / 9, 0.02));
    },
  );

  testWidgets('the drawn panel is one lotus in the accent, over a gradient, with no text',
      (t) async {
    for (final brightness in Brightness.values) {
      await _pumpArt(t, brightness: brightness);
      final p = brightness == Brightness.light
          ? NamoPalette.light
          : NamoPalette.dark;
      final icon = t.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Symbols.spa);
      expect(icon.weight, 200);
      expect(icon.color, p.accent);
      // About 40% of the panel's height.
      expect(icon.size, closeTo(t.getSize(find.byKey(_panel)).height * 0.4, 0.5));
      expect(find.byType(Text), findsNothing);
      final box = t.widget<DecoratedBox>(find.byKey(_panel));
      final gradient = (box.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.colors, [p.surface, p.background]);
      expect(gradient.begin, Alignment.topLeft);
      expect(gradient.end, Alignment.bottomRight);
    }
    expect(NamoPalette.light.surface, const Color(0xFFE8E0D2));
    expect(NamoPalette.light.background, const Color(0xFFF5F1E8));
    expect(NamoPalette.light.accent, const Color(0xFFA88B5B));
  });

  testWidgets(
    'a registered picture is shown, and a picture that fails to load falls back to the drawn panel',
    (t) async {
      await _pumpArt(t, pictures: {'c1': 'assets/branding/namo_icon_square.png'});
      expect(find.byKey(_picture), findsOneWidget);
      expect(find.byKey(_panel), findsNothing);
      expect(t.widget<Image>(find.byType(Image)).fit, BoxFit.cover);

      await _pumpArt(t, pictures: {'c1': 'assets/pictures/missing.png'});
      await t.pump();
      await t.pump();
      expect(find.byKey(_panel), findsOneWidget);
      expect(t.takeException(), isNull);

      // A category that is not registered gets the panel.
      await _pumpArt(t, pictures: {'other': 'assets/branding/namo_icon_square.png'});
      expect(find.byKey(_panel), findsOneWidget);
    },
  );

  testWidgets('the picture is left out of the semantics tree', (t) async {
    final handle = t.ensureSemantics();
    await _pumpArt(t, pictures: {'c1': 'assets/branding/namo_icon_square.png'});
    expect(
      find.descendant(of: find.byType(CardArt), matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
    handle.dispose();
  });
}
