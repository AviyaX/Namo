import 'dart:io';
import 'dart:ui' as ui;

import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/reader/reader_bottom_bar.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/design/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quality_support.dart';

const _long = 'Lorem ipsum dolor sit amet consectetur adipiscing elit sed do '
    'eiusmod tempor incididunt ut labore';

/// Made-up content with long Latin strings everywhere text is shown.
Library longLibrary({Correction? correction}) => Library(
  categories: [
    Category(
      id: 'c1',
      title: 'Category $_long',
      subtitle: 'Subtitle $_long',
      readings: [
        Reading(
          id: 'r1',
          title: 'Reading $_long',
          sections: [
            Section(
              id: 's01',
              number: 1,
              heading: 'Heading $_long',
              corrections: [?correction],
              verses: const [
                Verse(
                  id: 's01-v1',
                  paliSi: _long,
                  sinhala: _long,
                  english: _long,
                  englishKind: EnglishKind.translation,
                ),
              ],
            ),
            Section(
              id: 's02',
              number: 2,
              heading: 'Short',
              verses: const [Verse(id: 's02-v1', paliSi: _long, sinhala: _long)],
            ),
          ],
        ),
      ],
    ),
  ],
);

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

ProviderContainer containerOf(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

Finder row(String label) => find.text(label);

void main() {
  setUpAll(loadBundledFonts);

  group('1. web/index.html', () {
    test('has no viewport tag that blocks zooming', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, isNot(contains('user-scalable')));
      expect(html, isNot(contains('maximum-scale')));
      expect(html, isNot(contains('name="viewport"')));
    });
  });

  group('4. contents list numbers', () {
    for (final dark in [false, true]) {
      testWidgets('the row number reads at 4.5:1 (${dark ? 'dark' : 'light'})', (t) async {
        await openReal(t, Routes.contents(realReadingId), dark: dark);
        final number = t.widget<Text>(find.text('1').first);
        final background = Theme.of(t.element(find.byType(Scaffold).first)).scaffoldBackgroundColor;
        expect(contrast(number.style!.color!, background), greaterThanOrEqualTo(4.5));
      });
    }

    for (final dark in [false, true]) {
      testWidgets('the reader section number reads at 4.5:1 (${dark ? 'dark' : 'light'})', (t) async {
        await openReal(t, Routes.reader(realReadingId), dark: dark);
        final heading = find.byKey(const ValueKey('heading-s01'));
        final number = t.widget<Text>(
          find.descendant(of: heading, matching: find.text('1')),
        );
        final background = Theme.of(t.element(find.byType(Scaffold).first)).scaffoldBackgroundColor;
        expect(contrast(number.style!.color!, background), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('5, 6. chooser rows', () {
    testWidgets('language rows say checked, theme and layout rows are one-of-a-group', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.settings, size: const Size(390, 1400));
      ui.SemanticsFlags flags(String label) =>
          t.getSemantics(row(label)).getSemanticsData().flagsCollection;
      expect(flags('Pali').isChecked, ui.CheckedState.isTrue);
      expect(flags('English').isChecked, ui.CheckedState.isFalse);
      expect(flags('Pali').isSelected, ui.Tristate.none);
      expect(flags('Dark').isChecked, ui.CheckedState.isTrue);
      expect(flags('Light').isChecked, ui.CheckedState.isFalse);
      expect(flags('Dark').isInMutuallyExclusiveGroup, isTrue);
      expect(flags('Verse by verse').isInMutuallyExclusiveGroup, isTrue);
      expect(flags('Pali').isInMutuallyExclusiveGroup, isFalse);
      handle.dispose();
    });

    testWidgets('every chooser row, list row and speed choice has a focus colour', (t) async {
      await openReal(t, Routes.settings, size: const Size(390, 1400));
      // Sources is an editorial ListRow: a Pressable, which draws a focus ring.
      expect(
        find.ancestor(of: find.text('Sources'), matching: find.byType(Pressable)),
        findsOneWidget,
      );
      // The language, layout and theme segments are Pressables too.
      for (final label in ['Pali', 'Verse by verse', 'Dark']) {
        expect(
          find.ancestor(of: find.text(label), matching: find.byType(Pressable)),
          findsOneWidget,
          reason: label,
        );
      }
      // The speed choices are segments of the speed selector: Pressables.
      for (final label in ['Slow', 'Normal', 'Fast']) {
        expect(
          find.ancestor(of: find.text(label), matching: find.byType(Pressable)),
          findsOneWidget,
          reason: label,
        );
      }
    });
  });

  testWidgets('7. the layout rows stay put when "Needs two languages" appears', (t) async {
    await openReal(t, Routes.settings, size: const Size(390, 1400));
    final before = t.getTopLeft(row('Section by section')).dy;
    await t.tap(row('Pali'));
    await t.pumpAndSettle();
    expect(find.text('Needs two languages'), findsOneWidget);
    expect(t.getTopLeft(row('Section by section')).dy, before);
    // Side by side, so the second segment stays level with the first.
    expect(t.getTopLeft(row('Verse by verse')).dy, before);
  });

  testWidgets('10. the speed slider stays put when "Custom" appears', (t) async {
    await openReal(t, Routes.settings, size: const Size(390, 1400));
    final slider = find.byKey(const ValueKey('setting-scroll-speed'));
    final before = t.getTopLeft(slider).dy;
    containerOf(t).read(settingsProvider.notifier).setScrollSpeed(31);
    await t.pumpAndSettle();
    expect(find.text('Custom'), findsOneWidget);
    expect(t.getTopLeft(slider).dy, before);
  });

  group('8. reader top bar', () {
    for (final size in const [Size(320, 568), Size(390, 844)]) {
      for (final scale in [1.5, 2.0]) {
        testWidgets(
          'a long title fits the top bar on one line: ${size.width.round()}x${size.height.round()}, device text $scale',
          (t) async {
            await openReal(
              t,
              Routes.reader('r1'),
              size: size,
              deviceTextScale: scale,
              library: longLibrary(),
            );
            expect(t.takeException(), isNull);
            // The title shows in full height on one line, cut short, inside
            // the top bar.
            final title = find.textContaining('Reading Lorem');
            expect(title, findsOneWidget);
            final bar = t.getRect(find.byKey(const ValueKey('reader-top-bar')));
            final words = t.getRect(title);
            expect(words.top, greaterThanOrEqualTo(bar.top));
            expect(words.bottom, lessThanOrEqualTo(bar.bottom));
          },
        );
      }
    }
  });

  testWidgets('9. the bookmark button lines up with the first line of a wrapped heading', (t) async {
    Future<double> offset(Size size) async {
      await openReal(t, Routes.reader('r1'), size: size, library: longLibrary());
      // Measured from the section number, which sits on the heading's first
      // line (the room above a heading differs between the first and the
      // rest).
      final b = t.getRect(find.byTooltip('Bookmark this section').first);
      final n = t.getRect(find.descendant(
        of: find.byKey(const ValueKey('heading-s01')),
        matching: find.text('1'),
      ));
      return b.center.dy - n.top;
    }

    final wrapped = await offset(const Size(320, 700));
    // Section 2's heading is one line; the same offset applies to it.
    final n2 = t.getRect(find.descendant(
      of: find.byKey(const ValueKey('heading-s02')),
      matching: find.text('2'),
    ));
    final b2 = t.getRect(find.byTooltip('Bookmark this section').last);
    expect(wrapped, closeTo(b2.center.dy - n2.top, 0.5));
  });

  group('11-13. audio row', () {
    testWidgets('11. on a wide screen the recording controls stay in the reading column', (t) async {
      const size = Size(1280, 800);
      await openReal(t, Routes.reader(realReadingId), size: size, audio: true);
      final play = t.getRect(find.byKey(const ValueKey('audio-play')));
      final time = t.getRect(find.textContaining(' / '));
      final left = (size.width - NamoSizes.readingColumn) / 2;
      expect(play.left, greaterThanOrEqualTo(left));
      expect(time.right, lessThanOrEqualTo(left + NamoSizes.readingColumn));
      final next = t.getRect(find.byKey(const ValueKey('reader-next')));
      expect(next.right, lessThanOrEqualTo(left + NamoSizes.readingColumn));
    });

    for (final size in const [Size(320, 568), Size(390, 844)]) {
      testWidgets('12. the bottom bar fits the placeholder label at device text 2.0: ${size.width.round()}', (t) async {
        await openReal(
          t,
          Routes.reader(realReadingId),
          size: size,
          deviceTextScale: 2.0,
          audio: true,
        );
        expect(t.takeException(), isNull);
        expect(find.byKey(const ValueKey('reader-play')), findsOneWidget);
        final bar = t.getRect(find.byType(ReaderBottomBar));
        expect(bar.bottom, lessThanOrEqualTo(size.height));
        expect(bar.height, lessThan(size.height / 2));
      });
    }

    testWidgets('13. the placeholder label is one labelled node', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.reader(realReadingId), audio: true);
      final node = t.getSemantics(find.text('Development placeholder tone (not a chant)'));
      expect(node.label, 'Development placeholder tone (not a chant)');
      handle.dispose();
    });

    testWidgets('13. the failed message is announced as a live region', (t) async {
      final handle = t.ensureSemantics();
      await openReal(t, Routes.reader(realReadingId), audio: true, audioFails: true);
      final node = t.getSemantics(find.text('The recording could not be played.'));
      expect(node.label, 'The recording could not be played.');
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('13. the failed message fits at device text 2.0 on a narrow screen', (t) async {
      await openReal(
        t,
        Routes.reader(realReadingId),
        size: const Size(320, 568),
        deviceTextScale: 2.0,
        audio: true,
        audioFails: true,
      );
      expect(t.takeException(), isNull);
      expect(find.text('The recording could not be played.'), findsOneWidget);
    });
  });

  group('14. wide screens cap the column', () {
    testWidgets('Saved', (t) async {
      await openReal(t, Routes.saved, size: const Size(1600, 900), withSaved: true);
      final box = t.getRect(find.byKey(const ValueKey('saved-column')));
      expect(box.width, NamoSizes.readingColumn);
    });

    testWidgets('Sources', (t) async {
      await openReal(t, Routes.sources, size: const Size(1600, 900));
      final box = t.getRect(find.byKey(const ValueKey('sources-column')));
      expect(box.width, NamoSizes.readingColumn);
    });
  });

  group('15. Saved and Sources with long text at device text 2.0', () {
    for (final size in const [Size(320, 568), Size(390, 844), Size(1280, 800)]) {
      testWidgets('Saved with long titles: ${size.width.round()}', (t) async {
        await openReal(
          t,
          Routes.saved,
          size: size,
          deviceTextScale: 2.0,
          withSaved: true,
          library: longLibrary(),
        );
        await scrollThrough(t);
      });
    }
  });

  testWidgets('16. the auto-scroll switch is visible when off, in both themes', (t) async {
    for (final brightness in Brightness.values) {
      final theme = namoTheme(brightness);
      final p = theme.extension<NamoPalette>()!;
      final off = <WidgetState>{};
      final outline = theme.switchTheme.trackOutlineColor!.resolve(off)!;
      final thumb = theme.switchTheme.thumbColor!.resolve(off)!;
      final track = theme.switchTheme.trackColor!.resolve(off)!;
      expect(contrast(outline, p.background), greaterThanOrEqualTo(3), reason: '$brightness outline');
      expect(contrast(thumb, track), greaterThanOrEqualTo(3), reason: '$brightness thumb');
      final on = {WidgetState.selected};
      expect(
        contrast(theme.switchTheme.trackColor!.resolve(on)!, p.background),
        greaterThanOrEqualTo(3),
        reason: '$brightness on track',
      );
    }
  });

  group('17. Sources: a long unbroken form', () {
    const token = 'Abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz';
    for (final size in const [Size(320, 568), Size(390, 844)]) {
      testWidgets('is held by the row: ${size.width.round()}, device text 2.0', (t) async {
        await openReal(
          t,
          Routes.sources,
          size: size,
          deviceTextScale: 2.0,
          library: longLibrary(
            correction: const Correction(
              field: 'sinhala',
              from: token,
              to: '${token}x',
              reason: 'A reason',
              count: 1,
            ),
          ),
        );
        await scrollThrough(t);
        final row = t.getRect(find.byKey(const ValueKey('correction-0')));
        expect(find.textContaining('Abcdef'), findsNWidgets(2));
        for (final f in find.textContaining('Abcdef').evaluate()) {
          final r = t.getRect(find.byElementPredicate((e) => e == f));
          expect(r.right, lessThanOrEqualTo(row.right));
        }
      });
    }
  });
}
