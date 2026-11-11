import 'dart:convert';

import 'package:buddhist_gatha/home/card_art.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../support/passages.dart';

const _credit = 'Chanted by Ven. Kiriwaththuduwe Ariyadassana Thero';

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

String _location(WidgetTester t) =>
    _container(t)
        .read(routerProvider)
        .routeInformationProvider
        .value
        .uri
        .toString();

ScrollController _scroll(WidgetTester t) =>
    t.state<ReaderBodyState>(find.byType(ReaderBody)).controller;

AppSettings _only(List<ReadingLanguage> languages) =>
    AppSettings(languages: LanguageSelection(languages));

const _pali = ReadingLanguage.pali;
const _sinhala = ReadingLanguage.sinhala;
const _english = ReadingLanguage.english;

Future<void> _lets(WidgetTester t, Duration time, {int stepMs = 50}) async {
  for (var passed = 0; passed < time.inMilliseconds; passed += stepMs) {
    await t.pump(Duration(milliseconds: stepMs));
  }
}

void main() {
  setUpAll(loadBundledFonts);

  group('the Introduction', () {
    testWidgets('under Pali only shows its three paragraphs, no note and the '
        'plain bar, and Next goes to the Vandana', (t) async {
      await openReal(
        t,
        Routes.reader(spIntroductionId),
        settings: _only([_pali]),
      );
      final intro = (await realLibrary(t)).reading(spIntroductionId)!;
      final verses = intro.sections.single.verses;
      expect(verses.map((v) => v.id), ['intro-1', 'intro-2', 'intro-3']);
      for (final v in verses) {
        expect(find.byKey(ValueKey('verse-${v.id}-si')), findsOneWidget);
        expect(find.text(v.sinhala!), findsOneWidget);
      }
      expect(find.textContaining('not yet available'), findsNothing);
      expect(find.byTooltip('Bookmark this section'), findsNothing);
      expect(find.byKey(const ValueKey('chant-play')), findsNothing);
      expect(find.byTooltip('Previous reading'), findsOneWidget);

      await t.tap(find.byTooltip('Next reading'));
      await t.pumpAndSettle();
      expect(_location(t), startsWith(Routes.reader(spVandanaId)));
    });
  });

  group('the Vandana', () {
    testWidgets('shows its title, Roman name and credit, with the chanting '
        'bar, and Previous goes to the Introduction', (t) async {
      await openReal(t, Routes.reader(spVandanaId));
      final reading = (await realLibrary(t)).reading(spVandanaId)!;
      expect(
        find.descendant(
          of: find.byKey(ValueKey('heading-${reading.sections[0].id}')),
          matching: find.text(reading.title),
        ),
        findsOneWidget,
      );
      expect(find.text(reading.titleRoman!), findsOneWidget);
      expect(find.text(_credit), findsOneWidget);
      expect(find.byTooltip('Bookmark this section'), findsNothing);
      expect(find.byKey(const ValueKey('chant-play')), findsOneWidget);
      expect(find.byTooltip('Next reading'), findsOneWidget);

      await t.tap(find.byTooltip('Previous reading'));
      await t.pumpAndSettle();
      expect(_location(t), startsWith(Routes.reader(spIntroductionId)));
    });

    Future<void> toPart1(WidgetTester t) async {
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('block-u-part-1')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pump();
    }

    testWidgets('with Pali only there is no meaning', (t) async {
      await openReal(t, Routes.reader(spVandanaId), settings: _only([_pali]));
      await toPart1(t);
      expect(passage('u-part-1', 'pali'), findsOneWidget);
      expect(passage('u-part-1', 'sinhala'), findsNothing);
    });

    testWidgets('with Pali and Sinhala the meaning is under the lines, in '
        'the same block', (t) async {
      await openReal(
        t,
        Routes.reader(spVandanaId),
        settings: _only([_pali, _sinhala]),
      );
      await toPart1(t);
      final pali = passage('u-part-1', 'pali');
      final meaning = passage('u-part-1', 'sinhala');
      expect(meaning, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('block-u-part-1')),
          matching: meaning,
        ),
        findsOneWidget,
      );
      expect(
        t.getRect(meaning).top,
        greaterThanOrEqualTo(t.getRect(pali).bottom),
      );
    });

    testWidgets('with English only nothing shows for a unit, as in a pirith '
        'without English', (t) async {
      await openReal(
        t,
        Routes.reader(spVandanaId),
        settings: _only([_english]),
      );
      expect(find.byKey(const ValueKey('block-u-homage')), findsOneWidget);
      expect(passage('u-homage', 'pali'), findsNothing);
      expect(passage('u-homage', 'english'), findsNothing);
      expect(passage('u-homage', 'sinhala'), findsNothing);
      expect(find.textContaining('not yet available'), findsNothing);
    });

    testWidgets('the opening verses never have a meaning', (t) async {
      await openReal(
        t,
        Routes.reader(spVandanaId),
        settings: _only([_pali, _sinhala]),
      );
      expect(passage('u-verses', 'pali'), findsOneWidget);
      expect(passage('u-verses', 'sinhala'), findsNothing);
    });

    testWidgets('a favourite survives a reopen', (t) async {
      await openReal(t, Routes.reader(spVandanaId));
      await t.tap(find.byTooltip('Add to favourites'));
      await t.pumpAndSettle();
      final saved = _container(t).read(savedProvider);
      expect(saved.isFavourite(spVandanaId), isTrue);
      final store = jsonEncode(saved.toJson());

      await t.pumpWidget(const SizedBox());
      await openReal(
        t,
        Routes.reader(spVandanaId),
        storeExtras: {savedKey: store},
      );
      expect(find.byTooltip('Remove from favourites'), findsOneWidget);
    });

    testWidgets('a place in the middle is where it was after reopening', (
      t,
    ) async {
      await openReal(t, Routes.reader(spVandanaId));
      final c = _scroll(t);
      c.jumpTo(c.position.maxScrollExtent / 2);
      await t.pump();
      await _lets(t, const Duration(milliseconds: 600));
      final place = _container(t).read(positionProvider);
      final saved = place.byReading[spVandanaId]!.position;
      expect(saved.verseId, isNotNull);
      final block = find.byKey(ValueKey('block-${saved.verseId}'));
      final before = t.getTopLeft(block).dy;
      final store = jsonEncode(place.toJson());

      await t.pumpWidget(const SizedBox());
      await openReal(
        t,
        Routes.reader(spVandanaId),
        storeExtras: {positionKey: store},
      );
      await t.pumpAndSettle();
      expect(block, findsOneWidget);
      expect(t.getTopLeft(block).dy, closeTo(before, 2));
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('Samantha Pattana and Pirith list their readings; Buddha '
      'Wandanawa does not', (t) async {
    final lib = await realLibrary(t);
    expect(listsReadings(lib.category(samanthaCategoryId)!), isTrue);
    expect(listsReadings(lib.category(pirithCategoryId)!), isTrue);
    expect(listsReadings(lib.category(realCategoryId)!), isFalse);
  });
}
