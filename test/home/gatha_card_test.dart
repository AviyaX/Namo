import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/typography.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/design/widgets/surface_card.dart';
import 'package:buddhist_gatha/home/gatha_card.dart';
import 'package:buddhist_gatha/home/today.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('the verse is drawn at the reader text size and spacing', (t) async {
    final p = paletteOf(Brightness.dark);
    await pumpThemed(
      t,
      SizedBox(
        width: 350,
        child: GathaCard(
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
        '12 apart, the heading and "Read in context" ($b)', (t) async {
      final p = paletteOf(b);
      const selection = LanguageSelection([ReadingLanguage.sinhala, ReadingLanguage.english]);
      await pumpThemed(
        t,
        SizedBox(width: 350, child: GathaCard(pick: _pick(), selection: selection)),
        brightness: b,
      );
      final card = t.widget<SurfaceCard>(find.byType(SurfaceCard));
      expect(card.leadingLine, p.gold);
      expect(card.onTap, isNull);
      expect(find.text("Today's gatha"), findsOneWidget);

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
      final heading = t.widget<Text>(find.text('Heading 1'));
      expect(heading.style, NamoType.caption(p.textSecondary));
      expect(find.widgetWithText(TextAction, 'Read in context'), findsOneWidget);
      // The heading comes after the texts, the action last.
      expect(
        t.getTopLeft(find.text('Heading 1')).dy,
        greaterThan(t.getBottomLeft(find.byKey(const ValueKey('gatha-text-1'))).dy),
      );
      expect(
        t.getTopLeft(find.text('Read in context')).dy,
        greaterThan(t.getBottomLeft(find.text('Heading 1')).dy),
      );
    });
  }

  testWidgets('fits 320 wide at 2x text', (t) async {
    await pumpThemed(
      t,
      SizedBox(
        width: 288,
        child: GathaCard(pick: _pick(), selection: LanguageSelection.initial),
      ),
      size: const Size(320, 800),
      textScale: 2,
    );
    expect(t.takeException(), isNull);
  });
}
