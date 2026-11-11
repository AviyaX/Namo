import 'dart:convert';
import 'dart:math' as math;

import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/design/widgets/floating_bar.dart';
import 'package:buddhist_gatha/design/widgets/progress_line.dart';
import 'package:buddhist_gatha/flows/flows.dart';
import 'package:buddhist_gatha/home/card_art.dart';
import 'package:buddhist_gatha/home/continue_card.dart';
import 'package:buddhist_gatha/home/featured_card.dart';
import 'package:buddhist_gatha/home/gatha_card.dart';
import 'package:buddhist_gatha/home/home_header.dart';
import 'package:buddhist_gatha/home/quick_access.dart';
import 'package:buddhist_gatha/home/today.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../support/test_content.dart';

// Every test starts the app with openReal (see app_shell_test.dart for why
// one way per file).

Section _section(String id, int number) => Section(
  id: id,
  number: number,
  heading: 'Heading $id',
  verses: [Verse(id: '$id-v1', paliSi: 'pali', sinhala: 'sinhala')],
);

/// One category with two readings (2 + 1 sections), Latin placeholder titles.
Library _twoReadings() => Library(
  categories: [
    Category(
      id: 'c1',
      title: 'Category one',
      subtitle: 'Subtitle one',
      readings: [
        Reading(
          id: 'ra',
          title: 'Alpha reading',
          sections: [_section('a01', 1), _section('a02', 2)],
        ),
        Reading(
          id: 'rb',
          title: 'Beta reading',
          sections: [_section('b01', 1)],
        ),
      ],
    ),
  ],
);

Library _oneSection() => Library(
  categories: [
    Category(
      id: 'c1',
      title: 'Category 1',
      subtitle: 'Subtitle 1',
      readings: [
        Reading(id: 'r1', title: 'Reading 1', sections: [_section('s1', 1)]),
      ],
    ),
  ],
);

/// A topic with no readings at all.
Library _empty() => const Library(
  categories: [
    Category(id: 'c0', title: 'Empty topic', subtitle: 'Nothing', readings: []),
  ],
);

/// One checked verse with Pali and Sinhala but no English.
Library _noEnglishGatha() => const Library(
  categories: [
    Category(
      id: 'c1',
      title: 'Category 1',
      subtitle: 'Subtitle 1',
      readings: [
        Reading(
          id: 'r1',
          title: 'Reading 1',
          sections: [
            Section(
              id: 's1',
              number: 1,
              heading: 'Heading 1',
              verses: [
                Verse(
                  id: 's1-v1',
                  paliSi: 'pali placeholder',
                  sinhala: 'sinhala placeholder',
                  check: CheckStatus.checkedAgainstSource,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

Override _clock(DateTime at) => clockProvider.overrideWithValue(() => at);

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(Scaffold).first));

String _location(WidgetTester t) =>
    _container(t).read(routerProvider).routeInformationProvider.value.uri
        .toString();

Future<void> _remember(
  WidgetTester t,
  String readingId,
  String sectionId,
  double progress,
) async {
  _container(t)
      .read(positionProvider.notifier)
      .save(
        ReadingPosition(
          readingId: readingId,
          sectionId: sectionId,
          fraction: 0,
        ),
        progress,
      );
  await t.pumpAndSettle();
}

Finder get _featuredButton => find.descendant(
  of: find.byType(FeaturedCard),
  matching: find.byType(PrimaryButton),
);

Future<void> _tapVisible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

/// [sections] as flow-1, "Flow one", in the stored flows.
Map<String, String> _flowOne(List<FlowRef> sections) => {
  flowsKey: jsonEncode(
    FlowsState(
      flows: [Flow(id: 'flow-1', name: 'Flow one', sections: sections)],
      nextNumber: 2,
    ).toJson(),
  ),
};

/// [testLibrary] with its topic under Buddha Wandanawa's id, so Home shows
/// Quick Access for it.
Library _testLibraryAsBuddha() {
  final c = testLibrary().categories.single;
  return Library(
    categories: [
      Category(
        id: quickAccessTopicId,
        title: c.title,
        subtitle: c.subtitle,
        readings: c.readings,
      ),
    ],
  );
}

/// Flow one over [testLibrary]: sections 3 and 2 of r1.
final _testFlow = _flowOne(const [
  FlowRef(readingId: 'r1', sectionId: 's03'),
  FlowRef(readingId: 'r1', sectionId: 's02'),
]);

const _quickAccess = ValueKey('home-quick-access');
const _collections = ValueKey('home-collections');
const _flowsRow = ValueKey('home-flows');

double _top(WidgetTester t, Finder f) => t.getTopLeft(f).dy;

void main() {
  setUpAll(loadBundledFonts);

  group('header', () {
    testWidgets('"Namo" and "Good morning" at 08:00', (t) async {
      await openReal(
        t,
        Routes.home,
        overrides: [_clock(DateTime(2026, 3, 4, 8))],
      );
      expect(find.byKey(const ValueKey('screen-home')), findsOneWidget);
      expect(find.text('Namo'), findsOneWidget);
      expect(find.text('Good morning'), findsOneWidget);
      // No settings button on Home.
      expect(find.byTooltip('Settings'), findsNothing);
    });

    testWidgets('the header heads the column, the picture behind it', (
      t,
    ) async {
      await openReal(t, Routes.home);
      final column = t.getRect(find.byKey(const ValueKey('home-column')));
      final header = t.getRect(find.byType(HomeHeader));
      expect(header.top, column.top);
      expect(header.width, column.width);
      final backdrop = t.getRect(find.byKey(const ValueKey('home-backdrop')));
      expect(backdrop.top, 0);
      expect(backdrop.bottom, greaterThan(header.top));
      expect(find.byKey(const ValueKey('home-search')), findsOneWidget);
    });

    testWidgets('"Good evening" at 21:00', (t) async {
      await openReal(
        t,
        Routes.home,
        overrides: [_clock(DateTime(2026, 3, 4, 21))],
      );
      expect(find.text('Good evening'), findsOneWidget);
    });

    testWidgets('the greeting refreshes when the app comes back', (t) async {
      var now = DateTime(2026, 3, 4, 8);
      await openReal(
        t,
        Routes.home,
        overrides: [clockProvider.overrideWithValue(() => now)],
      );
      expect(find.text('Good morning'), findsOneWidget);
      now = DateTime(2026, 3, 4, 21);
      await t.pump();
      expect(find.text('Good morning'), findsOneWidget);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(find.text('Good evening'), findsOneWidget);
      expect(find.text('Good morning'), findsNothing);
    });
  });

  group('continue reading and the featured button', () {
    testWidgets('fresh start: no Continue reading; "Begin" opens the reader '
        'for the first reading', (t) async {
      await openReal(t, Routes.home);
      final lib = await realLibrary(t);
      expect(find.text('Continue reading'), findsNothing);
      expect(find.byType(ContinueCard), findsNothing);
      expect(
        find.descendant(of: _featuredButton, matching: find.text('Begin')),
        findsOneWidget,
      );
      await _tapVisible(t, _featuredButton);
      expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
      expect(
        _location(t),
        Routes.reader(lib.categories.first.readings.first.id, from: ReaderFrom.home),
      );
    });

    testWidgets('tapping the featured card itself opens the reader too', (
      t,
    ) async {
      await openReal(t, Routes.home);
      final card = find.byType(FeaturedCard);
      // The top of the card, away from the button.
      await t.tapAt(t.getTopLeft(card) + const Offset(40, 40));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('screen-library')), findsNothing);
    });

    testWidgets('after reading a Library reading: no Continue reading card; '
        '"Continue" on the featured button reopens at that place', (t) async {
      await openReal(t, Routes.home, library: testLibrary());
      expect(find.text('category 1'), findsWidgets);

      await _remember(t, 'r1', 's02', 0.5);

      expect(find.byType(ContinueCard), findsNothing);
      expect(find.text('Continue reading'), findsNothing);
      expect(
        find.descendant(of: _featuredButton, matching: find.text('Continue')),
        findsOneWidget,
      );
      await _tapVisible(t, _featuredButton);
      expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('heading-s02')), findsOneWidget);
    });

    testWidgets('after reading a flow: the Continue reading card with its '
        'name, section, percent and line, between the featured card and the '
        'rest', (t) async {
      await openReal(
        t,
        Routes.home,
        library: _testLibraryAsBuddha(),
        storeExtras: _testFlow,
      );
      await _remember(t, 'flow-1', 'r1~s02', 0.5);
      final card = find.byType(ContinueCard);
      expect(card, findsOneWidget);
      expect(find.text('Continue reading'), findsOneWidget);
      for (final s in ['Flow one', 'heading 2', '50%']) {
        expect(find.descendant(of: card, matching: find.text(s)),
            findsOneWidget, reason: s);
      }
      final line = t.widget<ProgressLine>(
        find.descendant(of: card, matching: find.byType(ProgressLine)),
      );
      expect(line.value, 0.5);
      // Below the featured card, above Quick Access.
      expect(_top(t, card),
          greaterThan(t.getBottomLeft(find.byType(FeaturedCard)).dy));
      expect(_top(t, card), lessThan(_top(t, find.byKey(_quickAccess))));
    });

    testWidgets('the Continue reading card is one button with today\'s label', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await openReal(
        t,
        Routes.home,
        library: testLibrary(),
        storeExtras: _testFlow,
      );
      await _remember(t, 'flow-1', 'r1~s02', 0.5);
      final node = find.bySemanticsLabel(
        'Continue reading, Flow one, heading 2, 50 percent',
      );
      expect(node, findsOneWidget);
      expect(
        t.getSemantics(node).getSemanticsData().flagsCollection.isButton,
        isTrue,
      );
      expect(
        find.bySemanticsLabel(RegExp('^Continue reading, Flow one')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('Continue reading is absent when the reading is not in the '
        'content', (t) async {
      await openReal(t, Routes.home, library: testLibrary());
      await _remember(t, 'gone', 's01', 0.2);
      expect(find.text('Continue reading'), findsNothing);
      expect(
        find.descendant(of: _featuredButton, matching: find.text('Begin')),
        findsOneWidget,
      );
    });

    testWidgets('a flow last read: the card shows its name and the section, '
        'and opens the flow from Home', (t) async {
      await openReal(
        t,
        Routes.home,
        library: testLibrary(),
        storeExtras: _testFlow,
      );
      await _remember(t, 'flow-1', 'r1~s02', 0.5);
      final card = find.byType(ContinueCard);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Flow one')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('heading 2')),
        findsOneWidget,
      );
      await t.tap(card);
      await t.pumpAndSettle();
      expect(_location(t), '/read/flow-1?from=home');
      expect(find.byKey(const ValueKey('heading-r1~s02')), findsOneWidget);
    });

    for (final (what, sections) in [
      ('emptied', const <FlowRef>[]),
      ('left with no live sections', const [
        FlowRef(readingId: 'r1', sectionId: 'gone'),
      ]),
    ]) {
      testWidgets('a flow $what is not offered', (t) async {
        await openReal(
          t,
          Routes.home,
          library: testLibrary(),
          storeExtras: _flowOne(sections),
        );
        await _remember(t, 'flow-1', 'r1~s02', 0.5);
        expect(find.byType(ContinueCard), findsNothing);
        expect(find.text('Continue reading'), findsNothing);
      });
    }

    testWidgets('a deleted flow is not offered', (t) async {
      await openReal(t, Routes.home, library: testLibrary());
      await _remember(t, 'flow-1', 'r1~s02', 0.5);
      expect(find.byType(ContinueCard), findsNothing);
      expect(find.text('Continue reading'), findsNothing);
    });
  });

  group('featured card', () {
    testWidgets('bundled content: "FEATURED COLLECTION", the title, the '
        'subtitle and "19 sections"', (t) async {
      await openReal(t, Routes.home);
      final c = (await realLibrary(t)).categories.first;
      final card = find.byType(FeaturedCard);
      for (final s in ['FEATURED COLLECTION', 'Buddha Wandanawa', c.subtitle, '19 sections']) {
        expect(find.descendant(of: card, matching: find.text(s)), findsOneWidget,
            reason: s);
      }
      expect(c.title, 'Buddha Wandanawa');
    });

    testWidgets('a single section is written "1 section"', (t) async {
      await openReal(t, Routes.home, library: _oneSection());
      expect(
        find.descendant(
          of: find.byType(FeaturedCard),
          matching: find.text('1 section'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('every topic has the same overline, "FEATURED COLLECTION"', (
      t,
    ) async {
      await openReal(t, Routes.home, library: _oneSection());
      expect(
        find.descendant(
          of: find.byType(FeaturedCard),
          matching: find.text('FEATURED COLLECTION'),
        ),
        findsOneWidget,
      );
      expect(find.text('Buddha Vandana'), findsNothing);
    });

    testWidgets('a topic with two readings shows the summed count and goes to '
        'the Library with it open', (t) async {
      await openReal(t, Routes.home, library: _twoReadings());
      expect(
        find.descendant(
          of: find.byType(FeaturedCard),
          matching: find.text('3 sections'),
        ),
        findsOneWidget,
      );
      await _tapVisible(t, _featuredButton);
      expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
      expect(find.byKey(const ValueKey('open-c1')), findsOneWidget);
      expect(find.text('Alpha reading'), findsOneWidget);
      expect(find.text('Heading b01'), findsOneWidget);
    });

    testWidgets('a topic with no readings: "0 sections", no Quick Access, no '
        'button, and the card does nothing', (t) async {
      await openReal(t, Routes.home, library: _empty());
      expect(
        find.descendant(
          of: find.byType(FeaturedCard),
          matching: find.text('0 sections'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(_quickAccess, skipOffstage: false), findsNothing);
      expect(_featuredButton, findsNothing);
      await t.tap(find.byType(FeaturedCard), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('screen-home')), findsOneWidget);
      expect(find.byKey(const ValueKey('reader-settings')), findsNothing);
    });

    testWidgets('on a phone the card is the column width and as tall as its '
        'words, at least half its width', (t) async {
      await openReal(t, Routes.home, library: _oneSection());
      final size = t.getSize(find.byType(FeaturedCard));
      expect(size.width, 390 - 40);
      final words = t
          .renderObject<RenderPictureWords>(
            find.descendant(
              of: find.byType(FeaturedCard),
              matching: find.byType(PictureWords),
            ),
          )
          .child!
          .size
          .height;
      expect(size.height, math.max(words, 350 * 0.5));
    });

    testWidgets('at 1280 x 800 the featured card uses the hero picture, 3 : 1', (
      t,
    ) async {
      await openReal(t, Routes.home, size: const Size(1280, 800));
      final image = t.widget<Image>(
        find.descendant(
          of: find.byType(FeaturedCard),
          matching: find.byKey(const ValueKey('card-art-picture')),
        ),
      );
      final dark =
          Theme.of(t.element(find.byType(FeaturedCard))).brightness ==
          Brightness.dark;
      expect(
        ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
        dark ? 'assets/pictures/hero_dark.jpg' : 'assets/pictures/hero_light.jpg',
      );
      final size = t.getSize(find.byType(FeaturedCard));
      expect(size.width / size.height, closeTo(3, 0.01));
    });
  });

  group("today's gatha", () {
    final day = DateTime(2026, 3, 4, 8);

    testWidgets('shows the texts of the day\'s verse, string for string', (
      t,
    ) async {
      await openReal(t, Routes.home, overrides: [_clock(day)]);
      final lib = await realLibrary(t);
      final pick = gathaForDay(lib, day)!;
      final texts = gathaTexts(pick.verse, LanguageSelection.initial);
      final card = find.byType(GathaCard);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text("TODAY'S GATHA")),
        findsOneWidget,
      );
      for (final (i, (_, text)) in texts.indexed) {
        final shown = t.widget<Text>(
          find.descendant(of: card, matching: find.byKey(ValueKey('gatha-text-$i'))),
        );
        expect(shown.data, text);
      }
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(ValueKey('gatha-text-${texts.length}')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text(
            '${lib.categoryOf(pick.reading.id)!.title} · ${pick.section.heading}',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Read in context" opens the reader at that section', (t) async {
      await openReal(t, Routes.home, overrides: [_clock(day)]);
      final pick = gathaForDay(await realLibrary(t), day)!;
      await _tapVisible(t, find.text('Read in context'));
      expect(find.byKey(const ValueKey('reader-settings')), findsOneWidget);
      expect(
        _location(t),
        Routes.reader(
          pick.reading.id,
          sectionId: pick.section.id,
          from: ReaderFrom.home,
        ),
      );
      expect(find.byKey(ValueKey('heading-${pick.section.id}')), findsOneWidget);
    });

    testWidgets('English only, and a verse without English: the Pali is shown', (
      t,
    ) async {
      final lib = _noEnglishGatha();
      await openReal(
        t,
        Routes.home,
        library: lib,
        overrides: [_clock(day)],
        settings: const AppSettings(
          languages: LanguageSelection([ReadingLanguage.english]),
        ),
      );
      final verse = lib.categories.first.readings.first.sections.first.verses.first;
      final card = find.byType(GathaCard);
      expect(
        t.widget<Text>(
          find.descendant(of: card, matching: find.byKey(const ValueKey('gatha-text-0'))),
        ).data,
        verse.paliSi,
      );
      expect(
        find.descendant(of: card, matching: find.text(verse.sinhala!)),
        findsNothing,
      );
    });

    testWidgets('absent when no verse can be picked', (t) async {
      await openReal(t, Routes.home, library: testLibrary());
      expect(find.byType(GathaCard), findsNothing);
      expect(find.text("TODAY'S GATHA"), findsNothing);
    });
  });

  group('collections', () {
    testWidgets('one topic: Collections with its one card', (t) async {
      final lib = await buddhaOnlyLibrary(t);
      await openReal(t, Routes.home, library: lib);
      expect(find.text('Collections', skipOffstage: false), findsOneWidget);
      expect(
        find.byKey(ValueKey('collection-${lib.categories.single.id}'),
            skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('several topics: a card for every topic, the first included; '
        'a topic without a picture shows the lotus panel', (t) async {
      final lib = severalCategories();
      await openReal(t, Routes.home, library: lib);
      expect(find.text('Collections', skipOffstage: false), findsOneWidget);
      for (final c in lib.categories) {
        final card =
            find.byKey(ValueKey('collection-${c.id}'), skipOffstage: false);
        expect(card, findsOneWidget, reason: c.id);
        expect(
          find.descendant(
            of: card,
            matching: find.byKey(const ValueKey('card-art-panel')),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
              of: card, matching: find.byType(Image), skipOffstage: false),
          findsNothing,
        );
        expect(t.getSize(card).width, 220);
        expect(t.getSize(card).height, greaterThanOrEqualTo(148));
      }
    });

    testWidgets('bundled content: three cards, the third Samantha Pattana '
        'with its picture and "2 readings"', (t) async {
      final handle = t.ensureSemantics();
      final lib = await realLibrary(t);
      await openReal(t, Routes.home, size: const Size(390, 3000));
      expect(lib.categories, hasLength(3));
      expect(find.byType(FeaturedCard), findsOneWidget);
      for (final c in lib.categories) {
        expect(
          find.byKey(ValueKey('collection-${c.id}'), skipOffstage: false),
          findsOneWidget,
          reason: c.id,
        );
      }
      final card = find.byKey(
        const ValueKey('collection-cat-samantha-patthana'),
        skipOffstage: false,
      );
      final pic = t.widget<Image>(
        find.descendant(
          of: card,
          matching: find.byType(Image),
          skipOffstage: false,
        ),
      );
      expect(
        ((pic.image as ResizeImage).imageProvider as AssetImage).assetName,
        'assets/pictures/samantha_patthana.jpg',
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('2 readings'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      final sp = lib.category(samanthaCategoryId)!;
      expect(
        find.descendant(
          of: card,
          matching: find.bySemanticsLabel(
            '${sp.title}, ${sp.subtitle}, 2 readings',
            skipOffstage: false,
          ),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a collection card opens the Library with its topic open', (
      t,
    ) async {
      await openReal(t, Routes.home, library: severalCategories());
      await _tapVisible(t, find.byKey(const ValueKey('collection-c3')));
      expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
      expect(find.byKey(const ValueKey('open-c3')), findsOneWidget);
    });
  });

  group('wide', () {
    testWidgets('at 1280 x 800 a flow\'s Continue reading and Today\'s gatha '
        'share a row', (t) async {
      await openReal(
        t,
        Routes.home,
        size: const Size(1280, 800),
        overrides: [_clock(DateTime(2026, 3, 4, 8))],
        storeExtras: await realFlowsStore(t),
      );
      final first =
          (await realLibrary(t)).reading(realReadingId)!.sections.first;
      await _remember(t, 'flow-1', '$realReadingId~${first.id}', 0.25);
      final cont = find.byType(ContinueCard);
      final gatha = find.byType(GathaCard);
      expect(t.getTopLeft(cont).dy, t.getTopLeft(gatha).dy);
      expect(t.getTopLeft(gatha).dx - t.getTopRight(cont).dx, closeTo(24, 0.01));
      // Below the featured banner.
      expect(
        t.getTopLeft(cont).dy,
        greaterThan(t.getBottomLeft(find.byType(FeaturedCard)).dy),
      );
    });

    testWidgets('with no flow to continue the gatha takes the full width', (
      t,
    ) async {
      await openReal(
        t,
        Routes.home,
        size: const Size(1280, 800),
        overrides: [_clock(DateTime(2026, 3, 4, 8))],
      );
      final reading = (await realLibrary(t)).reading(realReadingId)!;
      await _remember(t, reading.id, reading.sections[3].id, 0.25);
      expect(find.byType(ContinueCard), findsNothing);
      expect(
        t.getSize(find.byType(GathaCard)).width,
        t.getSize(find.byType(FeaturedCard)).width,
      );
    });

    testWidgets('the column is 680 under 840 wide and 1040 from 840', (t) async {
      await openReal(t, Routes.home, size: const Size(1280, 800));
      expect(t.getSize(find.byKey(const ValueKey('home-column'))).width, 1040);
    });
  });

  group('your flows', () {
    final row = find.byKey(_flowsRow);

    testWidgets('phone: after Quick Access, before Collections', (t) async {
      await openReal(
        t,
        Routes.home,
        library: _testLibraryAsBuddha(),
        storeExtras: _testFlow,
        size: const Size(390, 3000),
      );
      expect(find.byType(ContinueCard), findsNothing);
      expect(_top(t, row), greaterThan(_top(t, find.byKey(_quickAccess))));
      expect(_top(t, row), lessThan(_top(t, find.byKey(_collections))));
    });

    testWidgets('wide: after the Continue reading and gatha row and Quick '
        'Access, before Collections', (t) async {
      await openReal(
        t,
        Routes.home,
        size: const Size(1280, 3000),
        overrides: [_clock(DateTime(2026, 3, 4, 8))],
        storeExtras: await realFlowsStore(t),
      );
      final first =
          (await realLibrary(t)).reading(realReadingId)!.sections.first;
      await _remember(t, 'flow-1', '$realReadingId~${first.id}', 0.25);
      expect(
        _top(t, row),
        greaterThan(t.getBottomLeft(find.byType(GathaCard)).dy),
      );
      expect(
        _top(t, row),
        greaterThan(t.getBottomLeft(find.byType(ContinueCard)).dy),
      );
      expect(
        _top(t, row),
        greaterThan(t.getBottomLeft(find.byKey(_quickAccess)).dy),
      );
      expect(_top(t, row), lessThan(_top(t, find.byKey(_collections))));
    });

    testWidgets('the row goes when the last flow is deleted', (t) async {
      await openReal(
        t,
        Routes.home,
        library: testLibrary(),
        storeExtras: _testFlow,
        size: const Size(390, 3000),
      );
      expect(row, findsOneWidget);
      final before = _top(t, find.byKey(_collections));
      _container(t).read(flowsProvider.notifier).delete('flow-1');
      await t.pumpAndSettle();
      expect(row, findsNothing);
      expect(find.text('Your flows'), findsNothing);
      expect(_top(t, find.byKey(_collections)), lessThan(before));
    });
  });

  group('order', () {
    /// Each of [blocks] is on Home once, each above the next.
    void expectOrder(WidgetTester t, List<Finder> blocks) {
      for (final b in blocks) {
        expect(b, findsOneWidget);
      }
      for (var i = 1; i < blocks.length; i++) {
        expect(
          _top(t, blocks[i - 1]),
          lessThan(_top(t, blocks[i])),
          reason: 'block $i',
        );
      }
    }

    testWidgets('phone: header, featured, Continue (a flow), gatha, Quick '
        'Access, flows, Collections', (t) async {
      await openReal(
        t,
        Routes.home,
        size: const Size(390, 4000),
        overrides: [_clock(DateTime(2026, 3, 4, 8))],
        storeExtras: await realFlowsStore(t),
      );
      final first =
          (await realLibrary(t)).reading(realReadingId)!.sections.first;
      await _remember(t, 'flow-1', '$realReadingId~${first.id}', 0.25);
      expectOrder(t, [
        find.byType(HomeHeader),
        find.byType(FeaturedCard),
        find.byType(ContinueCard),
        find.byType(GathaCard),
        find.byKey(_quickAccess),
        find.byKey(_flowsRow),
        find.byKey(_collections),
      ]);
    });

    testWidgets('wide: featured; Continue (a flow) beside the gatha; Quick '
        'Access; flows; Collections', (t) async {
      await openReal(
        t,
        Routes.home,
        size: const Size(1280, 3000),
        overrides: [_clock(DateTime(2026, 3, 4, 8))],
        storeExtras: await realFlowsStore(t),
      );
      final first =
          (await realLibrary(t)).reading(realReadingId)!.sections.first;
      await _remember(t, 'flow-1', '$realReadingId~${first.id}', 0.25);
      expect(
        _top(t, find.byType(ContinueCard)),
        _top(t, find.byType(GathaCard)),
      );
      expectOrder(t, [
        find.byType(HomeHeader),
        find.byType(FeaturedCard),
        find.byType(GathaCard),
        find.byKey(_quickAccess),
        find.byKey(_flowsRow),
        find.byKey(_collections),
      ]);
    });
  });

  testWidgets('the last block can be scrolled above the navigation bar at '
      '390 x 844', (t) async {
    await openReal(t, Routes.home, library: severalCategories());
    final position = t
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.maxScrollExtent);
    await t.pumpAndSettle();
    final barTop = t.getRect(find.byType(FloatingBar)).top;
    expect(
      t.getRect(find.byKey(const ValueKey('home-column'))).bottom,
      lessThanOrEqualTo(barTop),
    );
    expect(
      t.getRect(find.byKey(const ValueKey('collection-c4'), skipOffstage: false)).bottom,
      lessThanOrEqualTo(barTop),
    );
  });

  group('no overflow', () {
    final cases = <(Size, double)>[
      (const Size(320, 568), 2.0),
      for (final w in [360.0, 390.0, 840.0, 1280.0])
        for (final s in [1.0, 1.5]) (Size(w, 800), s),
    ];
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      for (final (size, scale) in cases) {
        testWidgets('${size.width.round()} x ${size.height.round()}, text '
            '$scale, ${theme.name}', (t) async {
          await openReal(
            t,
            Routes.home,
            size: size,
            deviceTextScale: scale,
            settings: AppSettings(themeMode: theme),
            overrides: [_clock(DateTime(2026, 3, 4, 8))],
            storeExtras: await realFlowsStore(t),
          );
          final first =
              (await realLibrary(t)).reading(realReadingId)!.sections.first;
          await _remember(t, 'flow-1', '$realReadingId~${first.id}', 0.25);
          expect(find.byType(ContinueCard), findsOneWidget);
          expect(find.byKey(_quickAccess), findsOneWidget);
          expect(find.byType(GathaCard), findsOneWidget);
          await scrollThrough(t);
          expect(t.takeException(), isNull);
        });
        testWidgets('several topics, ${size.width.round()} x '
            '${size.height.round()}, text $scale, ${theme.name}', (t) async {
          await openReal(
            t,
            Routes.home,
            size: size,
            deviceTextScale: scale,
            library: severalCategories(),
            settings: AppSettings(themeMode: theme),
          );
          await scrollThrough(t);
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
