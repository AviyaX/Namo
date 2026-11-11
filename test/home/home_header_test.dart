import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:buddhist_gatha/app.dart';
import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/design/marks.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/home/card_art.dart';
import 'package:buddhist_gatha/home/featured_carousel.dart';
import 'package:buddhist_gatha/home/home_header.dart';
import 'package:buddhist_gatha/home/today.dart';
import 'package:buddhist_gatha/reader/screen_awake.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../quality/quality_support.dart';
import '../support/fake_screen_awake.dart';
import '../support/test_content.dart';

const _tagline = 'Buddhist Prayers · Chanting';
const _backdrop = ValueKey('home-backdrop');
const _fade = ValueKey('home-backdrop-fade');
const _sideFade = ValueKey('home-backdrop-side-fade');
const _search = ValueKey('home-search');

final _morning = clockProvider.overrideWithValue(
  () => DateTime(2026, 3, 4, 8),
);

/// A picture's pixels, decoded at full size.
class _Picture {
  _Picture(this.width, this.height, this.rgba);
  final int width;
  final int height;
  final Uint8List rgba;

  Color at(double x, double y) {
    final px = x.floor().clamp(0, width - 1);
    final py = y.floor().clamp(0, height - 1);
    final i = (py * width + px) * 4;
    return Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]);
  }
}

Future<_Picture> _decode(WidgetTester t, String asset) async =>
    (await t.runAsync(() async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      final bytes = await image.toByteData();
      final picture = _Picture(
        image.width,
        image.height,
        bytes!.buffer.asUint8List(),
      );
      image.dispose();
      return picture;
    }))!;

double _luminance(Color c) {
  double channel(double v) => v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The colour of the 2-stop vertical gradient at [f] (0 top, 1 bottom).
Color _gradientAt(LinearGradient g, double f) {
  final stops = g.stops ?? [0.0, 1.0];
  if (f <= stops.first) return g.colors.first;
  if (f >= stops.last) return g.colors.last;
  return Color.lerp(
    g.colors.first,
    g.colors.last,
    (f - stops.first) / (stops.last - stops.first),
  )!;
}

/// The normal distribution's cumulative function (Abramowitz and Stegun
/// 7.1.26, good to 1.5e-7).
double _phi(double z) {
  final x = z.abs() / math.sqrt2;
  final t = 1 / (1 + 0.3275911 * x);
  final erf = 1 -
      (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
                  0.284496736) *
              t +
          0.254829592) *
          t *
          math.exp(-x * x);
  return z >= 0 ? (1 + erf) / 2 : (1 - erf) / 2;
}

/// How much of a blurred box shadow covers the point [x], [y]: the blur of a
/// rectangle is the product of the blurs along each side.
double _shadowCover(BoxShadow s, Rect box, double x, double y) {
  final r = box.inflate(s.spreadRadius);
  final sigma = s.blurSigma;
  double along(double v, double lo, double hi) =>
      _phi((v - lo) / sigma) - _phi((v - hi) / sigma);
  return along(x, r.left, r.right) * along(y, r.top, r.bottom);
}

/// What the page shows at the global point [x], [y]: the page background,
/// or the header picture (cover, top right) under its fade; then the words'
/// own scrim over that.
Color _ground(
  _Picture picture,
  Rect box,
  LinearGradient fade,
  LinearGradient? sideFade,
  Color background,
  (BoxShadow, Rect) scrim,
  double x,
  double y,
) {
  final (shadow, around) = scrim;
  final cover = _shadowCover(shadow, around, x, y);
  final glow = shadow.color.withValues(alpha: shadow.color.a * cover);
  return Color.alphaBlend(
    glow,
    _picture(picture, box, fade, sideFade, background, x, y),
  );
}

/// The colour of a gradient of any number of stops at [f] (0 at its begin,
/// 1 at its end).
Color _stopsAt(LinearGradient g, double f) {
  final stops = g.stops!;
  if (f <= stops.first) return g.colors.first;
  for (var i = 1; i < stops.length; i++) {
    if (f <= stops[i]) {
      final span = stops[i] - stops[i - 1];
      return Color.lerp(
        g.colors[i - 1],
        g.colors[i],
        span == 0 ? 1 : (f - stops[i - 1]) / span,
      )!;
    }
  }
  return g.colors.last;
}

Color _picture(
  _Picture picture,
  Rect box,
  LinearGradient fade,
  LinearGradient? sideFade,
  Color background,
  double x,
  double y,
) {
  if (!box.contains(Offset(x, y))) return background;
  final scale = math.max(
    box.width / picture.width,
    box.height / picture.height,
  );
  final left = box.right - picture.width * scale;
  final pic = picture.at((x - left) / scale, (y - box.top) / scale);
  var shown = Color.alphaBlend(
    _gradientAt(fade, (y - box.top) / box.height),
    pic,
  );
  if (sideFade != null) {
    shown = Color.alphaBlend(
      _stopsAt(sideFade, (x - box.left) / box.width),
      shown,
    );
  }
  return shown;
}

/// The side fade, when there is one.
LinearGradient? _sideFadeOf(WidgetTester t) {
  final f = find.byKey(_sideFade);
  if (f.evaluate().isEmpty) return null;
  return (t.widget<DecoratedBox>(f).decoration as BoxDecoration).gradient!
      as LinearGradient;
}

/// The lowest contrast between [text]'s colour (or [color]) and anything
/// under its box.
double _worstContrast(
  WidgetTester t,
  Finder text,
  _Picture picture,
  Color background, {
  Color? color,
}) {
  color ??= t.widget<Text>(text).style!.color!;
  final rect = t.getRect(text);
  final box = t.getRect(find.byKey(_backdrop));
  final fade =
      (t.widget<DecoratedBox>(find.byKey(_fade)).decoration as BoxDecoration)
              .gradient!
          as LinearGradient;
  final scrimFinder = find.ancestor(
    of: text,
    matching: find.byKey(const ValueKey('home-header-scrim')),
  );
  final shadow =
      (t.widget<DecoratedBox>(scrimFinder).decoration as BoxDecoration)
          .boxShadow!
          .single;
  final scrim = (shadow, t.getRect(scrimFinder));
  var worst = double.infinity;
  for (var y = rect.top + 0.5; y < rect.bottom; y += 1) {
    for (var x = rect.left + 0.5; x < rect.right; x += 1) {
      final c = _contrast(
        color,
        _ground(picture, box, fade, _sideFadeOf(t), background, scrim, x, y),
      );
      if (c < worst) worst = c;
    }
  }
  return worst;
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('the lotus mark, "Namo", the tagline and the greeting', (
    t,
  ) async {
    await openReal(t, Routes.home, overrides: [_morning]);
    final header = find.byType(HomeHeader);
    expect(header, findsOneWidget);
    final mark = t.widget<NamoMarkIcon>(
      find.descendant(of: header, matching: find.byType(NamoMarkIcon)),
    );
    expect(mark.mark, NamoMark.lotus);
    expect(mark.size, 40);
    for (final s in ['Namo', _tagline, 'Good morning']) {
      expect(
        find.descendant(of: header, matching: find.text(s)),
        findsOneWidget,
      );
    }
    // The tagline sits under the wordmark, the greeting under both.
    expect(
      t.getRect(find.text(_tagline)).top,
      greaterThanOrEqualTo(t.getRect(find.text('Namo')).bottom),
    );
    expect(
      t.getRect(find.text('Good morning')).top,
      greaterThanOrEqualTo(t.getRect(find.text(_tagline)).bottom),
    );
    final p = NamoPalette.of(t.element(header));
    expect(t.widget<Text>(find.text(_tagline)).style!.color, p.textSecondary);
  });

  testWidgets('"Namo" is still a heading', (t) async {
    final handle = t.ensureSemantics();
    await openReal(t, Routes.home);
    expect(
      t.getSemantics(find.text('Namo')),
      matchesSemantics(label: 'Namo', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('no bell: no notifications control on Home', (t) async {
    await openReal(t, Routes.home);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            {
              Icons.notifications,
              Icons.notifications_none,
              Icons.notifications_outlined,
              Symbols.notifications,
              Symbols.notifications_rounded,
              Symbols.notifications_sharp,
            }.contains(w.icon),
      ),
      findsNothing,
    );
    expect(find.byTooltip('Notifications'), findsNothing);
  });

  testWidgets('the search button is labelled and goes to the Library\'s '
      'search', (t) async {
    final handle = t.ensureSemantics();
    await openReal(t, Routes.home);
    final button = find.byKey(const ValueKey('home-search'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.byTooltip('Search the library')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: button, matching: find.byIcon(Symbols.search_rounded)),
      findsOneWidget,
    );
    // A screen reader names the button by its tooltip.
    expect(
      t
          .getSemantics(
            find.descendant(of: button, matching: find.byType(Icon)),
          )
          .getSemanticsData()
          .tooltip,
      'Search the library',
    );
    handle.dispose();
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
  });

  group('the backdrop', () {
    for (final dark in [false, true]) {
      final theme = dark ? 'dark' : 'light';

      testWidgets('$theme: the theme\'s header picture, cover, top right, '
          'left out of semantics', (t) async {
        await openReal(t, Routes.home, dark: dark);
        final image = t.widget<Image>(
          find.descendant(
            of: find.byKey(_backdrop),
            matching: find.byType(Image),
          ),
        );
        var provider = image.image;
        if (provider is ResizeImage) provider = provider.imageProvider;
        expect(
          (provider as AssetImage).assetName,
          dark ? headerPictures.dark : headerPictures.light,
        );
        expect(image.fit, BoxFit.cover);
        expect(image.alignment, Alignment.topRight);
        expect(
          find.ancestor(
            of: find.byKey(_backdrop),
            matching: find.byType(ExcludeSemantics),
          ),
          findsWidgets,
        );
      });

      testWidgets('$theme: the fade ends in the page background at full '
          'strength, over the lowest 40%', (t) async {
        await openReal(t, Routes.home, dark: dark);
        final p = NamoPalette.of(t.element(find.byKey(_backdrop)));
        final fade =
            (t.widget<DecoratedBox>(find.byKey(_fade)).decoration
                        as BoxDecoration)
                    .gradient!
                as LinearGradient;
        expect(fade.begin, Alignment.topCenter);
        expect(fade.end, Alignment.bottomCenter);
        expect(fade.stops, [0.6, 1.0]);
        expect(fade.colors.last, p.background);
        expect(fade.colors.last.a, 1.0);
        expect(fade.colors.first.a, 0.0);
        expect(t.getRect(find.byKey(_fade)), t.getRect(find.byKey(_backdrop)));
      });

      // The words sit over the picture: every pixel under each line's box
      // (the picture under its fade, or the page) gives the line its
      // contrast — 4.5 : 1, or 3 : 1 for the 28 px wordmark.
      final cases = <(Size, double, double)>[
        (const Size(320, 568), 24, 2.0),
        (const Size(360, 800), 24, 1.5),
        (const Size(390, 844), 47, 1.0),
        (const Size(390, 844), 0, 2.0),
        (const Size(600, 900), 24, 1.0),
        (const Size(840, 800), 0, 1.0),
        (const Size(1280, 800), 0, 1.0),
        (const Size(1280, 800), 0, 2.0),
      ];
      for (final (size, top, scale) in cases) {
        testWidgets('$theme, ${size.width.round()} x ${size.height.round()}, '
            'top inset ${top.round()}, text $scale: the words keep their '
            'contrast', (t) async {
          t.view.padding = FakeViewPadding(top: top);
          await openReal(
            t,
            Routes.home,
            dark: dark,
            size: size,
            deviceTextScale: scale,
            overrides: [_morning],
          );
          final picture = await _decode(
            t,
            dark ? headerPictures.dark : headerPictures.light,
          );
          final p = NamoPalette.of(t.element(find.byKey(_backdrop)));
          expect(
            _worstContrast(t, find.text('Namo'), picture, p.background),
            greaterThanOrEqualTo(3.0),
          );
          for (final s in [_tagline, 'Good morning']) {
            expect(
              _worstContrast(t, find.text(s), picture, p.background),
              greaterThanOrEqualTo(4.5),
              reason: s,
            );
          }
          // The search icon, a control, at least 3 : 1 against anything
          // under its glyph's box.
          final icon = find.descendant(
            of: find.byKey(_search),
            matching: find.byType(Icon),
          );
          expect(
            _worstContrast(
              t,
              icon,
              picture,
              p.background,
              color: t.widget<Icon>(icon).color,
            ),
            greaterThanOrEqualTo(3.0),
            reason: 'search icon',
          );
        });
      }
    }

    testWidgets('on a phone it runs from the very top of the screen, edge '
        'to edge, width / 3 plus the top inset tall', (t) async {
      t.view.padding = const FakeViewPadding(top: 47);
      await openReal(t, Routes.home);
      final box = t.getRect(find.byKey(_backdrop));
      expect(box.top, 0);
      expect(box.left, 0);
      expect(box.width, 390);
      expect(box.height, closeTo(390 / 3 + 47, 0.01));
    });

    testWidgets('on a wide screen it spans the Home column, ending above '
        'the featured card', (t) async {
      await openReal(t, Routes.home, size: const Size(1280, 800));
      final box = t.getRect(find.byKey(_backdrop));
      final column = t.getRect(find.byKey(const ValueKey('home-column')));
      expect(box.top, 0);
      expect(box.left, column.left);
      expect(box.width, column.width);
      expect(box.height, HomeBackdrop.maxHeight);
    });

    // The picture has faded fully into the page before the featured card
    // starts, so the card never cuts it in a hard line.
    for (final (size, scale) in <(Size, double)>[
      (const Size(320, 568), 1.0),
      (const Size(360, 800), 1.0),
      (const Size(390, 844), 1.0),
      (const Size(600, 900), 1.0),
      (const Size(1280, 800), 1.0),
      (const Size(1280, 800), 2.0),
    ]) {
      testWidgets('${size.width.round()} wide, text $scale: the picture '
          'ends above the featured card', (t) async {
        await openReal(
          t,
          Routes.home,
          size: size,
          deviceTextScale: scale,
        );
        final box = t.getRect(find.byKey(_backdrop));
        final card = t.getRect(find.byType(FeaturedCarousel));
        expect(box.bottom, lessThanOrEqualTo(card.top + 0.01));
      });
    }

    for (final dark in [false, true]) {
      testWidgets('${dark ? 'dark' : 'light'}: on a wide screen the picture '
          'fades into the page at both sides of the column too', (t) async {
        await openReal(t, Routes.home, dark: dark, size: const Size(1280, 800));
        final p = NamoPalette.of(t.element(find.byKey(_backdrop)));
        final side = _sideFadeOf(t)!;
        expect(side.begin, Alignment.centerLeft);
        expect(side.end, Alignment.centerRight);
        expect(side.colors.first, p.background);
        expect(side.colors.last, p.background);
        expect(side.stops!.first, 0);
        expect(side.stops!.last, 1);
        for (final c in side.colors.sublist(1, side.colors.length - 1)) {
          expect(c.a, 0);
        }
        expect(
          t.getRect(find.byKey(_sideFade)),
          t.getRect(find.byKey(_backdrop)),
        );
      });
    }

    testWidgets('on a phone, edge to edge, there is no side fade', (t) async {
      await openReal(t, Routes.home);
      expect(find.byKey(_sideFade), findsNothing);
    });

    testWidgets('it scrolls away with the content', (t) async {
      await openReal(t, Routes.home, library: severalCategories());
      final before = t.getRect(find.byKey(_backdrop)).top;
      final position = t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(100);
      await t.pump();
      expect(t.getRect(find.byKey(_backdrop)).top, before - 100);
    });

    testWidgets('a missing picture leaves the backdrop empty and Home '
        'builds', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            contentRepositoryProvider.overrideWithValue(
              FakeContentRepository(),
            ),
            screenAwakeProvider.overrideWithValue(FakeScreenAwake()),
            routerProvider.overrideWith(
              (ref) => buildRouter(initialLocation: Routes.home),
            ),
          ],
          child: DefaultAssetBundle(
            bundle: _WithoutHeaderPictures(),
            child: const NamoApp(),
          ),
        ),
      );
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('screen-home')), findsOneWidget);
      expect(find.byType(HomeHeader), findsOneWidget);
      expect(find.byKey(_backdrop), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_backdrop),
          matching: find.byType(RawImage),
        ),
        findsNothing,
      );
    });
  });
}

/// The bundled assets, less the header pictures.
class _WithoutHeaderPictures extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == headerPictures.dark || key == headerPictures.light) {
      throw FlutterError('Unable to load asset: $key');
    }
    return rootBundle.load(key);
  }
}
