import 'dart:convert';

import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/home/continue_card.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

const _credit = 'Chanted by Ven. Nauyane Ariyadhamma Thero';

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

String _location(WidgetTester t) => _container(t)
    .read(routerProvider)
    .routeInformationProvider
    .value
    .uri
    .toString();

ScrollController _scroll(WidgetTester t) =>
    t.state<ReaderBodyState>(find.byType(ReaderBody)).controller;

final _prev = find.byKey(const ValueKey('reader-prev'));
final _next = find.byKey(const ValueKey('reader-next'));
final _play = find.byKey(const ValueKey('reader-play'));

bool _enabled(WidgetTester t, Finder f) =>
    t.widget<NamoIconButton>(f).onPressed != null;

Finder get _blocks => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey &&
      '${(w.key as ValueKey).value}'.startsWith('block-'),
);

Future<Category> _pirith(WidgetTester t) async =>
    (await realLibrary(t)).category(pirithCategoryId)!;

/// The reading with the fewest verses in [c].
Reading _shortest(Category c) => c.readings.reduce(
  (a, b) => a.sections[0].verses.length <= b.sections[0].verses.length ? a : b,
);

Reading _longest(Category c) => c.readings.reduce(
  (a, b) => a.sections[0].verses.length >= b.sections[0].verses.length ? a : b,
);

Future<void> _lets(WidgetTester t, Duration time, {int stepMs = 50}) async {
  for (var passed = 0; passed < time.inMilliseconds; passed += stepMs) {
    await t.pump(Duration(milliseconds: stepMs));
  }
}

void main() {
  setUpAll(loadBundledFonts);

  group('the header', () {
    testWidgets('shows the names and the credit, without a bookmark button', (
      t,
    ) async {
      await openReal(t, Routes.reader(mangalaReadingId));
      final reading = (await realLibrary(t)).reading(mangalaReadingId)!;
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
      expect(find.byTooltip('Remove bookmark'), findsNothing);
      expect(find.textContaining('used with permission'), findsNothing);
    });

    testWidgets('the favourite button works', (t) async {
      await openReal(t, Routes.reader(mangalaReadingId));
      await t.tap(find.byTooltip('Add to favourites'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Remove from favourites'), findsOneWidget);
      expect(
        _container(t).read(savedProvider).isFavourite(mangalaReadingId),
        isTrue,
      );
    });

    testWidgets('the settings sheet has no layout choice in a pirith but '
        'does in Buddha Wandanawa', (t) async {
      await openReal(t, Routes.reader(mangalaReadingId));
      await t.tap(find.byKey(const ValueKey('reader-settings')));
      await t.pumpAndSettle();
      expect(find.text('Languages'), findsOneWidget);
      expect(find.text('When two languages show'), findsNothing);

      await t.pumpWidget(const SizedBox());
      await openReal(t, Routes.reader(realReadingId));
      await t.tap(find.byKey(const ValueKey('reader-settings')));
      await t.pumpAndSettle();
      expect(find.text('When two languages show'), findsOneWidget);
    });
  });

  group('the place', () {
    testWidgets('a block in the middle is where it was after reopening', (
      t,
    ) async {
      await openReal(t, Routes.reader(mangalaReadingId));
      final c = _scroll(t);
      c.jumpTo(c.position.maxScrollExtent / 2);
      await t.pump();
      await _lets(t, const Duration(milliseconds: 600));
      final place = _container(t).read(positionProvider);
      final saved = place.byReading[mangalaReadingId]!.position;
      expect(saved.verseId, isNotNull);
      final block = find.byKey(ValueKey('block-${saved.verseId}'));
      final before = t.getTopLeft(block).dy;
      final store = jsonEncode(place.toJson());

      await t.pumpWidget(const SizedBox());
      await openReal(
        t,
        Routes.reader(mangalaReadingId),
        storeExtras: {positionKey: store},
      );
      await t.pumpAndSettle();
      expect(block, findsOneWidget);
      expect(t.getTopLeft(block).dy, closeTo(before, 2));
      expect(t.takeException(), isNull);
    });

    testWidgets('Continue reading on Home opens the pirith at that place', (
      t,
    ) async {
      await openReal(t, Routes.reader(mangalaReadingId));
      final c = _scroll(t);
      c.jumpTo(c.position.maxScrollExtent / 2);
      await t.pump();
      await _lets(t, const Duration(milliseconds: 600));
      final place = _container(t).read(positionProvider);
      final verseId = place.byReading[mangalaReadingId]!.position.verseId;
      final before = t.getTopLeft(find.byKey(ValueKey('block-$verseId'))).dy;
      final store = jsonEncode(place.toJson());

      await t.pumpWidget(const SizedBox());
      await openReal(t, Routes.home, storeExtras: {positionKey: store});
      await t.tap(find.byType(ContinueCard));
      await t.pumpAndSettle();
      expect(_location(t), startsWith('/read/$mangalaReadingId'));
      final block = find.byKey(ValueKey('block-$verseId'));
      expect(block, findsOneWidget);
      expect(t.getTopLeft(block).dy, closeTo(before, 2));
    });
  });

  group('previous and next pirith', () {
    testWidgets('next goes to the next one at its beginning, and Back after '
        'two goes to the Library', (t) async {
      final readings = (await _pirith(t)).readings;
      await openReal(t, Routes.reader(readings[0].id));
      expect(readings[0].id, mangalaReadingId);
      expect(find.byTooltip('Previous pirith'), findsOneWidget);
      expect(find.byTooltip('Next pirith'), findsOneWidget);
      expect(_enabled(t, _prev), isFalse);
      expect(_enabled(t, _next), isTrue);

      await t.tap(_next);
      await t.pumpAndSettle();
      expect(_location(t), startsWith(Routes.reader(readings[1].id)));
      expect(
        find.byKey(ValueKey('heading-${readings[1].sections[0].id}')),
        findsOneWidget,
      );
      expect(_scroll(t).offset, 0);
      expect(_enabled(t, _prev), isTrue);

      await t.tap(_next);
      await t.pumpAndSettle();
      expect(_location(t), startsWith(Routes.reader(readings[2].id)));

      await t.tap(find.byTooltip('Previous pirith'));
      await t.pumpAndSettle();
      expect(_location(t), startsWith(Routes.reader(readings[1].id)));

      await t.tap(_next);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(_location(t), startsWith(Routes.library));
      expect(find.byKey(const ValueKey('reader-settings')), findsNothing);
    });

    testWidgets('next is disabled on the last pirith', (t) async {
      final last = (await _pirith(t)).readings.last;
      await openReal(t, Routes.reader(last.id));
      expect(_enabled(t, _next), isFalse);
      expect(_enabled(t, _prev), isTrue);
    });

    testWidgets('the place of the pirith left is kept', (t) async {
      final readings = (await _pirith(t)).readings;
      await openReal(t, Routes.reader(readings[0].id));
      final c = _scroll(t);
      c.jumpTo(c.position.maxScrollExtent / 2);
      await t.pump();
      // The block at the top of the page, worked out from what is built.
      final bodyTop = t.getTopLeft(find.byType(ReaderBody)).dy;
      String? atTop;
      for (final v in readings[0].sections[0].verses) {
        final f = find.byKey(ValueKey('block-${v.id}'));
        if (f.evaluate().isNotEmpty && t.getTopLeft(f).dy <= bodyTop + 0.5) {
          atTop = v.id;
        }
      }
      expect(atTop, isNotNull);
      await t.tap(_next);
      await t.pumpAndSettle();
      final kept = _container(
        t,
      ).read(positionProvider).byReading[readings[0].id]!.position;
      expect(kept.verseId, atTop);
      expect(kept.fraction, inInclusiveRange(0.0, 1.0));
    });

    testWidgets('next always opens at the beginning, the Library at the '
        'remembered place', (t) async {
      final readings = (await _pirith(t)).readings;
      final target = readings[1];
      final verses = target.sections[0].verses;
      final verse = verses[verses.length ~/ 2];
      final store = jsonEncode(
        PositionState(
          byReading: {
            target.id: ReadingProgress(
              position: ReadingPosition(
                readingId: target.id,
                sectionId: target.sections[0].id,
                verseId: verse.id,
                fraction: 0.3,
              ),
              progress: 0.5,
            ),
          },
          lastReadingId: target.id,
        ).toJson(),
      );
      await openReal(
        t,
        Routes.reader(readings[0].id),
        storeExtras: {positionKey: store},
      );
      await t.tap(_next);
      await t.pumpAndSettle();
      expect(_location(t), startsWith(Routes.reader(target.id)));
      expect(_scroll(t).offset, 0);

      // From the Library (a plain reader address) the remembered place shows.
      _container(t).read(routerProvider).go(Routes.reader(target.id));
      await t.pumpAndSettle();
      expect(_scroll(t).offset, greaterThan(0));
      final block = find.byKey(ValueKey('block-${verse.id}'));
      expect(block, findsOneWidget);
      final bodyTop = t.getTopLeft(find.byType(ReaderBody)).dy;
      expect(t.getTopLeft(block).dy - bodyTop, lessThan(60));
    });

    testWidgets('Buddha Wandanawa keeps Previous / Next section', (t) async {
      await openReal(t, Routes.reader(realReadingId));
      expect(find.byTooltip('Previous section'), findsOneWidget);
      expect(find.byTooltip('Next section'), findsOneWidget);
      expect(find.byTooltip('Next pirith'), findsNothing);
      final where = _location(t);
      await t.tap(_next);
      await t.pumpAndSettle();
      expect(_location(t), where);
      expect(_scroll(t).offset, greaterThan(0));
    });
  });

  group('auto-scroll, silent', () {
    testWidgets('starts, pauses on a touch and finishes at the end', (
      t,
    ) async {
      final short = _shortest(await _pirith(t));
      await openReal(
        t,
        Routes.reader(short.id),
        settings: const AppSettings(scrollSpeed: 60),
      );
      expect(t.widget<Tooltip>(_play).message, 'Start auto-scroll');
      await t.tap(_play);
      await t.pump();
      expect(t.widget<Tooltip>(_play).message, 'Pause auto-scroll');
      await _lets(t, const Duration(seconds: 1), stepMs: 16);
      expect(_scroll(t).offset, greaterThan(0));

      // A touch on the text pauses it at once.
      final touch = await t.startGesture(const Offset(200, 300));
      await t.pump();
      expect(t.widget<Tooltip>(_play).message, 'Resume auto-scroll');
      await touch.up();
      await t.pump();
      final paused = _scroll(t).offset;
      await _lets(t, const Duration(milliseconds: 500), stepMs: 16);
      expect(_scroll(t).offset, paused);

      await t.tap(_play);
      await t.pump();
      for (var i = 0; i < 6000; i++) {
        await t.pump(const Duration(milliseconds: 100));
        if (t.widget<Tooltip>(_play).message == 'Start auto-scroll') break;
      }
      expect(t.widget<Tooltip>(_play).message, 'Start auto-scroll');
      expect(_scroll(t).offset, _scroll(t).position.maxScrollExtent);
      expect(t.takeException(), isNull);
    });
  });

  group('the longest pirith, on demand', () {
    const size = Size(320, 568);
    Future<Reading> longest(WidgetTester t) async =>
        _longest(await _pirith(t));

    testWidgets('a far place (0.7 through) is where it was after reopening', (
      t,
    ) async {
      final reading = await longest(t);
      await openReal(
        t,
        Routes.reader(reading.id),
        size: size,
        deviceTextScale: 2.0,
      );
      final c = _scroll(t);
      c.jumpTo(c.position.maxScrollExtent * 0.7);
      await t.pump();
      await _lets(t, const Duration(milliseconds: 700));
      final place = _container(t).read(positionProvider);
      final verseId = place.byReading[reading.id]!.position.verseId!;
      final block = find.byKey(ValueKey('block-$verseId'));
      final before = t.getTopLeft(block).dy;
      final store = jsonEncode(place.toJson());

      await t.pumpWidget(const SizedBox());
      await openReal(
        t,
        Routes.reader(reading.id),
        size: size,
        deviceTextScale: 2.0,
        storeExtras: {positionKey: store},
      );
      await t.pumpAndSettle();
      expect(block, findsOneWidget);
      expect(t.getTopLeft(block).dy, closeTo(before, 2));
    });

    testWidgets('a touch while the place is still being looked for ends it', (
      t,
    ) async {
      final reading = await longest(t);
      await openReal(
        t,
        Routes.reader(reading.id),
        size: size,
        deviceTextScale: 2.0,
      );
      final c = _scroll(t);
      c.jumpTo(c.position.maxScrollExtent * 0.7);
      await t.pump();
      await _lets(t, const Duration(milliseconds: 700));
      final place = _container(t).read(positionProvider);
      final store = jsonEncode(place.toJson());

      // Where a quiet reopening ends up.
      await t.pumpWidget(const SizedBox());
      await openReal(
        t,
        Routes.reader(reading.id),
        size: size,
        deviceTextScale: 2.0,
        storeExtras: {positionKey: store},
      );
      final settled = _scroll(t).offset;

      // The same, touched as soon as the first jump has happened.
      await t.pumpWidget(const SizedBox());
      await openReal(
        t,
        Routes.reader(reading.id),
        size: size,
        deviceTextScale: 2.0,
        storeExtras: {positionKey: store},
        settle: false,
      );
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 16));
        if (find.byType(ReaderBody).evaluate().isNotEmpty &&
            _scroll(t).offset > 0) {
          break;
        }
      }
      expect(_scroll(t).offset, greaterThan(0));
      final touch = await t.startGesture(const Offset(160, 300));
      final held = _scroll(t).offset;
      await touch.up();
      await t.pumpAndSettle();
      expect(_scroll(t).offset, closeTo(held, 0.5));
      expect(held, isNot(closeTo(settled, 2)));
    });

    Future<void> startAt(WidgetTester t, double fraction) async {
      final reading = await longest(t);
      await openReal(
        t,
        Routes.reader(reading.id),
        size: size,
        deviceTextScale: 2.0,
        settings: const AppSettings(scrollSpeed: 60),
      );
      final c = _scroll(t);
      c.jumpTo(c.position.maxScrollExtent * fraction);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(_play);
      await t.pump();
      expect(t.widget<Tooltip>(_play).message, 'Pause auto-scroll');
    }

    bool finished(WidgetTester t) =>
        t.widget<Tooltip>(_play).message == 'Start auto-scroll';

    Future<void> expectFinishedAtEnd(WidgetTester t) async {
      final reading = await longest(t);
      final last = reading.sections[0].verses.last;
      expect(find.byKey(ValueKey('block-${last.id}')), findsOneWidget);
      expect(_scroll(t).offset, _scroll(t).position.maxScrollExtent);
    }

    testWidgets('started near the end it finishes with the last block built', (
      t,
    ) async {
      await startAt(t, 0.97);
      for (var i = 0; i < 20000 && !finished(t); i++) {
        await t.pump(const Duration(milliseconds: 100));
        if (finished(t)) await expectFinishedAtEnd(t);
      }
      expect(finished(t), isTrue);
      await expectFinishedAtEnd(t);
      expect(t.takeException(), isNull);
    });

    testWidgets('started mid-way it does not finish early and a touch '
        'pauses it', (t) async {
      await startAt(t, 0.5);
      final from = _scroll(t).offset;
      for (var i = 0; i < 300; i++) {
        await t.pump(const Duration(milliseconds: 100));
        expect(finished(t), isFalse);
      }
      expect(_scroll(t).offset, greaterThan(from));
      final touch = await t.startGesture(const Offset(160, 300));
      await t.pump();
      expect(t.widget<Tooltip>(_play).message, 'Resume auto-scroll');
      await touch.up();
      await t.pump();
      final paused = _scroll(t).offset;
      await _lets(t, const Duration(milliseconds: 500), stepMs: 16);
      expect(_scroll(t).offset, paused);
    });

    testWidgets('started at 0.9 it runs on to the real end', (t) async {
      await startAt(t, 0.9);
      for (var i = 0; i < 30000 && !finished(t); i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(finished(t), isTrue);
      await expectFinishedAtEnd(t);
    });
  });

  group('the longest pirith', () {
    testWidgets('opens at 320 x 568, text scale 2.0, built on demand', (
      t,
    ) async {
      final longest = _longest(await _pirith(t));
      expect(longest.id, 'pirith-24-mahasamaya-suttam');
      expect(longest.sections[0].verses.length, 178);
      await openReal(
        t,
        Routes.reader(longest.id),
        size: const Size(320, 568),
        deviceTextScale: 2.0,
      );
      expect(t.takeException(), isNull);
      expect(_blocks.evaluate().length, lessThan(20));
      final c = _scroll(t);
      for (final f in [0.3, 0.7, 1.0]) {
        c.jumpTo(c.position.maxScrollExtent * f);
        await t.pump();
        expect(t.takeException(), isNull);
        expect(_blocks.evaluate().length, lessThan(20));
      }
    });
  });
}
