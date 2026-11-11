import 'package:buddhist_gatha/audio/chant_timing.dart' show ChantPlace;
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/reader/reader_items.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../support/passages.dart';

const _pali = ReadingLanguage.pali;
const _sinhala = ReadingLanguage.sinhala;
const _english = ReadingLanguage.english;

/// Placeholder phrases (Latin), long enough to wrap on a narrow screen.
Reading _reading({int blocks = 3}) => Reading(
  id: 'x',
  title: 'Title',
  sections: [
    Section(
      id: 'x-s',
      number: 1,
      heading: 'Title',
      verses: [
        for (var b = 0; b < blocks; b++)
          Verse(
            id: 'x-$b',
            phrases: [
              for (var i = 0; i < 3; i++)
                Phrase(
                  pali: 'pali $b.$i ${'lorem ipsum ' * 6}',
                  sinhala: 'sinhala $b.$i ${'dolor sit amet ' * 6}',
                  english: 'english $b.$i ${'consectetur ' * 6}',
                ),
            ],
          ),
      ],
    ),
  ],
);

Future<ScrollController> _pump(
  WidgetTester t,
  Reading reading,
  List<ReadingLanguage> languages, {
  required double width,
  required bool dark,
  required double scale,
  double height = 700,
  ValueNotifier<ChantPlace?>? place,
}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: namoTheme(dark ? Brightness.dark : Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: ReaderBody(
            items: buildReaderItems(
              reading,
              LanguageSelection(languages),
              TwoLanguageLayout.verse,
            ),
            controller: controller,
            fontScale: 1,
            lineSpacing: 1.6,
            chantPlace: place,
            bookmarkedSections: const {},
            onToggleBookmark: (_) {},
          ),
        ),
      ),
    ),
  );
  await t.pump();
  return controller;
}

Finder _text(String start) => find.textContaining(start);

void main() {
  setUpAll(loadBundledFonts);

  for (final width in [320.0, 390.0, 1280.0]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        final name = 'width $width dark=$dark scale $scale';

        testWidgets('Pali with Sinhala: meaning placed by width, $name', (
          t,
        ) async {
          await _pump(
            t,
            _reading(),
            [_pali, _sinhala],
            width: width,
            dark: dark,
            scale: scale,
          );
          final phrase = t.getRect(_text('pali 0.0'));
          final meaning = t.getRect(_text('sinhala 0.0'));
          if (width >= NamoSizes.wideBreakpoint) {
            expect(meaning.top, closeTo(phrase.top, 0.5), reason: name);
            expect(meaning.left, greaterThan(phrase.right - 0.5));
          } else {
            expect(
              meaning.top,
              greaterThanOrEqualTo(phrase.bottom),
              reason: name,
            );
            expect(meaning.top - phrase.bottom, lessThan(NamoSpace.sm + 1));
          }
          expect(t.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('one language shows only that text', (t) async {
    await _pump(t, _reading(), [_english], width: 390, dark: false, scale: 1);
    expect(_text('english 0.0'), findsOneWidget);
    expect(_text('pali 0.0'), findsNothing);
    expect(_text('sinhala 0.0'), findsNothing);
  });

  testWidgets('Sinhala with English shows no Pali', (t) async {
    await _pump(
      t,
      _reading(),
      [_sinhala, _english],
      width: 1280,
      dark: true,
      scale: 2,
    );
    expect(_text('sinhala 0.0'), findsOneWidget);
    expect(_text('english 0.0'), findsOneWidget);
    expect(_text('pali'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('gaps: sm between the passages, xl between blocks', (t) async {
    await _pump(
      t,
      _reading(),
      [_pali, _sinhala],
      width: 390,
      dark: false,
      scale: 1,
      height: 2400,
    );
    final first = t.getRect(_text('pali 0.0'));
    final meaning = t.getRect(_text('sinhala 0.0'));
    expect(meaning.top - first.bottom, NamoSpace.sm);
    final nextBlock = t.getRect(_text('pali 1.0'));
    expect(nextBlock.top - meaning.bottom, NamoSpace.xl);
  });

  testWidgets('the blocks and passages carry keys', (t) async {
    await _pump(t, _reading(), [_pali], width: 390, dark: false, scale: 1);
    expect(find.byKey(const ValueKey('block-x-0')), findsOneWidget);
    expect(passage('x-0', 'pali'), findsOneWidget);
  });

  testWidgets('a long reading is built on demand', (t) async {
    final c = await _pump(
      t,
      _reading(blocks: 150),
      [_pali, _sinhala],
      width: 320,
      dark: false,
      scale: 1,
      height: 568,
    );
    final built = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key as ValueKey).value}'.startsWith('block-'),
    );
    expect(built.evaluate().length, lessThan(15));
    c.jumpTo(c.position.maxScrollExtent / 2);
    await t.pump();
    expect(built.evaluate().length, lessThan(15));
    expect(t.takeException(), isNull);
  });

  String joined(int b, String Function(Phrase) of) =>
      _reading().sections.first.verses[b].phrases.map(of).join(' ');

  testWidgets('two languages give two passages of the phrases joined by '
      'single spaces', (t) async {
    await _pump(
      t,
      _reading(),
      [_pali, _sinhala],
      width: 390,
      dark: false,
      scale: 1,
    );
    final inBlock = find.descendant(
      of: find.byKey(const ValueKey('block-x-0')),
      matching: passages,
    );
    expect(inBlock, findsNWidgets(2));
    expect(passageText(t, passage('x-0', 'pali')), joined(0, (p) => p.pali));
    expect(
      passageText(t, passage('x-0', 'sinhala')),
      joined(0, (p) => p.sinhala),
    );
    expect(passage('x-0', 'english'), findsNothing);
    expect(markCount(t), 0, reason: 'no place, no marks');
  });

  testWidgets('one language gives one passage', (t) async {
    await _pump(t, _reading(), [_english], width: 390, dark: false, scale: 1);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('block-x-0')),
        matching: passages,
      ),
      findsOneWidget,
    );
  });

  testWidgets('the phrase being chanted is marked in every passage, and the '
      'mark moves with the place', (t) async {
    final place = ValueNotifier<ChantPlace?>(const ChantPlace(1, 1));
    addTearDown(place.dispose);
    await _pump(
      t,
      _reading(),
      [_pali, _sinhala],
      width: 390,
      dark: false,
      scale: 1,
      height: 2400,
      place: place,
    );
    expect(markedIn(t, passage('x-1', 'pali')), [1]);
    expect(markedIn(t, passage('x-1', 'sinhala')), [1]);
    expect(markCount(t), 2, reason: 'nothing marked in the other blocks');
    expect(find.byKey(const ValueKey('block-active')), findsOneWidget);
    for (final s in phraseSpans(t, passage('x-1', 'pali'))) {
      if (isMarked(s)) {
        expect(s.style!.fontWeight, isNull);
        expect(s.style!.fontSize, isNull);
      }
    }

    place.value = const ChantPlace(1, 2);
    await t.pump();
    expect(markedIn(t, passage('x-1', 'pali')), [2]);
    expect(markedIn(t, passage('x-1', 'sinhala')), [2]);

    place.value = const ChantPlace(2, 0);
    await t.pump();
    expect(markedIn(t, passage('x-1', 'pali')), isEmpty);
    expect(markedIn(t, passage('x-2', 'pali')), [0]);
    expect(markedIn(t, passage('x-2', 'sinhala')), [0]);

    place.value = null;
    await t.pump();
    expect(markCount(t), 0);
    expect(find.byKey(const ValueKey('block-active')), findsNothing);
  });

  testWidgets('a phrase empty in one language is skipped there and the mark '
      'still lines up by phrase', (t) async {
    final reading = _single(const [
      Phrase(pali: 'a one', sinhala: 's one', english: ''),
      Phrase(pali: 'a two', sinhala: '', english: ''),
      Phrase(pali: 'a three', sinhala: 's three', english: ''),
    ]);
    final place = ValueNotifier<ChantPlace?>(const ChantPlace(0, 2));
    addTearDown(place.dispose);
    await _pump(
      t,
      reading,
      [_pali, _sinhala],
      width: 390,
      dark: false,
      scale: 1,
      place: place,
    );
    expect(passageText(t, passage('y-0', 'pali')), 'a one a two a three');
    expect(passageText(t, passage('y-0', 'sinhala')), 's one s three');
    expect(markedIn(t, passage('y-0', 'pali')), [2]);
    // The second span of the Sinhala passage is phrase 2.
    expect(markedIn(t, passage('y-0', 'sinhala')), [1]);
    place.value = const ChantPlace(0, 1);
    await t.pump();
    expect(markedIn(t, passage('y-0', 'pali')), [1]);
    expect(markedIn(t, passage('y-0', 'sinhala')), isEmpty);
  });

  testWidgets('a language no phrase has text in gives no passage', (t) async {
    await _pump(
      t,
      _single(const [Phrase(pali: 'p', sinhala: '', english: '')]),
      [_pali, _sinhala],
      width: 390,
      dark: false,
      scale: 1,
    );
    expect(passage('y-0', 'pali'), findsOneWidget);
    expect(passage('y-0', 'sinhala'), findsNothing);
  });

  testWidgets('wide: the two passages sit side by side', (t) async {
    await _pump(
      t,
      _reading(),
      [_pali, _sinhala],
      width: 1280,
      dark: false,
      scale: 1,
    );
    final a = t.getRect(passage('x-0', 'pali'));
    final b = t.getRect(passage('x-0', 'sinhala'));
    expect(b.left, greaterThan(a.right - 0.5));
    expect(b.top, closeTo(a.top, 0.5));
  });

  testWidgets('offsetOfPhrase gives the top of the line a phrase starts on', (
    t,
  ) async {
    final c = await _pump(
      t,
      _reading(),
      [_pali],
      width: 320,
      dark: false,
      scale: 2,
      height: 2400,
    );
    final state = t.state<ReaderBodyState>(find.byType(ReaderBody));
    final top = t.getTopLeft(passage('x-1', 'pali')).dy + c.offset;
    expect(state.offsetOfPhrase(1, 0), closeTo(top, 0.5));
    final second = state.offsetOfPhrase(1, 1)!;
    final third = state.offsetOfPhrase(1, 2)!;
    expect(second, greaterThan(top));
    expect(third, greaterThan(second));
    expect(state.offsetOfPhrase(99, 0), isNull);
  });

  testWidgets('offsetOfPhrase falls back to the block top for a phrase with '
      'no text in the first passage', (t) async {
    final c = await _pump(
      t,
      _single(const [
        Phrase(pali: 'a one', sinhala: 's one', english: ''),
        Phrase(pali: '', sinhala: 's two', english: ''),
      ]),
      [_pali, _sinhala],
      width: 390,
      dark: false,
      scale: 1,
    );
    final state = t.state<ReaderBodyState>(find.byType(ReaderBody));
    final blockTop = t.getTopLeft(find.byKey(const ValueKey('block-y-0'))).dy;
    expect(state.offsetOfPhrase(0, 1), closeTo(blockTop + c.offset, 0.5));
  });
}

Reading _single(List<Phrase> phrases) => Reading(
  id: 'y',
  title: 'Title',
  sections: [
    Section(
      id: 'y-s',
      number: 1,
      heading: 'Title',
      verses: [Verse(id: 'y-0', phrases: phrases)],
    ),
  ],
);
