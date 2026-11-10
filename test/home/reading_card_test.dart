import 'dart:io';

import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/home/card_art.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../quality/quality_support.dart';

const _panel = ValueKey('card-art-panel');
const _picture = ValueKey('card-art-picture');
const _loading = ValueKey('card-art-loading');

/// Lets the real image decoder finish (it runs outside fake-async time).
Future<void> _untilDecoded(WidgetTester t) async {
  for (var i = 0; i < 100; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump();
    if (find.byKey(_loading).evaluate().isEmpty) return;
  }
  fail('the picture did not decode');
}

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

  testWidgets('the Buddha Wandanawa card shows the bundled picture, not the drawn panel',
      (t) async {
    await openReal(t, Routes.home);
    await _untilDecoded(t);
    expect(find.byKey(_picture), findsOneWidget);
    expect(find.byKey(_panel), findsNothing);
    expect(find.byKey(_loading), findsNothing);
    final image = t.widget<Image>(find.byKey(_picture));
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.center);
    expect((image.image as ResizeImage).width, lessThanOrEqualTo(1600));
    expect(
      ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
      'assets/pictures/samadhi_buddha_anuradhapura.jpg',
    );
  });

  test('every path in cardPictures is a bundled asset listed in pubspec.yaml', () async {
    expect(cardPictures['cat-namaskaraya'],
        'assets/pictures/samadhi_buddha_anuradhapura.jpg');
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final path in cardPictures.values) {
      expect(pubspec, contains('- $path'));
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: path);
    }
  });

  testWidgets('the picture is excluded from semantics and the card label is unchanged',
      (t) async {
    final handle = t.ensureSemantics();
    await openReal(t, Routes.home);
    await _untilDecoded(t);
    final c = (await realLibrary(t)).categories.first;
    expect(c.id, 'cat-namaskaraya');
    final label = '${c.title}, ${c.subtitle}, 19 sections';
    expect(find.bySemanticsLabel(label), findsOneWidget);
    expect(
      find.descendant(of: find.byType(CardArt), matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
    expect(
      find.bySemanticsLabel(RegExp('samadhi|Anuradhapura|picture', caseSensitive: false)),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('a category with no picture shows the drawn panel in a 16:9 slot',
      (t) async {
      await openReal(t, Routes.home, library: severalCategories());
      expect(find.byKey(_panel), findsNWidgets(4));
      expect(find.byKey(_picture), findsNothing);
      final slot = find.ancestor(
        of: find.byType(CardArt),
        matching: find.byType(AspectRatio),
      );
      expect(slot, findsNWidgets(4));
      expect(t.widget<AspectRatio>(slot.first).aspectRatio, closeTo(16 / 9, 1e-9));
      final size = t.getSize(slot.first);
      expect(size.width / size.height, closeTo(16 / 9, 0.02));
    },
  );

  testWidgets('while the picture decodes the slot shows the gradient and stays 16:9',
      (t) async {
    await _pumpArt(t, pictures: {'c1': 'assets/pictures/samadhi_buddha_anuradhapura.jpg'});
    expect(find.byKey(_loading), findsOneWidget);
    expect(find.byKey(_panel), findsNothing);
    expect(t.getSize(find.byType(CardArt)), const Size(320, 180));
    await _untilDecoded(t);
    expect(find.byKey(_loading), findsNothing);
    expect(t.getSize(find.byType(CardArt)), const Size(320, 180));
  });

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
