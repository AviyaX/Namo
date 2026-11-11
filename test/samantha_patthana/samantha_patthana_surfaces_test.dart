import 'dart:convert';

import 'package:buddhist_gatha/design/widgets/list_row.dart';
import 'package:buddhist_gatha/home/continue_card.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

String _location(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .routeInformationProvider
        .value
        .uri
        .toString();

void main() {
  setUpAll(loadBundledFonts);

  group('Saved', () {
    Future<void> open(WidgetTester t) => openReal(
      t,
      Routes.saved,
      size: const Size(390, 2000),
      storeExtras: {
        savedKey: jsonEncode(
          const SavedState(favourites: {spIntroductionId, spVandanaId})
              .toJson(),
        ),
      },
    );

    testWidgets('both readings as favourites: the Vandana with its two names, '
        'the Introduction with the topic subtitle', (t) async {
      final lib = await realLibrary(t);
      final sp = lib.category(samanthaCategoryId)!;
      final intro = lib.reading(spIntroductionId)!;
      final vandana = lib.reading(spVandanaId)!;
      await open(t);
      final rows = {
        for (final r in t.widgetList<ListRow>(find.byType(ListRow))) r.title: r,
      };
      expect(rows[vandana.title]!.subtitle, vandana.titleRoman);
      expect(rows[intro.title]!.title, 'Introduction');
      expect(rows[intro.title]!.subtitle, sp.subtitle);
    });

    for (final id in [spIntroductionId, spVandanaId]) {
      testWidgets('the favourite $id opens its reader', (t) async {
        final r = (await realLibrary(t)).reading(id)!;
        await open(t);
        await t.tap(find.text(r.titleRoman ?? r.title));
        await t.pumpAndSettle();
        expect(_location(t), startsWith(Routes.reader(id)));
      });
    }
  });

  group('Continue reading', () {
    testWidgets('after opening and leaving the Vandana the card shows its '
        'title and Roman name', (t) async {
      final lib = await realLibrary(t);
      final vandana = lib.reading(spVandanaId)!;
      await openReal(t, Routes.reader(spVandanaId));
      // A place is remembered once the page has moved and come to rest.
      final scroll = t.state<ReaderBodyState>(find.byType(ReaderBody));
      scroll.controller.jumpTo(scroll.controller.position.maxScrollExtent / 3);
      await t.pump();
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      await t.tap(find.text('Home'));
      await t.pumpAndSettle();
      final card = find.byType(ContinueCard);
      expect(card, findsOneWidget);
      for (final s in [vandana.title, vandana.titleRoman!]) {
        expect(
          find.descendant(of: card, matching: find.text(s)),
          findsOneWidget,
          reason: s,
        );
      }
      await t.tap(card);
      await t.pumpAndSettle();
      expect(_location(t), startsWith(Routes.reader(spVandanaId)));
    });

    testWidgets('the Introduction shows "Introduction" and its heading', (
      t,
    ) async {
      final lib = await realLibrary(t);
      final intro = lib.reading(spIntroductionId)!;
      await openReal(
        t,
        Routes.home,
        size: const Size(390, 3000),
        storeExtras: {
          positionKey: jsonEncode(
            PositionState(
              byReading: {
                spIntroductionId: ReadingProgress(
                  position: ReadingPosition(
                    readingId: spIntroductionId,
                    sectionId: intro.sections.single.id,
                    fraction: 0.3,
                  ),
                  progress: 0.3,
                ),
              },
              lastReadingId: spIntroductionId,
            ).toJson(),
          ),
        },
      );
      final card = find.byType(ContinueCard);
      expect(card, findsOneWidget);
      expect(intro.title, 'Introduction');
      expect(intro.sections.single.heading, 'Introduction');
      // The title, then the heading.
      expect(
        find.descendant(of: card, matching: find.text('Introduction')),
        findsNWidgets(2),
      );
    });
  });

  testWidgets('a Library address for the topic opens it with both rows', (
    t,
  ) async {
    await openReal(
      t,
      Routes.category(samanthaCategoryId),
      size: const Size(390, 3000),
    );
    await t.pumpAndSettle();
    expect(_location(t), Routes.library);
    final open = find.byKey(const ValueKey('open-$samanthaCategoryId'));
    expect(open, findsOneWidget);
    for (final id in [spIntroductionId, spVandanaId]) {
      expect(
        find.descendant(
          of: open,
          matching: find.byKey(ValueKey('reading-row-$id')),
        ),
        findsOneWidget,
      );
    }
  });
}
