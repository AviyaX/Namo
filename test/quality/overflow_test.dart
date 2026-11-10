import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quality_support.dart';

const _sizes = [Size(320, 568), Size(390, 844), Size(1280, 800)];

String _name(LanguageSelection s) => s.languages.map((l) => l.code).join('+');

/// Every single language, and every ordered pair.
List<LanguageSelection> _selections() {
  const all = ReadingLanguage.values;
  return [
    for (final a in all) LanguageSelection([a]),
    for (final a in all)
      for (final b in all)
        if (a != b) LanguageSelection([a, b]),
  ];
}

void main() {
  setUpAll(loadBundledFonts);

  // The reader, at every size, text size, device text size, language choice
  // and (for two languages) layout. The layout only matters for two
  // languages, so a single language is tried once.
  for (final size in _sizes) {
    for (final scale in [0.85, 1.6]) {
      for (final deviceTextScale in [1.0, 2.0]) {
        for (final selection in _selections()) {
          for (final layout in TwoLanguageLayout.values) {
            if (selection.languages.length == 1 &&
                layout != TwoLanguageLayout.values.first) {
              continue;
            }
            final layoutName =
                selection.languages.length == 1 ? '' : ', ${layout.name} layout';
            testWidgets(
              'reader does not overflow: ${size.width.round()}x${size.height.round()}, '
              'text $scale, device text $deviceTextScale, ${_name(selection)}$layoutName',
              (t) async {
                await openReal(
                  t,
                  Routes.reader(realReadingId),
                  size: size,
                  deviceTextScale: deviceTextScale,
                  settings: AppSettings(
                    languages: selection,
                    layout: layout,
                    fontScale: scale,
                  ),
                );
                await scrollThrough(t);
              },
            );
          }
        }
      }
    }
  }

  // The reader with the recording controls showing (the labelled tone, and
  // the failed message), where the bottom bar is tallest.
  for (final size in _sizes) {
    for (final failed in [false, true]) {
      testWidgets(
        'reader bottom bar does not overflow with the ${failed ? 'failed message' : 'placeholder label'}: '
        '${size.width.round()}x${size.height.round()}, device text 2.0',
        (t) async {
          await openReal(
            t,
            Routes.reader(realReadingId),
            size: size,
            deviceTextScale: 2.0,
            settings: const AppSettings(fontScale: 1.6),
            audio: true,
            audioFails: failed,
          );
          expect(t.takeException(), isNull);
          await scrollThrough(t);
          // The recording controls leave room for the text.
          final body = t.getSize(find.byType(ReaderBody));
          expect(body.height, greaterThan(size.height * 0.3));
        },
      );
    }
  }

  // The same sizes for every other screen, at the largest device text size.
  final others = <(String, String, bool)>[
    ('Home', Routes.home, false),
    ('Library', Routes.library, false),
    ('Category', Routes.category(realCategoryId), false),
    ('Contents list', Routes.contents(realReadingId), false),
    ('Saved (empty)', Routes.saved, false),
    ('Saved (with entries)', Routes.saved, true),
    ('Settings', Routes.settings, false),
    ('Sources', Routes.sources, false),
  ];
  for (final size in _sizes) {
    for (final (name, location, saved) in others) {
      testWidgets(
        '$name does not overflow: ${size.width.round()}x${size.height.round()}, device text 2.0',
        (t) async {
          await openReal(
            t,
            location,
            size: size,
            deviceTextScale: 2.0,
            withSaved: saved,
          );
          await scrollThrough(t);
        },
      );
    }
    testWidgets(
      'Settings with one language does not overflow: ${size.width.round()}x${size.height.round()}, device text 2.0',
      (t) async {
        await openReal(
          t,
          Routes.settings,
          size: size,
          deviceTextScale: 2.0,
          settings: AppSettings(
            languages: const LanguageSelection([ReadingLanguage.english]),
            scrollSpeed: 31,
          ),
        );
        await scrollThrough(t);
      },
    );
    testWidgets(
      'the reader sheet does not overflow: ${size.width.round()}x${size.height.round()}, device text 2.0',
      (t) async {
        await openReal(
          t,
          Routes.reader(realReadingId),
          size: size,
          deviceTextScale: 2.0,
          settings: AppSettings(
            languages: const LanguageSelection([ReadingLanguage.english]),
            scrollSpeed: 31,
          ),
        );
        await t.tap(find.byKey(const ValueKey('reader-settings')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final scrollable = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        );
        final position = t.state<ScrollableState>(scrollable.first).position;
        position.jumpTo(position.maxScrollExtent);
        await t.pump();
        expect(t.takeException(), isNull);
      },
    );
  }
}
