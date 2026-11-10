import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/floating_bar.dart';
import 'package:buddhist_gatha/design/widgets/progress_line.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

// Every test here opens the bundled content with openReal, and only that way.

final _topBar = find.byKey(const ValueKey('reader-top-bar'));
final _play = find.byKey(const ValueKey('reader-play'));
final _prev = find.byKey(const ValueKey('reader-prev'));
final _next = find.byKey(const ValueKey('reader-next'));
final _audioPlay = find.byKey(const ValueKey('audio-play'));

NamoPalette paletteOf(WidgetTester t) =>
    NamoPalette.of(t.element(find.byType(ProgressLine)));

Icon iconIn(WidgetTester t, Finder f) =>
    t.widget<Icon>(find.descendant(of: f, matching: find.byType(Icon)));

void expectAtLeastTouchTarget(WidgetTester t, Finder f, String reason) {
  final size = t.getSize(f);
  expect(size.width, greaterThanOrEqualTo(48), reason: reason);
  expect(size.height, greaterThanOrEqualTo(48), reason: reason);
}

/// The lowest edge of any verse text in the reading.
double lastVerseBottom(WidgetTester t) {
  final verses = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('verse-'),
  );
  expect(verses, findsWidgets);
  var bottom = double.negativeInfinity;
  for (final e in verses.evaluate()) {
    final text = find.descendant(
      of: find.byWidget(e.widget),
      matching: find.byType(Text),
    );
    final b = t.getRect(text.first).bottom;
    if (b > bottom) bottom = b;
  }
  return bottom;
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('the top bar: Back, favourite and settings are 48-px buttons '
      'on a flat bar', (t) async {
    await openReal(t, Routes.reader(realReadingId));
    for (final label in ['Back', 'Add to favourites', 'Reading settings']) {
      final f = find.byTooltip(label);
      expect(f, findsOneWidget, reason: label);
      expectAtLeastTouchTarget(t, f, label);
      expect(
        find.descendant(of: _topBar, matching: f),
        findsOneWidget,
        reason: label,
      );
    }
    final bars = t.widgetList<AppBar>(find.byType(AppBar));
    for (final bar in bars) {
      expect(bar.elevation, 0);
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('the progress line sits right under the top bar, full width, '
      'announced once', (t) async {
    await openReal(t, Routes.reader(realReadingId));
    final line = t.getRect(find.byType(ProgressLine));
    final bar = t.getRect(_topBar);
    expect(line.top, closeTo(bar.bottom, 0.01));
    expect(line.left, 0);
    expect(line.width, 390);
    expect(find.bySemanticsLabel('Reading progress'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('favourite and bookmark fill in gold when on', (t) async {
    await openReal(t, Routes.reader(realReadingId));
    final p = paletteOf(t);

    final add = find.byTooltip('Add to favourites');
    expect(iconIn(t, add).fill, 0);
    await t.tap(add);
    await t.pump();
    final remove = find.byTooltip('Remove from favourites');
    expect(iconIn(t, remove).fill, 1);
    expect(iconIn(t, remove).color, p.gold);

    final mark = find.byTooltip('Bookmark this section').first;
    expect(iconIn(t, mark).fill, 0);
    await t.tap(mark);
    await t.pump();
    final unmark = find.byTooltip('Remove bookmark');
    expect(unmark, findsOneWidget);
    expect(iconIn(t, unmark).fill, 1);
    expect(iconIn(t, unmark).color, p.gold);
    expect(t.takeException(), isNull);
  });

  testWidgets('the play button is a 56-px sage circle between 48-px '
      'previous and next', (t) async {
    await openReal(t, Routes.reader(realReadingId));
    final p = paletteOf(t);
    expect(t.getSize(_play), const Size(56, 56));
    final disc = find.descendant(
      of: _play,
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == p.sage &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(disc, findsOneWidget);
    expect(t.getSize(disc), const Size(56, 56));
    expect(iconIn(t, _play).color, p.onSage);
    expectAtLeastTouchTarget(t, _prev, 'previous');
    expectAtLeastTouchTarget(t, _next, 'next');
    expect(t.getCenter(_prev).dx, lessThan(t.getCenter(_play).dx));
    expect(t.getCenter(_next).dx, greaterThan(t.getCenter(_play).dx));
    expect(t.takeException(), isNull);
  });

  for (final size in const [Size(390, 844), Size(844, 390)]) {
    testWidgets('at the end the last verse clears the control bar: '
        '${size.width.round()}x${size.height.round()}', (t) async {
      await openReal(t, Routes.reader(realReadingId), size: size);
      final position = t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await t.pump();
      final bar = t.getRect(find.byType(FloatingBar));
      expect(lastVerseBottom(t), lessThanOrEqualTo(bar.top));
      // The bar floats 12 above the foot of the screen, 16 from each side
      // (or centred at most 680 wide).
      expect(bar.bottom, closeTo(size.height - 12, 0.01));
      expect(bar.width, lessThanOrEqualTo(NamoSizes.readingColumn));
      expect(bar.left, greaterThanOrEqualTo(16));
      expect(bar.center.dx, closeTo(size.width / 2, 0.01));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('a recording puts its controls in the floating bar, above '
      'play', (t) async {
    await openReal(t, Routes.reader(realReadingId), audio: true);
    expect(
      find.descendant(of: find.byType(FloatingBar), matching: _audioPlay),
      findsOneWidget,
    );
    expect(
      t.getRect(_audioPlay).bottom,
      lessThanOrEqualTo(t.getRect(_play).top),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('without a recording there are no audio controls', (t) async {
    await openReal(t, Routes.reader(realReadingId));
    expect(_audioPlay, findsNothing);
    expect(
      find.descendant(of: find.byType(FloatingBar), matching: _play),
      findsOneWidget,
    );
  });

  const cases = [
    (Size(320, 568), 2.0),
    (Size(360, 740), 1.0),
    (Size(360, 740), 1.5),
    (Size(390, 844), 1.0),
    (Size(390, 844), 1.5),
    (Size(840, 1100), 1.0),
    (Size(840, 1100), 1.5),
    (Size(1280, 800), 1.0),
    (Size(1280, 800), 1.5),
  ];
  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    for (final (size, scale) in cases) {
      for (final audio in [false, true]) {
        testWidgets('no overflow: ${size.width.round()}x${size.height.round()}'
            ', device text $scale, ${theme.name}'
            '${audio ? ', with a recording' : ''}', (t) async {
          await openReal(
            t,
            Routes.reader(realReadingId),
            size: size,
            deviceTextScale: scale,
            settings: AppSettings(themeMode: theme),
            audio: audio,
          );
          expect(t.takeException(), isNull);
          await scrollThrough(t);
          final bar = t.getRect(find.byType(FloatingBar));
          expect(bar.bottom, lessThanOrEqualTo(size.height));
          expect(lastVerseBottom(t), lessThanOrEqualTo(bar.top));
        });
      }
    }
  }
}
