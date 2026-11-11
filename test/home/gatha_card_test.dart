import 'dart:math' as math;

import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/marks.dart';
import 'package:buddhist_gatha/design/typography.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/design/widgets/pressable.dart';
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

  testWidgets('"Read in context" is at least 48 high and wide', (t) async {
    await pumpThemed(
      t,
      SizedBox(width: 350, child: _card(pick: _pick(), selection: LanguageSelection.initial)),
    );
    final pill = find.ancestor(
      of: find.text('Read in context'),
      matching: find.byType(Pressable),
    );
    expect(pill, findsOneWidget);
    expect(t.getSize(pill).height, greaterThanOrEqualTo(48));
    expect(t.getSize(pill).width, greaterThanOrEqualTo(48));
  });

  // The leaf is gold at the watermark's opacity, drawn twice where its lines
  // cross (outline and veins), over the card's gradient (surface at the top,
  // backgroundAlt at the bottom). The verse and the grey text keep 4.5 : 1 on
  // the strongest such pixel at either end of the gradient. The gold overline
  // is held to the same on the leaf wherever the leaf reaches it, and on the
  // plain gradient where it does not.
  double lum(Color c) {
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  double contrast(Color a, Color b) {
    final x = lum(a), y = lum(b);
    return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
  }

  for (final b in Brightness.values) {
    final p = paletteOf(b);
    final opacity = const LeafWatermark().opacity;
    Color leaf(Color ground) {
      var c = ground;
      for (var i = 0; i < 2; i++) {
        c = Color.alphaBlend(p.gold.withValues(alpha: p.gold.a * opacity), c);
      }
      return c;
    }

    test('verse and caption text over the leaf watermark keep 4.5 : 1 ($b)', () {
      for (final ground in [p.surface, p.backgroundAlt]) {
        expect(contrast(p.text, leaf(ground)), greaterThanOrEqualTo(4.5));
        expect(contrast(p.textSecondary, leaf(ground)), greaterThanOrEqualTo(4.5));
      }
    });

    for (final (width, textScale) in [(288.0, 2.0), (350.0, 1.0), (350.0, 2.0)]) {
      testWidgets('the gold overline keeps 4.5 : 1 where the leaf is and is '
          'clear of it ($b, $width wide, text $textScale)', (t) async {
        await pumpThemed(
          t,
          SizedBox(
            width: width,
            child: _card(pick: _pick(), selection: LanguageSelection.initial),
          ),
          brightness: b,
          textScale: textScale,
        );
        final card = t.getRect(find.byType(GathaCard));
        final overline = t.getRect(find.text("TODAY'S GATHA"));
        // The leaf as painted: 24 x 32 units, fitted and centred in its box.
        final box = t.getRect(find.byType(LeafWatermark));
        final scale = math.min(box.width / 24, box.height / 32);
        final drawn = Rect.fromCenter(
          center: box.center,
          width: 24 * scale,
          height: 32 * scale,
        );
        final fraction =
            ((overline.bottom - card.top) / card.height).clamp(0.0, 1.0);
        final plain = Color.lerp(p.surface, p.backgroundAlt, fraction)!;
        final ground = drawn.overlaps(overline) ? leaf(plain) : plain;
        expect(contrast(p.gold, ground), greaterThanOrEqualTo(4.5));
      });
    }
  }
}
