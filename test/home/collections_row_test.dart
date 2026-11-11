import 'dart:convert';

import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/progress_line.dart';
import 'package:buddhist_gatha/home/card_art.dart';
import 'package:buddhist_gatha/home/card_row.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../quality/quality_support.dart';

const _block = ValueKey('home-collections');

void _nothing() {}

Finder _card(String id) =>
    find.byKey(ValueKey('collection-$id'), skipOffstage: false);

Finder _inCard(String id, Finder f) =>
    find.descendant(of: _card(id), matching: f, skipOffstage: false);

String _location(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .routeInformationProvider
        .value
        .uri
        .toString();

Future<void> _tapVisible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

/// A stored place in [readingId] (its first section) at [progress], read
/// last. [readingId] need not be in the content.
Future<Map<String, String>> _remembered(
  WidgetTester t,
  String readingId,
  double progress,
) async {
  final reading = (await realLibrary(t)).reading(readingId);
  return {
    positionKey: jsonEncode(
      PositionState(
        byReading: {
          readingId: ReadingProgress(
            position: ReadingPosition(
              readingId: readingId,
              sectionId: reading?.sections.first.id ?? 's01',
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

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('bundled content: a card for each of the three topics, in '
      'order, with title, Sinhala title, book icon and count', (t) async {
    await openReal(t, Routes.home, size: const Size(390, 3000));
    final lib = await realLibrary(t);
    expect(lib.categories, hasLength(3));
    expect(
      find.descendant(of: find.byKey(_block), matching: find.text('Collections')),
      findsOneWidget,
    );
    double? left;
    for (final c in lib.categories) {
      expect(_card(c.id), findsOneWidget, reason: c.id);
      for (final s in [c.title, c.subtitle, topicCountLabel(c)]) {
        expect(_inCard(c.id, find.text(s)), findsOneWidget, reason: s);
      }
      expect(_inCard(c.id, find.byIcon(Symbols.menu_book_rounded)),
          findsOneWidget);
      final x = t.getTopLeft(_card(c.id)).dx;
      if (left != null) expect(x, greaterThan(left));
      left = x;
    }
  });

  testWidgets('each card, its press tint and its picture take the card '
      'radius', (t) async {
    await openReal(t, Routes.home, size: const Size(390, 3000));
    final card = t.widget<TappableCard>(
      _inCard(realCategoryId, find.byType(TappableCard)),
    );
    expect(card.radius, NamoRadius.card);
    expect(
      t.widget<ClipRRect>(_inCard(realCategoryId, find.byType(ClipRRect)).first)
          .borderRadius,
      BorderRadius.circular(NamoRadius.card),
    );
    expect(
      const TappableCard(onTap: _nothing, semanticLabel: '', child: SizedBox())
          .radius,
      NamoRadius.card,
    );
  });

  testWidgets('first launch: no progress on any card', (t) async {
    await openReal(t, Routes.home, size: const Size(390, 3000));
    for (final c in (await realLibrary(t)).categories) {
      expect(_inCard(c.id, find.byType(ProgressLine)), findsNothing);
      expect(_inCard(c.id, find.textContaining('%')), findsNothing);
    }
  });

  testWidgets('a remembered place in the one-reading topic: its card shows a '
      'rounded progress line and "34%", the others none', (t) async {
    final handle = t.ensureSemantics();
    final lib = await realLibrary(t);
    final bw = lib.category(realCategoryId)!;
    await openReal(
      t,
      Routes.home,
      size: const Size(390, 3000),
      storeExtras: await _remembered(t, realReadingId, 0.34),
    );
    final line = t.widget<ProgressLine>(
      _inCard(bw.id, find.byType(ProgressLine)),
    );
    expect(line.value, 0.34);
    expect(line.rounded, isTrue);
    expect(_inCard(bw.id, find.text('34%')), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '${bw.title}, ${bw.subtitle}, ${topicCountLabel(bw)}, 34 percent',
      ),
      findsOneWidget,
    );
    for (final c in lib.categories.skip(1)) {
      expect(_inCard(c.id, find.byType(ProgressLine)), findsNothing);
    }
    handle.dispose();
  });

  testWidgets('a remembered pirith (a topic of several readings): no progress '
      'on its card', (t) async {
    await openReal(
      t,
      Routes.home,
      size: const Size(390, 3000),
      storeExtras: await _remembered(t, mangalaReadingId, 0.5),
    );
    expect(_inCard(pirithCategoryId, find.byType(ProgressLine)), findsNothing);
    expect(_inCard(pirithCategoryId, find.text('50%')), findsNothing);
  });

  testWidgets('a remembered reading that no longer exists: no progress, '
      'nothing thrown', (t) async {
    await openReal(
      t,
      Routes.home,
      size: const Size(390, 3000),
      storeExtras: await _remembered(t, 'gone', 0.5),
    );
    expect(
      find.descendant(
        of: find.byKey(_block),
        matching: find.byType(ProgressLine),
      ),
      findsNothing,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('a card opens its topic in the Library', (t) async {
    await openReal(t, Routes.home);
    await _tapVisible(t, _card(samanthaCategoryId));
    expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-$samanthaCategoryId')),
        findsOneWidget);
  });

  testWidgets('"See all" opens the Library tab', (t) async {
    await openReal(t, Routes.home);
    await _tapVisible(
      t,
      find.descendant(of: find.byKey(_block), matching: find.text('See all')),
    );
    expect(_location(t), Routes.library);
    expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
  });

  testWidgets('a topic with no readings keeps its card, with the drawn panel, '
      'and it opens the topic in the Library', (t) async {
    await openReal(
      t,
      Routes.home,
      library: const Library(
        categories: [
          Category(id: 'c0', title: 'Empty', subtitle: 'Nothing', readings: []),
        ],
      ),
    );
    expect(_card('c0'), findsOneWidget);
    expect(_inCard('c0', find.byKey(const ValueKey('card-art-panel'))),
        findsOneWidget);
    expect(_inCard('c0', find.byType(ProgressLine)), findsNothing);
    await _tapVisible(t, _card('c0'));
    expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-c0')), findsOneWidget);
  });

  testWidgets('phone: cards 220 wide, as tall as the tallest, in a row that '
      'scrolls sideways', (t) async {
    final lib = severalCategories();
    await openReal(t, Routes.home, library: lib, deviceTextScale: 1.5);
    final heights = <double>{};
    for (final c in lib.categories) {
      expect(t.getSize(_card(c.id)).width, 220, reason: c.id);
      heights.add(t.getSize(_card(c.id)).height);
      expect(_inCard(c.id, find.byKey(const ValueKey('card-art-panel'))),
          findsOneWidget);
    }
    expect(heights, hasLength(1));
    expect(t.getTopRight(_card('c4')).dx, greaterThan(390));
  });

  testWidgets('phone: a card that takes keyboard focus is scrolled into view', (
    t,
  ) async {
    await openReal(t, Routes.home, library: severalCategories());
    final last = _card('c4');
    expect(t.getTopLeft(last).dx, greaterThan(390));
    final focus = Focus.of(
      t.element(
        find
            .descendant(
              of: last,
              matching: find.byType(Focus),
              skipOffstage: false,
            )
            .last,
      ),
    );
    await t.ensureVisible(_card('c1'));
    await t.pumpAndSettle();
    for (var i = 0; i < 200 && !focus.hasFocus; i++) {
      FocusManager.instance.primaryFocus?.nextFocus();
      await t.pumpAndSettle();
    }
    expect(focus.hasFocus, isTrue);
    final rect = t.getRect(last);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(390));
  });

  testWidgets('wide: the three cards fill the row, equal in size, no '
      'sideways scroll', (t) async {
    await openReal(t, Routes.home, size: const Size(1280, 3000));
    final lib = await realLibrary(t);
    final block = t.getRect(find.byKey(_block));
    final rects = [for (final c in lib.categories) t.getRect(_card(c.id))];
    expect(rects.first.left, block.left);
    expect(rects.last.right, closeTo(block.right, 0.01));
    for (final r in rects.skip(1)) {
      expect(r.width, closeTo(rects.first.width, 0.01));
      expect(r.height, rects.first.height);
      expect(r.top, rects.first.top);
    }
    expect(
      find.descendant(
        of: find.byKey(_block),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
  });
}
