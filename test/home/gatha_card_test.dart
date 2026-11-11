import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/marks.dart';
import 'package:buddhist_gatha/design/typography.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/design/widgets/surface_card.dart';
import 'package:buddhist_gatha/home/gatha_card.dart';
import 'package:buddhist_gatha/home/today.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/widgets/widget_support.dart';
import '../quality/quality_support.dart';

/// Latin placeholder content: one checked verse in all three languages.
GathaPick _pick() {
  const verse = Verse(
    id: 's1-v1',
    paliSi: 'pali placeholder',
    sinhala: 'sinhala placeholder',
    english: 'english placeholder',
    check: CheckStatus.checkedAgainstSource,
  );
  const section = Section(id: 's1', number: 1, heading: 'Heading 1', verses: [verse]);
  const reading = Reading(id: 'r1', title: 'Reading 1', sections: [section]);
  return GathaPick(reading, section, verse);
}

Widget _card({
  required GathaPick pick,
  required LanguageSelection selection,
  double fontScale = 1.0,
  double lineSpacing = 1.6,
  String topicTitle = 'Topic 1',
}) =>
    ProviderScope(
      child: GathaCard(
        pick: pick,
        selection: selection,
        fontScale: fontScale,
        lineSpacing: lineSpacing,
        topicTitle: topicTitle,
      ),
    );

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('the verse is drawn at the reader text size and spacing', (t) async {
    final p = paletteOf(Brightness.dark);
    await pumpThemed(
      t,
      SizedBox(
        width: 350,
        child: _card(
          pick: _pick(),
          selection: const LanguageSelection([ReadingLanguage.english]),
          fontScale: 1.4,
          lineSpacing: 2.0,
        ),
      ),
    );
    expect(
      t.widget<Text>(find.byKey(const ValueKey('gatha-text-0'))).style,
      readingStyle(ReadingLanguage.english,
          fontScale: 1.4, lineSpacing: 2.0, color: p.text),
    );
  });

  for (final b in Brightness.values) {
    testWidgets('a gold leading line, the overline, the texts in reading style '
        '12 apart, the caption and "Read in context" ($b)', (t) async {
      final p = paletteOf(b);
      const selection = LanguageSelection([ReadingLanguage.sinhala, ReadingLanguage.english]);
      await pumpThemed(
        t,
        SizedBox(width: 350, child: _card(pick: _pick(), selection: selection)),
        brightness: b,
      );
      final card = t.widget<SurfaceCard>(find.byType(SurfaceCard));
      expect(card.framed, isTrue);
      expect(card.onTap, isNull);
      expect(find.text("TODAY'S GATHA"), findsOneWidget);

      final first = t.widget<Text>(find.byKey(const ValueKey('gatha-text-0')));
      final second = t.widget<Text>(find.byKey(const ValueKey('gatha-text-1')));
      expect(first.data, 'sinhala placeholder');
      expect(second.data, 'english placeholder');
      expect(
        first.style,
        readingStyle(ReadingLanguage.sinhala, fontScale: 1.0, lineSpacing: 1.6, color: p.text),
      );
      expect(
        second.style,
        readingStyle(ReadingLanguage.english,
            fontScale: 1.0, lineSpacing: 1.6, color: p.textSecondary),
      );
      expect(
        t.getTopLeft(find.byKey(const ValueKey('gatha-text-1'))).dy -
            t.getBottomLeft(find.byKey(const ValueKey('gatha-text-0'))).dy,
        12,
      );
      final heading = t.widget<Text>(find.text('Topic 1 · Heading 1'));
      expect(heading.style, NamoType.caption(p.textSecondary));
      expect(find.bySemanticsLabel('Read in context'), findsOneWidget);
      // The heading comes after the texts, the action last.
      expect(
        t.getTopLeft(find.text('Topic 1 · Heading 1')).dy,
        greaterThan(t.getBottomLeft(find.byKey(const ValueKey('gatha-text-1'))).dy),
      );
      expect(
        t.getTopLeft(find.text('Read in context')).dy,
        greaterThan(t.getBottomLeft(find.text('Topic 1 · Heading 1')).dy),
      );
    });
  }

  testWidgets('fits 320 wide at 2x text', (t) async {
    await pumpThemed(
      t,
      SizedBox(
        width: 288,
        child: _card(pick: _pick(), selection: LanguageSelection.initial),
      ),
      size: const Size(320, 800),
      textScale: 2,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('the caption is only the heading when there is no topic', (t) async {
    await pumpThemed(
      t,
      SizedBox(
        width: 350,
        child: _card(pick: _pick(), selection: LanguageSelection.initial, topicTitle: ''),
      ),
    );
    expect(find.text('Heading 1'), findsOneWidget);
  });

  testWidgets('the bookmark button toggles the section in savedProvider', (t) async {
    await pumpThemed(
      t,
      SizedBox(width: 350, child: _card(pick: _pick(), selection: LanguageSelection.initial)),
    );
    final container = ProviderScope.containerOf(t.element(find.byType(GathaCard)));
    bool marked() => container.read(savedProvider).isBookmarked('r1', 's1');
    final button = find.byKey(const ValueKey('gatha-bookmark'));
    expect(button, findsOneWidget);
    expect(marked(), isFalse);
    expect(find.byTooltip('Bookmark this section'), findsOneWidget);
    expect(t.widget<NamoIconButton>(button).filled, isFalse);
    expect(t.widget<NamoIconButton>(button).icon, Symbols.bookmark_rounded);
    expect(t.getSize(button).shortestSide, greaterThanOrEqualTo(48));

    await t.tap(button);
    await t.pump();
    expect(marked(), isTrue);
    expect(find.byTooltip('Remove bookmark'), findsOneWidget);
    expect(t.widget<NamoIconButton>(button).filled, isTrue);

    await t.tap(button);
    await t.pump();
    expect(marked(), isFalse);
    expect(find.byTooltip('Bookmark this section'), findsOneWidget);
  });

  testWidgets('a section bookmarked elsewhere shows as bookmarked', (t) async {
    await pumpThemed(
      t,
      SizedBox(width: 350, child: _card(pick: _pick(), selection: LanguageSelection.initial)),
    );
    final container = ProviderScope.containerOf(t.element(find.byType(GathaCard)));
    container.read(savedProvider.notifier).toggleBookmark('r1', 's1');
    await t.pump();
    expect(t.widget<NamoIconButton>(find.byKey(const ValueKey('gatha-bookmark'))).filled, isTrue);
  });

  testWidgets('English shows only when selected, and only if the verse has it', (t) async {
    await pumpThemed(
      t,
      SizedBox(
        width: 350,
        child: _card(
          pick: _pick(),
          selection: const LanguageSelection([ReadingLanguage.sinhala]),
        ),
      ),
    );
    expect(find.text('english placeholder'), findsNothing);
    expect(find.text('sinhala placeholder'), findsOneWidget);

    const bare = Verse(
      id: 's1-v1',
      paliSi: 'pali placeholder',
      check: CheckStatus.checkedAgainstSource,
    );
    const section = Section(id: 's1', number: 1, heading: 'Heading 1', verses: [bare]);
    const reading = Reading(id: 'r1', title: 'Reading 1', sections: [section]);
    await pumpThemed(
      t,
      SizedBox(
        width: 350,
        child: _card(
          pick: GathaPick(reading, section, bare),
          selection: const LanguageSelection([ReadingLanguage.english]),
        ),
      ),
    );
    expect(find.text('english placeholder'), findsNothing);
    expect(find.text('pali placeholder'), findsOneWidget);
  });

  testWidgets('the watermark is behind the text, not tappable, not in semantics', (t) async {
    final handle = t.ensureSemantics();
    await pumpThemed(
      t,
      SizedBox(width: 350, child: _card(pick: _pick(), selection: LanguageSelection.initial)),
    );
    final mark = find.byType(LeafWatermark);
    expect(mark, findsOneWidget);
    expect(
      find.ancestor(of: mark, matching: find.byType(IgnorePointer)),
      findsWidgets,
    );
    expect(
      find.descendant(of: mark, matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
    handle.dispose();
  });

  for (final b in Brightness.values) {
    testWidgets('320 wide at 2x text, all three languages, no overflow ($b)', (t) async {
      await pumpThemed(
        t,
        SizedBox(
          width: 288,
          child: _card(
            pick: _pick(),
            selection: const LanguageSelection(
                [ReadingLanguage.pali, ReadingLanguage.sinhala, ReadingLanguage.english]),
            topicTitle: 'A long topic title for the caption',
          ),
        ),
        size: const Size(320, 800),
        textScale: 2,
        brightness: b,
      );
      expect(t.takeException(), isNull);
    });
  }
}
