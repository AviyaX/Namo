import 'dart:convert';

import 'package:buddhist_gatha/audio/audio_controls.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/home/continue_card.dart';
import 'package:buddhist_gatha/home/featured_card.dart';
import 'package:buddhist_gatha/library/search.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
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

Phrase _p(String s) => Phrase(pali: s, sinhala: s, english: s);

/// Latin placeholder pirith: three of them share the word "zebra".
Library _synthetic() => Library(
  categories: [
    Category(
      id: 'cat-x',
      title: 'Topic',
      subtitle: 'Sub',
      readings: [
        for (final (i, words) in [
          'alpha zebra one',
          'beta zebra two',
          'gamma three',
          'delta zebra four',
        ].indexed)
          Reading(
            id: 'p$i',
            title: 'Title $i',
            titleRoman: 'Roman $i',
            sections: [
              Section(
                id: 'p$i-s1',
                number: 1,
                heading: 'Title $i',
                verses: [
                  Verse(id: 'p$i-v1', phrases: [_p('first $i'), _p(words)]),
                ],
              ),
            ],
          ),
      ],
    ),
  ],
);

void main() {
  setUpAll(loadBundledFonts);

  group('Library, real content', () {
    for (final width in [390.0, 1280.0]) {
      for (final dark in [false, true]) {
        testWidgets('Pirith opens to 39 rows at $width dark=$dark', (t) async {
          await openReal(
            t,
            Routes.category(pirithCategoryId),
            size: Size(width, 8000),
            dark: dark,
          );
          await t.pumpAndSettle();
          final lib = await realLibrary(t);
          final cat = lib.category(pirithCategoryId)!;
          expect(cat.readings, hasLength(39));
          final rows = find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('pirith-row-'),
          );
          expect(rows, findsNWidgets(39));
          final keys = [
            for (final e in rows.evaluate())
              (e.widget.key! as ValueKey<String>).value,
          ];
          expect(keys, [for (final r in cat.readings) 'pirith-row-${r.id}']);
          for (final (i, r) in cat.readings.indexed) {
            final row = find.byKey(ValueKey('pirith-row-${r.id}'));
            expect(
              find.descendant(of: row, matching: find.text(r.title)),
              findsOneWidget,
            );
            expect(
              find.descendant(of: row, matching: find.text(r.titleRoman!)),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: row,
                matching: find.text(formatTime(r.audio?.duration)),
              ),
              findsOneWidget,
            );
            expect(
              find.descendant(of: row, matching: find.text('${i + 1}')),
              findsOneWidget,
            );
          }
          // No reading-title header apart from the rows themselves.
          expect(find.text(cat.readings.first.title), findsOneWidget);
          // The Roman names are drawn in the serif family.
          final roman = t.widget<Text>(
            find.descendant(
              of: find.byKey(ValueKey('pirith-row-${cat.readings.first.id}')),
              matching: find.text(cat.readings.first.titleRoman!),
            ),
          );
          expect(roman.style!.fontFamily, contains('NotoSerif'));
        });
      }
    }

    testWidgets('the first row is Maha Mangala and opens its reader', (t) async {
      await openReal(
        t,
        Routes.category(pirithCategoryId),
        size: const Size(390, 8000),
      );
      await t.pumpAndSettle();
      final lib = await realLibrary(t);
      expect(lib.category(pirithCategoryId)!.readings.first.id, mangalaReadingId);
      await t.tap(find.byKey(const ValueKey('pirith-row-$mangalaReadingId')));
      await t.pumpAndSettle();
      expect(_location(t), startsWith('/read/$mangalaReadingId'));
    });

    testWidgets('the topic row says 39 pirith; Buddha Wandanawa still opens', (
      t,
    ) async {
      await openReal(t, Routes.library, size: const Size(390, 3000));
      await t.pumpAndSettle();
      expect(find.text('39 pirith'), findsOneWidget);
      final lib = await realLibrary(t);
      final buddha = lib.category(realCategoryId)!;
      await t.tap(find.text(buddha.title).last);
      await t.pumpAndSettle();
      expect(
        find.text(buddha.readings.first.sections.first.heading),
        findsWidgets,
      );
      expect(find.byKey(const ValueKey('pirith-row-$mangalaReadingId')), findsNothing);
    });
  });

  group('Search', () {
    const sinhalaOnly = LanguageSelection([ReadingLanguage.sinhala]);
    const english = LanguageSelection([ReadingLanguage.english]);

    testWidgets('mangala and the Sinhala name find Maha Mangala once', (t) async {
      final lib = await realLibrary(t);
      final r = lib.reading(mangalaReadingId)!;
      final index = SearchIndex(lib);
      for (final q in ['mangala', r.title]) {
        final hits = index.search(q, sinhalaOnly);
        expect(
          hits.where((h) => h.reading.id == mangalaReadingId),
          hasLength(1),
          reason: q,
        );
      }
    });

    testWidgets('a word from the middle of a phrase finds it once, with the line', (
      t,
    ) async {
      final lib = await realLibrary(t);
      final r = lib.reading(mangalaReadingId)!;
      final phrases = [
        for (final s in r.sections)
          for (final v in s.verses) ...v.phrases,
      ];
      final phrase = phrases.firstWhere(
        (p) => p.english.split(' ').length >= 4,
      );
      final words = phrase.english.split(' ');
      final word = words[words.length ~/ 2].replaceAll(RegExp('[^A-Za-z]'), '');
      expect(word.length, greaterThanOrEqualTo(3));
      final hits = SearchIndex(lib).search(word, english);
      final mine = hits.where((h) => h.reading.id == mangalaReadingId).toList();
      expect(mine, hasLength(1));
      final expected = phrases.firstWhere(
        (p) => foldForSearch(p.english).contains(foldForSearch(word)),
      );
      expect(mine.single.line, expected.english.trim());
      expect(mine.single.lineLanguage, ReadingLanguage.english);
    });

    test('a query in phrases of 3 pirith returns 3 hits', () {
      final hits = SearchIndex(_synthetic()).search('zebra', english);
      expect(hits.map((h) => h.reading.id), ['p0', 'p1', 'p3']);
      expect(hits.map((h) => h.line), [
        'alpha zebra one',
        'beta zebra two',
        'delta zebra four',
      ]);
    });

    testWidgets('Buddha Wandanawa queries return what they did', (t) async {
      final lib = await buddhaOnlyLibrary(t);
      final full = await realLibrary(t);
      final heading = lib.categories.single.readings.first.sections.first.heading;
      final q = heading.split(' ').first;
      List<String> ids(List<SearchHit> h) => [
        for (final x in h) '${x.reading.id}/${x.section.id}/${x.line}',
      ];
      final before = ids(searchLibrary(lib, q, english));
      final after = ids(
        SearchIndex(full)
            .search(q, english)
            .where((h) => h.category.id == realCategoryId)
            .toList(),
      );
      expect(after, before);
      expect(before, isNotEmpty);
    });

    testWidgets('the index is built once across 20 searches', (t) async {
      SearchIndex.builds = 0;
      await openReal(t, Routes.library, size: const Size(390, 3000));
      await t.pumpAndSettle();
      for (var i = 0; i < 20; i++) {
        await t.enterText(
          find.byKey(const ValueKey('library-search')),
          i.isEven ? 'mangala' : 'sutta',
        );
        await t.pump();
      }
      expect(SearchIndex.builds, 1);
      expect(find.byKey(const ValueKey('library-results')), findsOneWidget);
    });

    testWidgets('a pirith hit is one row and opens the reader', (t) async {
      await openReal(t, Routes.library, size: const Size(390, 3000));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('library-search')), 'mangala');
      await t.pumpAndSettle();
      final lib = await realLibrary(t);
      final r = lib.reading(mangalaReadingId)!;
      expect(find.text(r.title), findsOneWidget);
      await t.tap(find.text(r.title));
      await t.pumpAndSettle();
      expect(_location(t), startsWith('/read/$mangalaReadingId'));
    });
  });

  group('Home', () {
    testWidgets('the Collections row has a Pirith card with 39 pirith', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.home, size: const Size(390, 3000));
      await t.pumpAndSettle();
      final card = find.byKey(const ValueKey('collection-cat-pirith'));
      expect(card, findsOneWidget);
      final pic = t.widget<Image>(
        find.descendant(of: card, matching: find.byType(Image)),
      );
      expect(
        ((pic.image as ResizeImage).imageProvider as AssetImage).assetName,
        'assets/pictures/pirith.jpg',
      );
      expect(
        find.descendant(of: card, matching: find.text('39 pirith')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('39 pirith')),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('Saved and Continue', () {
    testWidgets('a favourite pirith shows both names and opens its reader', (
      t,
    ) async {
      final lib = await realLibrary(t);
      final r = lib.reading(mangalaReadingId)!;
      await openReal(
        t,
        Routes.saved,
        storeExtras: {
          savedKey: jsonEncode(
            const SavedState(favourites: {mangalaReadingId}).toJson(),
          ),
        },
      );
      await t.pumpAndSettle();
      expect(find.text(r.title), findsOneWidget);
      expect(find.text(r.titleRoman!), findsOneWidget);
      await t.tap(find.text(r.title));
      await t.pumpAndSettle();
      expect(_location(t), startsWith('/read/$mangalaReadingId'));
    });

    testWidgets('a pirith read last: no Continue card; the featured page '
        'names it and opens the reader', (t) async {
      final lib = await realLibrary(t);
      final r = lib.reading(mangalaReadingId)!;
      await openReal(
        t,
        Routes.home,
        size: const Size(390, 3000),
        storeExtras: {
          positionKey: jsonEncode(
            PositionState(
              byReading: {
                mangalaReadingId: ReadingProgress(
                  position: ReadingPosition(
                    readingId: mangalaReadingId,
                    sectionId: r.sections.first.id,
                    fraction: 0.3,
                  ),
                  progress: 0.3,
                ),
              },
              lastReadingId: mangalaReadingId,
            ).toJson(),
          ),
        },
      );
      await t.pumpAndSettle();
      // Only a flow gets the Continue reading card; the carousel's Pirith
      // page names the pirith (in Sinhala letters) and continues it.
      expect(find.byType(ContinueCard), findsNothing);
      final card = find.byType(FeaturedCard);
      Finder inCard(Finder f) => find.descendant(of: card, matching: f);
      expect(inCard(find.text(r.title)), findsOneWidget);
      expect(
        t.widget<Text>(inCard(find.text(r.title))).style!.fontFamily,
        contains('NotoSansSinhala'),
      );
      await t.tap(inCard(find.text('Continue')));
      await t.pumpAndSettle();
      expect(_location(t), startsWith('/read/$mangalaReadingId'));
    });
  });
}
