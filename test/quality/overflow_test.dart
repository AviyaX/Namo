import 'dart:convert';

import 'package:buddhist_gatha/audio/recording_store.dart';
import 'package:buddhist_gatha/bana/bana_progress.dart';
import 'package:buddhist_gatha/books/book_places.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/design/widgets/floating_bar.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_search.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_state.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_tree.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bana/bana_support.dart';
import '../books/books_support.dart';
import '../support/fake_recording_store.dart';
import '../tipitaka/tipitaka_app_support.dart';
import '../tipitaka/tipitaka_support.dart';
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

  late AssetBytes shipped;
  late TipitakaTree shippedTree;
  setUpAll(() async {
    shipped = await shippedTreeAssets();
    shippedTree = await TipitakaRepository(load: shipped).tree();
  });

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
          // The recording controls leave room for the text: the reading area
          // visible above the floating bar (the text runs under the bar).
          final body = t.getRect(find.byType(ReaderBody));
          final bar = t.getRect(find.byType(FloatingBar));
          expect(bar.top - body.top, greaterThan(size.height * 0.3));
        },
      );
    }
  }

  for (final size in _sizes) {
    for (final side in [false, true]) {
      testWidgets('pirith reader does not overflow: ${size.width.round()}x${size.height.round()}, device text 2.0${side ? ', side by side' : ''}', (t) async {
        await openReal(t, Routes.reader(mangalaReadingId), size: size, deviceTextScale: 2.0,
            settings: AppSettings(
                fontScale: 1.6,
                layout: side ? TwoLanguageLayout.sideBySide : TwoLanguageLayout.verse));
        expect(t.takeException(), isNull);
        expect(find.text('Scroll'), findsOneWidget);
        expect(find.text('Chant'), findsOneWidget);
        await scrollThrough(t);
      });
    }
  }

  // A first-run tip up over each screen it points on: the bubble fits, and
  // is inside the view, at the narrowest width and the largest device text.
  for (final size in _sizes) {
    final where = '${size.width.round()}x${size.height.round()}, device text 2.0';
    final bubble = find.byKey(const ValueKey('tip-bubble'));
    void expectInView(WidgetTester t) {
      expect(t.takeException(), isNull);
      expect(bubble, findsOneWidget);
      final view = Offset.zero & size;
      final rect = t.getRect(bubble);
      expect(view.expandToInclude(rect), view, reason: '$rect leaves $view');
    }

    testWidgets('Home with the Recordings tip does not overflow: $where', (
      t,
    ) async {
      await openReal(t, Routes.home,
          size: size, deviceTextScale: 2.0, tips: true);
      expectInView(t);
    });

    testWidgets('Library with the My flows tip does not overflow: $where', (
      t,
    ) async {
      await openReal(t, Routes.library,
          size: size, deviceTextScale: 2.0, tips: true);
      // The tip waits for its card to be wholly on screen; on a small screen
      // at large text that is a scroll away.
      for (var i = 0; i < 10 && bubble.evaluate().isEmpty; i++) {
        await t.drag(find.byKey(const ValueKey('screen-library')),
            const Offset(0, -200));
        await t.pumpAndSettle();
      }
      expectInView(t);
    });

    testWidgets(
      'the gatha reader with the Languages and layout tip does not overflow: $where',
      (t) async {
        await openReal(t, Routes.reader(realReadingId),
            size: size, deviceTextScale: 2.0, tips: true);
        expectInView(t);
      },
    );

    testWidgets(
      'the pirith reader with the Scroll and Chant tip does not overflow: $where',
      (t) async {
        await openReal(t, Routes.reader(mangalaReadingId),
            size: size,
            deviceTextScale: 2.0,
            tips: true,
            recordingStore: FakeRecordingStore());
        expect(bubble, findsOneWidget);
        await t.tap(find.byKey(const ValueKey('tip-got-it')));
        await t.pumpAndSettle();
        expectInView(t);
      },
    );
  }

  // A flow with a recorded section: its reader with the chant bar idle, and
  // its editor with the marks, in both themes and at both text sizes.
  for (final size in [const Size(320, 568), const Size(1280, 800)]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        final where =
            '${size.width.round()}x${size.height.round()}, device text $scale, '
            '${dark ? 'dark' : 'light'}';
        testWidgets('the flow reader with the chant bar does not overflow: '
            '$where', (t) async {
          await openReal(
            t,
            Routes.reader('flow-1'),
            size: size,
            deviceTextScale: scale,
            dark: dark,
            storeExtras: await realFlowsStore(t),
          );
          expect(t.takeException(), isNull);
          await scrollThrough(t);
        });
        testWidgets('the flow editor with marks does not overflow: $where', (
          t,
        ) async {
          await openReal(
            t,
            Routes.flowEditor('flow-1'),
            size: size,
            deviceTextScale: scale,
            dark: dark,
            storeExtras: await realFlowsStore(t),
          );
          expect(t.takeException(), isNull);
          // The page scrolls, so every row, the marked one too, passes through.
          await scrollThrough(t);
          expect(t.takeException(), isNull);
        });
      }
    }
  }

  // The longest recording line, with Try again beside it, in the narrowest
  // bar.
  testWidgets('the pirith reader with a failed recording does not overflow', (
    t,
  ) async {
    final store = FakeRecordingStore()
      ..set(
        mangalaReadingId,
        const RecordingStatus(
          availability: Availability.failed,
          reason: damagedMessage,
          bytes: 1046598,
        ),
      );
    await openReal(
      t,
      Routes.reader(mangalaReadingId),
      size: const Size(320, 568),
      deviceTextScale: 2.0,
      settings: const AppSettings(fontScale: 1.6),
      recordingStore: store,
    );
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('recording-row')), findsOneWidget);
    await scrollThrough(t);
  });

  // Settings with the Recordings group at its fullest: progress, failures and
  // both buttons, at the narrowest width and largest device text.
  testWidgets('Settings while recordings download does not overflow', (t) async {
    final store = FakeRecordingStore();
    final statuses = <String, RecordingStatus>{};
    for (var i = 0; i < 40; i++) {
      final (availability, progress) = i < 12
          ? (Availability.downloaded, 1.0)
          : i == 12
          ? (Availability.downloading, 0.42)
          : i < 16
          ? (Availability.failed, 0.0)
          : (Availability.waiting, 0.0);
      statuses['r$i'] = RecordingStatus(
        availability: availability,
        progress: progress,
        bytes: 2563097,
      );
    }
    store.snapshot.value = RecordingsSnapshot(statuses);
    await openReal(
      t,
      Routes.settings,
      size: const Size(320, 568),
      deviceTextScale: 2.0,
      recordingStore: store,
    );
    await scrollThrough(t);
  });

  // Home on its own at the phone, tall phone and desktop sizes, ordinary and
  // doubled device text, in both themes.
  for (final size in const [Size(320, 640), Size(412, 915), Size(1280, 800)]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'Home does not overflow: ${size.width.round()}x${size.height.round()}, '
          'device text $scale, ${dark ? 'dark' : 'light'}',
          (t) async {
            await openReal(
              t,
              Routes.home,
              size: size,
              deviceTextScale: scale,
              dark: dark,
            );
            await scrollThrough(t);
          },
        );
      }
    }
  }

  // The same sizes for every other screen, at the largest device text size.
  final others = <(String, String, bool)>[
    ('Home', Routes.home, false),
    ('Library (closed)', Routes.library, false),
    ('Library (open)', Routes.category(realCategoryId), false),
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
      'Home with the largest reading text and spacing does not overflow: ${size.width.round()}x${size.height.round()}, device text 2.0',
      (t) async {
        await openReal(
          t,
          Routes.home,
          size: size,
          deviceTextScale: 2.0,
          settings: const AppSettings(
            languages: LanguageSelection([
              ReadingLanguage.sinhala,
              ReadingLanguage.english,
            ]),
            fontScale: 1.6,
            lineSpacing: 2.2,
          ),
        );
        await scrollThrough(t);
      },
    );
    testWidgets(
      'Home with several reading cards does not overflow: ${size.width.round()}x${size.height.round()}, device text 2.0',
      (t) async {
        await openReal(
          t,
          Routes.home,
          size: size,
          deviceTextScale: 2.0,
          library: severalCategories(),
        );
        await scrollThrough(t);
        expect(find.byKey(const ValueKey('card-art-panel')), findsWidgets);
      },
    );
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

  // Every screen at the five sizes the design is drawn for, at the normal
  // and a larger text size, in both themes: no overflow, no exception.
  const matrixSizes = [
    Size(360, 800),
    Size(390, 844),
    Size(840, 900),
    Size(1280, 800),
    Size(844, 390),
  ];

  Future<void> typeSearch(WidgetTester t, String q) async {
    await t.enterText(find.byKey(const ValueKey('library-search')), q);
    await t.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('reader-settings')));
    await t.pumpAndSettle();
  }

  final screens = <(
    String,
    String,
    AppSettings,
    bool,
    bool,
    Future<void> Function(WidgetTester)?,
  )>[
    ('Home (fresh)', Routes.home, const AppSettings(), false, false, null),
    ('Home (remembered place)', Routes.home, const AppSettings(), false, true, null),
    ('Library (closed)', Routes.library, const AppSettings(), false, false, null),
    ('Library (topic open)', Routes.category(realCategoryId), const AppSettings(), false, false, null),
    (
      'Library (search results)',
      Routes.library,
      const AppSettings(),
      false,
      false,
      (t) async {
        final lib = await realLibrary(t);
        final heading = lib.category(realCategoryId)!.readings.first.sections[3].heading;
        await typeSearch(t, String.fromCharCodes(heading.runes.take(2)));
      },
    ),
    (
      'Library (nothing found)',
      Routes.library,
      const AppSettings(),
      false,
      false,
      (t) => typeSearch(t, 'zzzz'),
    ),
    ('Reader (one language)', Routes.reader(realReadingId), AppSettings(languages: const LanguageSelection([ReadingLanguage.english])), false, false, null),
    ('Reader (two languages)', Routes.reader(realReadingId), AppSettings(languages: const LanguageSelection([ReadingLanguage.pali, ReadingLanguage.sinhala])), false, false, null),
    ('Reader (settings sheet)', Routes.reader(realReadingId), const AppSettings(), false, false, openSheet),
    ('Saved (empty)', Routes.saved, const AppSettings(), false, false, null),
    ('Saved (filled)', Routes.saved, const AppSettings(), true, false, null),
    ('Settings', Routes.settings, const AppSettings(), false, false, null),
    ('Sources', Routes.sources, const AppSettings(), false, false, null),
    ('Not found', '/no/such/place', const AppSettings(), false, false, null),
  ];

  for (final size in matrixSizes) {
    for (final textScale in [1.0, 1.5]) {
      for (final dark in [false, true]) {
        for (final (name, location, settings, saved, remembered, after) in screens) {
          testWidgets(
            'matrix: $name, ${size.width.round()}x${size.height.round()}, '
            'text ${textScale}x, ${dark ? 'dark' : 'light'}',
            (t) async {
              String? place;
              if (remembered) {
                final lib = await realLibrary(t);
                final reading = lib.category(realCategoryId)!.readings.first;
                place = jsonEncode(
                  PositionState(
                    byReading: {
                      reading.id: ReadingProgress(
                        position: ReadingPosition(
                          readingId: reading.id,
                          sectionId: reading.sections[1].id,
                          fraction: 0.4,
                        ),
                        progress: 0.4,
                      ),
                    },
                    lastReadingId: reading.id,
                  ).toJson(),
                );
              }
              await openReal(
                t,
                location,
                size: size,
                deviceTextScale: textScale,
                dark: dark,
                settings: settings,
                withSaved: saved,
                storeExtras: {positionKey: ?place},
              );
              if (after != null) await after(t);
              expect(t.takeException(), isNull);
              if (find.byType(Scrollable).evaluate().isNotEmpty &&
                  !name.contains('sheet')) {
                await scrollThrough(t);
              }
              expect(t.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  // Samantha Pattana: the Library with the topic open, and both readings in
  // the reader, at the narrowest and the wide size, at device text 1.0 and
  // 2.0, with Pali only, Pali and Sinhala, and English only.
  const spSelections = [
    LanguageSelection([ReadingLanguage.pali]),
    LanguageSelection([ReadingLanguage.pali, ReadingLanguage.sinhala]),
    LanguageSelection([ReadingLanguage.english]),
  ];
  for (final size in const [Size(320, 568), Size(1280, 800)]) {
    for (final deviceTextScale in [1.0, 2.0]) {
      final where =
          '${size.width.round()}x${size.height.round()}, device text $deviceTextScale';
      testWidgets('Library (Samantha Pattana open) does not overflow: $where', (
        t,
      ) async {
        await openReal(
          t,
          Routes.category(samanthaCategoryId),
          size: size,
          deviceTextScale: deviceTextScale,
        );
        for (final id in [spIntroductionId, spVandanaId]) {
          expect(find.byKey(ValueKey('reading-row-$id')), findsOneWidget);
        }
        await scrollThrough(t);
      });
      for (final id in [spIntroductionId, spVandanaId]) {
        for (final selection in spSelections) {
          testWidgets(
            '$id does not overflow: $where, ${_name(selection)}',
            (t) async {
              await openReal(
                t,
                Routes.reader(id),
                size: size,
                deviceTextScale: deviceTextScale,
                settings: AppSettings(languages: selection),
              );
              await scrollThrough(t);
            },
          );
        }
      }
    }
  }

  // Pirith: the Library with the topic open, and a pirith in the reader
  // silent, chanting with a phrase highlighted, and with the pill showing.
  final pirithScreens = <(String, String, Future<void> Function(WidgetTester, Size, double, bool)?)>[
    ('Library (Pirith open)', Routes.category(pirithCategoryId), null),
    ('Pirith (silent)', Routes.reader(mangalaReadingId), null),
    (
      'Pirith (chanting, phrase highlighted)',
      '',
      (t, size, scale, dark) =>
          openChanting(t, size: size, deviceTextScale: scale, dark: dark),
    ),
    (
      'Pirith (Follow the chanting showing)',
      '',
      (t, size, scale, dark) => openChanting(
        t,
        size: size,
        deviceTextScale: scale,
        dark: dark,
        pausedFollowing: true,
      ),
    ),
  ];
  for (final size in matrixSizes) {
    for (final textScale in [1.0, 1.5]) {
      for (final dark in [false, true]) {
        for (final (name, location, open) in pirithScreens) {
          testWidgets(
            'matrix: $name, ${size.width.round()}x${size.height.round()}, '
            'text ${textScale}x, ${dark ? 'dark' : 'light'}',
            (t) async {
              if (open != null) {
                await open(t, size, textScale, dark);
              } else {
                await openReal(
                  t,
                  location,
                  size: size,
                  deviceTextScale: textScale,
                  dark: dark,
                );
              }
              expect(t.takeException(), isNull);
              await scrollThrough(t);
              expect(t.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  // The Tripitaka (the made-up fixture): its first page, the first page with
  // a remembered place (the Continue card), a list page, the first page with
  // search results (a query typed in), and the reader in each of its three
  // views, at the narrowest and the wide size, ordinary and doubled device
  // text, in both themes.
  final tipitakaScreens = <(String, String, Map<String, String>)>[
    ('Tripitaka first page', Routes.tipitaka, const {}),
    (
      'Tripitaka first page with Continue card',
      Routes.tipitaka,
      {
        tipitakaPlacesKey: jsonEncode([
          {'key': 'vp-1-1', 'entry': 1, 'fraction': 0.5, 'order': 1},
        ]),
      },
    ),
    ('Tripitaka list', Routes.tipitakaNode('vp-2'), const {}),
    for (final view in TipitakaView.values)
      (
        'Tripitaka reader (${view.name})',
        Routes.tipitakaReader('vp-1-1'),
        {tipitakaViewKey: jsonEncode(view.name)},
      ),
  ];
  for (final size in const [Size(320, 568), Size(1280, 800)]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        final where = '${size.width.round()}x${size.height.round()}, '
            'device text $scale, ${dark ? 'dark' : 'light'}';
        for (final (name, location, extras) in tipitakaScreens) {
          testWidgets('$name does not overflow: $where', (t) async {
            await openReal(
              t,
              location,
              size: size,
              deviceTextScale: scale,
              dark: dark,
              storeExtras: extras,
            );
            expect(t.takeException(), isNull);
            if (name.contains('Continue')) {
              expect(find.byType(TipitakaContinueCard), findsOneWidget);
            }
            await scrollThrough(t);
          });
        }
        testWidgets('Tripitaka first page with search results does not '
            'overflow: $where', (t) async {
          // Over the shipped tree: the made-up names have no letters a
          // search can match.
          await openReal(
            t,
            Routes.tipitaka,
            size: size,
            deviceTextScale: scale,
            dark: dark,
            tipitaka: shipped,
          );
          await t.enterText(
            find.descendant(
              of: find.byKey(const ValueKey('tipitaka-search')),
              matching: find.byType(TextField),
            ),
            latinKey(shippedTree.node('dn-1')!.pali),
          );
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('tipitaka-result-dn-1')),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          await scrollThrough(t);
        });
        testWidgets('Tripitaka footnotes sheet does not overflow: $where',
            (t) async {
          await openReal(
            t,
            Routes.tipitakaReader('vp-1-1'),
            size: size,
            deviceTextScale: scale,
            dark: dark,
          );
          final mark = find.byKey(const ValueKey('tipitaka-footnote-mark-1'));
          final text = find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first;
          // Built lazily: drag down to it, then bring it to the top, clear
          // of the bar.
          for (var i = 0; i < 40 && mark.evaluate().isEmpty; i++) {
            await t.drag(text, const Offset(0, -100));
            await t.pump();
          }
          await t.ensureVisible(mark.first);
          await t.pumpAndSettle();
          await t.tap(mark.first);
          await t.pumpAndSettle();
          expect(find.text('Footnotes'), findsOneWidget);
          expect(t.takeException(), isNull);
        });
      }
    }
  }

  // The books (the made-up fixture; the nested book's page "1-1" has a
  // 60-character title, so the two-line ellipsis is exercised): the shelf on
  // the Library, a book's page without and with a remembered place, a
  // contents list, and the reader on a verse page, a list, table and picture
  // page, and a footnotes page. Page numbers: "1" is 2, "1-1" is 3, "1-2" is
  // 4, "2-1-1" is 7.
  final booksScreens = <(String, String, Map<String, String>)>[
    ('Books shelf', Routes.library, const {}),
    ('Book page', Routes.book(tinyBookNestedId), const {}),
    (
      'Book page with a place',
      Routes.book(tinyBookNestedId),
      {
        bookPlacesKey: jsonEncode({
          tinyBookNestedId: {'n': 3, 'offset': 0},
        }),
      },
    ),
    ('Book contents', Routes.bookContents(tinyBookNestedId, 2), const {}),
    ('Book reader (gatha)', Routes.bookReader(tinyBookNestedId, 3), const {}),
    (
      'Book reader (list, table, picture)',
      Routes.bookReader(tinyBookNestedId, 7),
      const {},
    ),
    ('Book reader (footnotes)', Routes.bookReader(tinyBookNestedId, 4), const {}),
  ];
  for (final size in const [Size(320, 568), Size(1280, 800)]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        final where = '${size.width.round()}x${size.height.round()}, '
            'device text $scale, ${dark ? 'dark' : 'light'}';
        for (final (name, location, extras) in booksScreens) {
          testWidgets('$name does not overflow: $where', (t) async {
            await openReal(
              t,
              location,
              size: size,
              deviceTextScale: scale,
              dark: dark,
              // The reader scrolled; Pages mode has its own cases.
              settings: const AppSettings(
                bookReadingMode: BookReadingMode.scroll,
              ),
              storeExtras: extras,
            );
            expect(t.takeException(), isNull);
            await scrollThrough(t);
          });
        }
      }
    }
  }

  // The books read page by page, at the app's largest text on the smallest
  // phone, on both papers in both themes: every page of both made-up books
  // (the long list, footnotes and table included), turned through with the
  // Next page arrow.
  final pageNext = find.byKey(const ValueKey('book-page-next'));
  for (final paper in BookPaper.values) {
    for (final dark in [false, true]) {
      for (final id in [tinyBookFlatId, tinyBookNestedId]) {
        testWidgets(
          'Book reader in Pages mode, every page of $id, does not overflow: '
          '320x568, text 1.6, ${paper.name} paper, ${dark ? 'dark' : 'light'}',
          (t) async {
            await openReal(
              t,
              Routes.bookReader(id, 1),
              size: const Size(320, 568),
              dark: dark,
              settings: AppSettings(fontScale: 1.6, bookPaper: paper),
              books: fakeAssets(tinyBooksWithLongBlocks()),
            );
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            var turns = 0;
            while (t.widget<NamoIconButton>(pageNext).onPressed != null) {
              await t.tap(pageNext);
              await t.pumpAndSettle();
              expect(t.takeException(), isNull, reason: 'after turn $turns');
              expect(++turns, lessThan(200));
            }
            // Turned through to the book's last page.
            expect(turns, greaterThan(0));
          },
        );
      }
    }
  }

  // The books scrolled, likewise: the verse, footnotes, list, table and
  // picture pages.
  for (final paper in BookPaper.values) {
    for (final dark in [false, true]) {
      for (final n in [3, 4, 7, 8]) {
        testWidgets(
          'Book reader in Scroll mode, page $n, does not overflow: '
          '320x568, text 1.6, ${paper.name} paper, ${dark ? 'dark' : 'light'}',
          (t) async {
            await openReal(
              t,
              Routes.bookReader(tinyBookNestedId, n),
              size: const Size(320, 568),
              dark: dark,
              settings: AppSettings(
                fontScale: 1.6,
                bookPaper: paper,
                bookReadingMode: BookReadingMode.scroll,
              ),
              books: fakeAssets(tinyBooksWithLongBlocks()),
            );
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            await scrollThrough(t);
          },
        );
      }
    }
  }

  for (final mode in BookReadingMode.values) {
    testWidgets('every tap target in ${mode.name} mode is at least 48 x 48', (
      t,
    ) async {
      await openReal(
        t,
        Routes.bookReader(tinyBookNestedId, 8),
        size: const Size(320, 568),
        settings: AppSettings(fontScale: 1.6, bookReadingMode: mode),
        books: fakeAssets(tinyBooksWithLongBlocks()),
      );
      await t.pumpAndSettle();
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      final keys = mode == BookReadingMode.pages
          ? ['book-page-prev', 'book-page-next']
          : ['book-prev', 'book-next'];
      for (final key in keys) {
        final size = t.getSize(find.byKey(ValueKey(key)));
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
      }
      expect(t.takeException(), isNull);
    });
  }

  // The Bana tab: first page, with a monk and a topic chosen, and with a
  // search, at the narrowest size and the wide one, text 1.6x, both themes.
  for (final size in const [Size(320, 568), Size(1280, 800)]) {
    for (final dark in [false, true]) {
      testWidgets('Bana tab does not overflow: ${size.width.round()}x'
          '${size.height.round()}, text 1.6x, ${dark ? 'dark' : 'light'}',
          (t) async {
        await openReal(
          t,
          Routes.bana,
          size: size,
          dark: dark,
          settings: const AppSettings(fontScale: 1.6),
          deviceTextScale: 1.6,
          overrides: banaOverrides(),
        );
        expect(t.takeException(), isNull);
        await scrollThrough(t);
        // The header scrolled out of the lazy list: back to the top.
        t
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await t.pumpAndSettle();
        await t.ensureVisible(find.byKey(const ValueKey('bana-speaker-b')));
        await t.tap(find.byKey(const ValueKey('bana-speaker-b')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('bana-search')),
            matching: find.byType(TextField),
          ),
          'single',
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await scrollThrough(t);
      });
    }
  }

  // The series page, with a last-opened part, at the narrowest size and the
  // wide one, text 1.6x, both themes.
  for (final size in const [Size(320, 568), Size(1280, 800)]) {
    for (final dark in [false, true]) {
      testWidgets('Bana series page does not overflow: ${size.width.round()}x'
          '${size.height.round()}, text 1.6x, ${dark ? 'dark' : 'light'}',
          (t) async {
        await openReal(
          t,
          Routes.banaSeries('s1'),
          size: size,
          dark: dark,
          settings: const AppSettings(fontScale: 1.6),
          deviceTextScale: 1.6,
          overrides: banaOverrides(),
          storeExtras: {
            banaLastPartKey: jsonEncode({'s1': 'v2'}),
          },
        );
        expect(t.takeException(), isNull);
        await scrollThrough(t);
        expect(t.takeException(), isNull);
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      });
    }
  }
}
