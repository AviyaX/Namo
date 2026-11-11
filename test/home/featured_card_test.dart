import 'dart:io';
import 'dart:math' as math;

import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/home/card_art.dart';
import 'package:buddhist_gatha/home/featured_card.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../quality/quality_support.dart';
import '../support/test_content.dart';

// The behaviour of the former reading card (its picture, its label, its
// focus, hover and press) is guarded here, on the featured card that took
// its place.

const _panel = ValueKey('card-art-panel');
const _picture = ValueKey('card-art-picture');
const _loading = ValueKey('card-art-loading');

/// Lets the real image decoder finish (it runs outside fake-async time).
Future<void> _untilDecoded(WidgetTester t) async {
  for (var i = 0; i < 100; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
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
            height: 180,
            child: TopicPicture(categoryId: 'c1', pictures: pictures),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  setUpAll(loadBundledFonts);

  test('onPicture over the scrim at its weakest behind text, laid on pure '
      'white, has a contrast of at least 4.5', () {
    const white = Color(0xFFFFFFFF);
    final behind = Color.alphaBlend(
      NamoPalette.pictureScrim.withValues(alpha: pictureFadeAtText),
      white,
    );
    expect(_contrast(NamoPalette.onPicture, behind), greaterThanOrEqualTo(4.5));
    expect(pictureFadeAtText, 0.70);
    expect(pictureFadeAtBottom, 0.90);
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('the words on the picture are onPicture (${theme.name})', (
      t,
    ) async {
      await openReal(t, Routes.home, settings: AppSettings(themeMode: theme));
      final c = (await realLibrary(t)).categories.first;
      final card = find.byType(FeaturedCard);
      for (final s in ['Buddha Vandana', c.title, c.subtitle, '19 sections']) {
        final text = t.widget<Text>(
          find.descendant(of: card, matching: find.text(s)),
        );
        expect(text.style!.color, NamoPalette.onPicture, reason: s);
      }
    });
  }

  testWidgets('the card is one button for screen readers, labelled '
      '"<title>, <subtitle>, <count>"', (t) async {
    final handle = t.ensureSemantics();
    await openReal(t, Routes.home);
    final c = (await realLibrary(t)).categories.first;
    final node = find.bySemanticsLabel('${c.title}, ${c.subtitle}, 19 sections');
    expect(node, findsOneWidget);
    expect(
      t.getSemantics(node).getSemanticsData().flagsCollection.isButton,
      isTrue,
    );
    // One node: the title and the subtitle are not separate nodes.
    expect(find.bySemanticsLabel(c.title), findsNothing);
    expect(find.bySemanticsLabel(c.subtitle), findsNothing);
    handle.dispose();
  });

  testWidgets('on a phone the card shows assets/pictures/buddha_wandanawa.jpg, '
      'decoded no wider than needed', (t) async {
    await openReal(t, Routes.home);
    await _untilDecoded(t);
    final picture = find.descendant(
      of: find.byType(FeaturedCard),
      matching: find.byKey(_picture),
    );
    expect(picture, findsOneWidget);
    expect(
      find.descendant(of: find.byType(FeaturedCard), matching: find.byKey(_panel)),
      findsNothing,
    );
    final image = t.widget<Image>(picture);
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.center);
    expect((image.image as ResizeImage).width, lessThanOrEqualTo(1600));
    expect(
      ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
      'assets/pictures/buddha_wandanawa.jpg',
    );
  });

  test('every registered picture is a bundled asset listed in pubspec.yaml', () async {
    expect(cardPictures['cat-namaskaraya'], 'assets/pictures/buddha_wandanawa.jpg');
    expect(widePictures['cat-namaskaraya'], 'assets/pictures/home_banner.jpg');
    expect(featuredOverlines['cat-namaskaraya'], 'Buddha Vandana');
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final path in [...cardPictures.values, ...widePictures.values]) {
      expect(pubspec, contains('- $path'));
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: path);
    }
  });

  testWidgets('the picture is excluded from semantics and the card label is '
      'unchanged', (t) async {
    final handle = t.ensureSemantics();
    await openReal(t, Routes.home);
    await _untilDecoded(t);
    final c = (await realLibrary(t)).categories.first;
    expect(c.id, 'cat-namaskaraya');
    expect(find.bySemanticsLabel('${c.title}, ${c.subtitle}, 19 sections'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TopicPicture).first,
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    expect(
      find.bySemanticsLabel(
        RegExp('buddha_wandanawa|home_banner|jpg|picture', caseSensitive: false),
      ),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('while the picture decodes the slot shows the plain ground and '
      'keeps its size', (t) async {
    await _pumpArt(t, pictures: {'c1': 'assets/pictures/buddha_wandanawa.jpg'});
    expect(find.byKey(_loading), findsOneWidget);
    expect(find.byKey(_panel), findsNothing);
    expect(t.getSize(find.byType(TopicPicture)), const Size(320, 180));
    await _untilDecoded(t);
    expect(find.byKey(_loading), findsNothing);
    expect(t.getSize(find.byType(TopicPicture)), const Size(320, 180));
  });

  testWidgets('the lotus panel: backgroundAlt ground, one lotus in gold at low '
      'strength, no text', (t) async {
    for (final brightness in Brightness.values) {
      await _pumpArt(t, brightness: brightness);
      final p = brightness == Brightness.light ? NamoPalette.light : NamoPalette.dark;
      final icon = t.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Symbols.spa_rounded);
      expect(icon.weight, 300);
      expect(icon.color!.toARGB32() & 0x00FFFFFF, p.gold.toARGB32() & 0x00FFFFFF);
      expect(icon.color!.a, lessThan(0.6));
      expect(icon.size, closeTo(t.getSize(find.byKey(_panel)).height * 0.4, 0.5));
      expect(find.byType(Text), findsNothing);
      final box = t.widget<DecoratedBox>(find.byKey(_panel));
      expect((box.decoration as BoxDecoration).color, p.backgroundAlt);
    }
  });

  testWidgets('a registered picture is shown, and a picture that fails to load '
      'falls back to the lotus panel', (t) async {
    await _pumpArt(t, pictures: {'c1': 'assets/branding/namo_icon_square.png'});
    expect(find.byKey(_picture), findsOneWidget);
    expect(find.byKey(_panel), findsNothing);
    expect(t.widget<Image>(find.byType(Image)).fit, BoxFit.cover);

    await _pumpArt(t, pictures: {'c1': 'assets/pictures/missing.png'});
    await t.pump();
    await t.pump();
    expect(find.byKey(_panel), findsOneWidget);
    expect(t.takeException(), isNull);

    // A topic that is not registered gets the panel.
    await _pumpArt(t, pictures: {'other': 'assets/branding/namo_icon_square.png'});
    expect(find.byKey(_panel), findsOneWidget);
  });

  testWidgets('the picture is left out of the semantics tree', (t) async {
    final handle = t.ensureSemantics();
    await _pumpArt(t, pictures: {'c1': 'assets/branding/namo_icon_square.png'});
    expect(
      find.descendant(
        of: find.byType(TopicPicture),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets('a thumbnail is a 56 square with radius 12', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: namoTheme(Brightness.dark),
        home: const Center(child: TopicThumbnail(categoryId: 'c1')),
      ),
    );
    expect(t.getSize(find.byType(TopicThumbnail)), const Size(56, 56));
    final clip = t.widget<ClipRRect>(
      find.descendant(of: find.byType(TopicThumbnail), matching: find.byType(ClipRRect)),
    );
    expect(clip.borderRadius, BorderRadius.circular(12));
  });

  test('section counts', () {
    final c = testLibrary().categories.first;
    expect(sectionCount(c), 3);
    expect(sectionCountLabel(1), '1 section');
    expect(sectionCountLabel(0), '0 sections');
    expect(sectionCountLabel(19), '19 sections');
  });

  testWidgets('focused by keyboard the card shows the focus ring; hover and '
      'press do not throw', (t) async {
    await openReal(t, Routes.home, library: testLibrary());
    final card = find.byType(FeaturedCard);

    bool cardFocused() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<FeaturedCard>() !=
        null;
    for (var i = 0; i < 20 && !cardFocused(); i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
    }
    expect(cardFocused(), isTrue);
    expect(
      find.descendant(of: card, matching: find.byKey(const ValueKey('pressable-focus-ring'))),
      findsOneWidget,
    );

    // Hover with a mouse.
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(t.getTopLeft(card) + const Offset(40, 40));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);

    // Press and release: the one-reading topic opens the reader.
    final press = await t.startGesture(t.getTopLeft(card) + const Offset(40, 40));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
    await press.up();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
