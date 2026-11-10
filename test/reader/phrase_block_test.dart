import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/reader/reader_items.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

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
            expect(meaning.top - phrase.bottom, lessThan(NamoSpace.xs + 8));
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

  testWidgets('gaps: xs under the phrase, md between phrases, xl between '
      'blocks', (t) async {
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
    final next = t.getRect(_text('pali 0.1'));
    expect(meaning.top - first.bottom, NamoSpace.xs);
    expect(next.top - meaning.bottom, NamoSpace.md);
    final lastOfBlock = t.getRect(_text('sinhala 0.2'));
    final nextBlock = t.getRect(_text('pali 1.0'));
    expect(nextBlock.top - lastOfBlock.bottom, NamoSpace.xl);
  });

  testWidgets('the rows carry the block and phrase keys', (t) async {
    await _pump(t, _reading(), [_pali], width: 390, dark: false, scale: 1);
    expect(find.byKey(const ValueKey('block-x-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('phrase-x-0-2')), findsOneWidget);
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

  testWidgets('offsetOfPhrase gives each built phrase its top', (t) async {
    final c = await _pump(
      t,
      _reading(),
      [_pali],
      width: 390,
      dark: false,
      scale: 1,
      height: 2400,
    );
    final state = t.state<ReaderBodyState>(find.byType(ReaderBody));
    final top = t.getTopLeft(find.byKey(const ValueKey('phrase-x-1-2'))).dy;
    expect(state.offsetOfPhrase(1, 2), closeTo(top + c.offset, 0.5));
    expect(state.offsetOfPhrase(1, 1)!, lessThan(state.offsetOfPhrase(1, 2)!));
    expect(state.offsetOfPhrase(99, 0), isNull);
  });
}
