import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quality_support.dart';

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('the real reading shows 19 headings and reaches the end', (t) async {
    final library = await realLibrary(t);
    final reading = library.reading(realReadingId)!;
    await openReal(t, Routes.reader(realReadingId));

    final headings = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('heading-'),
    );
    expect(reading.sections, hasLength(19));
    expect(headings, findsNWidgets(19));

    final position = t.state<ScrollableState>(find.byType(Scrollable).first).position;
    position.jumpTo(position.maxScrollExtent);
    await t.pumpAndSettle();
    expect(find.text('තෙරුවන් සමාකර ගැනීම'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'English + Pali shows the not-available line on sections 9, 14, 16 and 17 only (whole section)',
    (t) async {
      final library = await realLibrary(t);
      final reading = library.reading(realReadingId)!;
      await openReal(
        t,
        Routes.reader(realReadingId),
        settings: const AppSettings(
          languages: LanguageSelection([
            ReadingLanguage.english,
            ReadingLanguage.pali,
          ]),
        ),
      );

      const wholeLine = 'English is not yet available for this section.';
      final withLine = <int>[];
      for (final s in reading.sections) {
        final heading = find.byKey(ValueKey('heading-${s.id}'));
        expect(heading, findsOneWidget, reason: 'section ${s.number}');
        final line = find.descendant(of: heading, matching: find.text(wholeLine));
        if (line.evaluate().isNotEmpty) withLine.add(s.number);
      }
      expect(withLine, [9, 14, 16, 17]);
      expect(find.text(wholeLine), findsNWidgets(4));
      // Pali is in every section.
      expect(find.textContaining('Pali is not yet available'), findsNothing);
    },
  );

  testWidgets('on a wide screen the text column is at most 680 wide and centred', (t) async {
    const size = Size(1280, 800);
    final library = await realLibrary(t);
    final first = library.reading(realReadingId)!.sections.first;
    await openReal(t, Routes.reader(realReadingId), size: size);

    final heading = t.getRect(find.byKey(ValueKey('heading-${first.id}')));
    expect(heading.width, lessThanOrEqualTo(NamoSizes.readingColumn));
    expect(heading.width, greaterThan(500), reason: 'the column is used, not squeezed');
    expect(heading.center.dx, closeTo(size.width / 2, 1));

    final verse = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('verse-${first.verses.first.id}'),
    );
    final text = t.getRect(verse.first);
    expect(text.width, lessThanOrEqualTo(NamoSizes.readingColumn));
    expect(text.center.dx, closeTo(size.width / 2, 1));
  });
}
