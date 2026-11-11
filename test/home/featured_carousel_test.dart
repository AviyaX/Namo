import 'dart:convert';

import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/progress_line.dart';
import 'package:buddhist_gatha/home/card_art.dart';
import 'package:buddhist_gatha/home/featured_card.dart';
import 'package:buddhist_gatha/home/featured_carousel.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

/// A stored place in [readingId] at [progress], read last.
Future<Map<String, String>> _remember(
  WidgetTester t,
  String readingId,
  double progress,
) async {
  final reading = (await realLibrary(t)).reading(readingId)!;
  return {
    positionKey: jsonEncode(
      PositionState(
        byReading: {
          readingId: ReadingProgress(
            position: ReadingPosition(
              readingId: readingId,
              sectionId: reading.sections.first.id,
              fraction: 0,
            ),
            progress: progress,
          ),
        },
        lastReadingId: readingId,
      ).toJson(),
    ),
  };
}

Finder get _carousel => find.byType(FeaturedCarousel);

/// The page on screen (the others are not built, or are offstage).
Finder get _card => find.byType(FeaturedCard);

Finder _inCard(Finder f) => find.descendant(of: _card, matching: f);

String _shownTopic(WidgetTester t) => t.widget<FeaturedCard>(_card).category.id;

SemanticsNode _node(WidgetTester t) =>
    t.getSemantics(find.bySemanticsLabel('Featured collections'));

PageController _controller(WidgetTester t) => t
    .widget<PageView>(find.descendant(of: _carousel, matching: find.byType(PageView)))
    .controller!;

/// Swipes the carousel one page to the left.
Future<void> _swipeNext(WidgetTester t) async {
  await t.fling(
    find.descendant(of: _carousel, matching: find.byType(PageView)),
    const Offset(-300, 0),
    1000,
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('first launch: page 1 of 3, Buddha Wandanawa, "Begin", no '
      'progress line and no "% complete"', (t) async {
    final handle = t.ensureSemantics();
    await openReal(t, Routes.home);
    expect(_shownTopic(t), realCategoryId);
    expect(_inCard(find.text('Begin')), findsOneWidget);
    expect(_inCard(find.text('Continue')), findsNothing);
    expect(find.descendant(of: _carousel, matching: find.byType(ProgressLine)), findsNothing);
    expect(find.textContaining('% complete'), findsNothing);
    expect(_node(t).value, 'Page 1 of 3');
    // The overline, shown upper-cased.
    expect(_inCard(find.text('FEATURED COLLECTION')), findsOneWidget);
    expect(find.text('Buddha Vandana'), findsNothing);
    handle.dispose();
  });

  testWidgets('remembered Buddha Wandanawa at 0.34: "Continue", "34% complete" '
      'over a rounded 4 px progress line', (t) async {
    final handle = t.ensureSemantics();
    await openReal(
      t,
      Routes.home,
      storeExtras: await _remember(t, realReadingId, 0.34),
    );
    final c = (await realLibrary(t)).category(realCategoryId)!;
    expect(_shownTopic(t), realCategoryId);
    expect(_inCard(find.text('Continue')), findsOneWidget);
    expect(_inCard(find.text('34% complete')), findsOneWidget);
    final line = t.widget<ProgressLine>(_inCard(find.byType(ProgressLine)));
    expect(line.value, 0.34);
    expect(line.height, 4);
    expect(line.rounded, isTrue);
    // The percent sits at the lower right of the card.
    final card = t.getRect(_card);
    final percent = t.getRect(_inCard(find.text('34% complete')));
    expect(percent.left, greaterThan(card.center.dx));
    expect(percent.bottom, greaterThan(card.center.dy));
    expect(
      find.bySemanticsLabel(
        '${c.title}, ${c.subtitle}, 19 sections, Continue, 34% complete',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('last read a pirith: the carousel starts on Pirith with that '
      "pirith's title and \"Continue\", and opens it", (t) async {
    final handle = t.ensureSemantics();
    await openReal(
      t,
      Routes.home,
      storeExtras: await _remember(t, mangalaReadingId, 0.5),
    );
    final reading = (await realLibrary(t)).reading(mangalaReadingId)!;
    expect(_shownTopic(t), pirithCategoryId);
    expect(_node(t).value, 'Page 2 of 3');
    expect(_inCard(find.text(reading.title)), findsOneWidget);
    expect(_inCard(find.text('Continue')), findsOneWidget);
    expect(_inCard(find.text('50% complete')), findsOneWidget);
    handle.dispose();

    await t.tap(_inCard(find.text('Continue')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
    expect(find.text(reading.title), findsWidgets);
  });

  testWidgets('a stale remembered id: page 1, no progress, nothing thrown', (
    t,
  ) async {
    await openReal(
      t,
      Routes.home,
      storeExtras: {
        positionKey: jsonEncode({
          'byReading': {
            'gone': {
              'position': {'readingId': 'gone', 'sectionId': 's01', 'fraction': 0},
              'progress': 0.5,
            },
          },
          'lastReadingId': 'gone',
        }),
      },
    );
    expect(t.takeException(), isNull);
    expect(_shownTopic(t), realCategoryId);
    expect(_inCard(find.text('Begin')), findsOneWidget);
    expect(find.descendant(of: _carousel, matching: find.byType(ProgressLine)), findsNothing);
    expect(find.textContaining('% complete'), findsNothing);
  });

  testWidgets('a swipe moves to page 2 of 3, Pirith, "Open"; the dots follow', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await openReal(t, Routes.home);
    final dots = find.byKey(const ValueKey('featured-dots'));
    final dark = Theme.of(t.element(_carousel)).brightness == Brightness.dark;
    final p = dark ? NamoPalette.dark : NamoPalette.light;
    List<Color?> dotColours() => [
      for (final e in find
          .descendant(of: dots, matching: find.byType(DecoratedBox))
          .evaluate())
        ((e.widget as DecoratedBox).decoration as BoxDecoration).color,
    ];
    expect(dotColours(), [p.gold, p.border, p.border]);
    expect(t.getSize(find.descendant(of: dots, matching: find.byType(DecoratedBox)).first),
        const Size(6, 6));

    await _swipeNext(t);
    expect(_node(t).value, 'Page 2 of 3');
    expect(_shownTopic(t), pirithCategoryId);
    expect(_inCard(find.text('Open')), findsOneWidget);
    expect(dotColours(), [p.border, p.gold, p.border]);
    handle.dispose();
  });

  testWidgets('it does not move by itself', (t) async {
    await openReal(t, Routes.home);
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(seconds: 5));
    }
    expect(_shownTopic(t), realCategoryId);
    expect(_controller(t).page, 0);
  });

  testWidgets('screen reader increase and decrease move a page; with reduced '
      'motion it jumps without animating', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final handle = t.ensureSemantics();
    await openReal(t, Routes.home);
    final node = _node(t);
    expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.decrease), isFalse);
    node.owner!.performAction(node.id, SemanticsAction.increase);
    await t.pump();
    expect(_controller(t).page, 1, reason: 'there in one frame');
    expect(t.binding.transientCallbackCount, 0, reason: 'nothing animating');
    expect(_node(t).value, 'Page 2 of 3');
    expect(_shownTopic(t), pirithCategoryId);

    final again = _node(t);
    again.owner!.performAction(again.id, SemanticsAction.decrease);
    await t.pump();
    expect(_controller(t).page, 0);
    expect(_node(t).value, 'Page 1 of 3');
    handle.dispose();
  });

  testWidgets('without reduced motion increase animates to the next page', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await openReal(t, Routes.home);
    final node = _node(t);
    node.owner!.performAction(node.id, SemanticsAction.increase);
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(_controller(t).page, inExclusiveRange(0, 1));
    await t.pumpAndSettle();
    expect(_controller(t).page, 1);
    handle.dispose();
  });

  testWidgets('with the card focused, the arrow keys move a page and the '
      'focus goes with it', (t) async {
    await openReal(t, Routes.home);
    bool focusedOn(String categoryId) =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<FeaturedCard>()
            ?.category
            .id ==
        categoryId;
    for (var i = 0; i < 20 && !focusedOn(realCategoryId); i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
    }
    expect(focusedOn(realCategoryId), isTrue);

    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    expect(_shownTopic(t), pirithCategoryId);
    expect(focusedOn(pirithCategoryId), isTrue);
    expect(
      _inCard(find.byKey(const ValueKey('pressable-focus-ring'))),
      findsOneWidget,
    );

    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pumpAndSettle();
    expect(_shownTopic(t), realCategoryId);
    expect(focusedOn(realCategoryId), isTrue);
  });

  testWidgets('one topic: no dots and no paging', (t) async {
    await openReal(t, Routes.home, library: await buddhaOnlyLibrary(t));
    expect(_card, findsOneWidget);
    expect(find.byKey(const ValueKey('featured-dots')), findsNothing);
    expect(find.descendant(of: _carousel, matching: find.byType(PageView)), findsNothing);
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme theme: Buddha Wandanawa shows hero_$theme.jpg, statue '
        'to the right', (t) async {
      await openReal(t, Routes.home, dark: dark);
      final image = t.widget<Image>(_inCard(find.byKey(const ValueKey('card-art-picture'))));
      expect(
        ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
        'assets/pictures/hero_$theme.jpg',
      );
      expect(image.alignment, Alignment.centerRight);
    });

    testWidgets('$theme theme: every word sits where the scrim is at least '
        'pictureFadeAtText strong', (t) async {
      await openReal(
        t,
        Routes.home,
        dark: dark,
        storeExtras: await _remember(t, realReadingId, 0.34),
      );
      final words = t.renderObject<RenderPictureWords>(_inCard(find.byType(PictureWords)));
      expect(words.side, TextSide.left);
      final scrim = t.getRect(_inCard(find.byType(PictureWords)));
      // The left-side scrim: pictureFadeAtBottom at the left edge, falling
      // evenly to pictureFadeAtText at the middle and to nothing at the right.
      double strengthAt(double x) {
        final f = ((x - scrim.left) / scrim.width).clamp(0.0, 1.0);
        return f <= 0.5
            ? pictureFadeAtBottom + (pictureFadeAtText - pictureFadeAtBottom) * f / 0.5
            : pictureFadeAtText * (1 - f) / 0.5;
      }

      final texts = _inCard(find.byType(Text)).evaluate().toList();
      final percent = _inCard(find.text('34% complete'));
      expect(percent, findsOneWidget);
      var checked = 0;
      for (final e in texts) {
        final text = find.byElementPredicate((x) => x == e);
        if (find.descendant(of: _inCard(find.byKey(const ValueKey('featured-progress'))), matching: text).evaluate().isNotEmpty) {
          continue;
        }
        final rect = t.getRect(text);
        expect(strengthAt(rect.right), greaterThanOrEqualTo(pictureFadeAtText - 1e-9),
            reason: (e.widget as Text).data);
        checked++;
      }
      expect(checked, greaterThanOrEqualTo(4));

      // The percent, over the picture's bright side, has a backdrop of its own.
      final backdrop = t.widget<DecoratedBox>(
        _inCard(find.byKey(const ValueKey('featured-progress'))),
      );
      final colour = (backdrop.decoration as BoxDecoration).color!;
      expect(colour.toARGB32() & 0x00FFFFFF, NamoPalette.pictureScrim.toARGB32() & 0x00FFFFFF);
      expect(colour.a, greaterThanOrEqualTo(pictureFadeAtText - 1e-3));
      expect(t.widget<Text>(percent).style!.color, NamoPalette.onPicture);
    });

    testWidgets('$theme theme: 320 x 640 at 200% text, every page whole: no '
        'overflow, every word inside its card', (t) async {
      // Remembered places make the fullest pages (caption, percent).
      final store = await _remember(t, mangalaReadingId, 0.5);
      await openReal(
        t,
        Routes.home,
        dark: dark,
        size: const Size(320, 640),
        deviceTextScale: 2.0,
        storeExtras: store,
      );
      expect(t.takeException(), isNull);
      final pager = find.descendant(of: _carousel, matching: find.byType(PageView));
      _controller(t).jumpToPage(0);
      await t.pumpAndSettle();
      for (var page = 0; page < 3; page++) {
        if (page > 0) {
          _controller(t).jumpToPage(page);
          await t.pumpAndSettle();
        }
        expect(t.takeException(), isNull, reason: 'page $page');
        final card = t.getRect(_card);
        expect(card.height, t.getSize(pager).height, reason: 'page $page');
        for (final e in _inCard(find.byType(Text)).evaluate()) {
          final r = t.getRect(find.byElementPredicate((x) => x == e));
          expect(
            r.left >= card.left - 0.5 &&
                r.right <= card.right + 0.5 &&
                r.top >= card.top - 0.5 &&
                r.bottom <= card.bottom + 0.5,
            isTrue,
            reason: 'page $page: "${(e.widget as Text).data}" at $r, card $card',
          );
        }
      }
      // The dots sit below the pages, not over them.
      expect(
        t.getRect(find.byKey(const ValueKey('featured-dots'))).top,
        greaterThanOrEqualTo(t.getRect(pager).bottom),
      );
    });
  }
}
