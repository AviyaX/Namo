import 'dart:convert';

import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/home/continue_card.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
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
      expect(_location(t), Routes.reader(readings[1].id));
      expect(
        find.byKey(ValueKey('heading-${readings[1].sections[0].id}')),
        findsOneWidget,
      );
      expect(_scroll(t).offset, 0);
      expect(_enabled(t, _prev), isTrue);

      await t.tap(_next);
      await t.pumpAndSettle();
      expect(_location(t), Routes.reader(readings[2].id));

      await t.tap(find.byTooltip('Previous pirith'));
      await t.pumpAndSettle();
      expect(_location(t), Routes.reader(readings[1].id));

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
      await t.tap(_next);
      await t.pumpAndSettle();
      expect(
        _container(t).read(positionProvider).byReading[readings[0].id],
        isNotNull,
      );
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
