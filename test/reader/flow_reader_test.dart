import 'dart:convert';

import 'package:buddhist_gatha/audio/audio_controls.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/design/widgets/not_found.dart';
import 'package:buddhist_gatha/design/widgets/pressable.dart';
import 'package:buddhist_gatha/flows/flows.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../support/test_content.dart';

const _names = {'flow-1': 'Flow one', 'flow-2': 'Flow two'};

FlowRef _ref(String readingId, String sectionId) =>
    FlowRef(readingId: readingId, sectionId: sectionId);

/// The stored value of [flows] (id → sections), named from [_names].
String _stored(Map<String, List<FlowRef>> flows) => jsonEncode(
  FlowsState(
    flows: [
      for (final e in flows.entries)
        Flow(id: e.key, name: _names[e.key]!, sections: e.value),
    ],
    nextNumber: flows.length + 1,
  ).toJson(),
);

Future<void> _open(
  WidgetTester t,
  String location,
  Map<String, List<FlowRef>> flows, {
  Library? library,
  bool audio = false,
  AppSettings settings = const AppSettings(),
  Map<String, String> extras = const {},
}) => openReal(
  t,
  location,
  library: library ?? testLibrary(),
  audio: audio,
  settings: settings,
  storeExtras: {flowsKey: _stored(flows), ...extras},
);

/// The placeholder reading of [testLibrary] and the bundled Pirith.
Future<Library> _withPirith(WidgetTester t) async {
  final real = await realLibrary(t);
  return Library(
    categories: [
      testLibrary().categories.first,
      real.category(pirithCategoryId)!,
    ],
  );
}

/// The two pirith with the most blocks, longest first: each is many screens
/// long, so the other's heading can be brought to the top.
Future<List<Reading>> _longPirith(WidgetTester t) async {
  final readings = [
    ...(await realLibrary(t)).category(pirithCategoryId)!.readings,
  ]..sort((a, b) => b.sections[0].verses.length - a.sections[0].verses.length);
  return readings.take(2).toList();
}

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

ScrollController _scroll(WidgetTester t) =>
    t.state<ReaderBodyState>(find.byType(ReaderBody)).controller;

Finder _heading(String flowSectionId) =>
    find.byKey(ValueKey('heading-$flowSectionId'));

final _prev = find.byKey(const ValueKey('reader-prev'));
final _next = find.byKey(const ValueKey('reader-next'));

bool _enabled(WidgetTester t, Finder f) =>
    t.widget<NamoIconButton>(f).onPressed != null;

/// Whether [flowSectionId]'s heading is at the top of the text.
void _expectAtTop(WidgetTester t, String flowSectionId) {
  expect(_heading(flowSectionId), findsOneWidget);
  expect(
    t.getTopLeft(_heading(flowSectionId)).dy,
    closeTo(t.getTopLeft(find.byType(ReaderBody)).dy, 1),
  );
}

Future<void> _go(WidgetTester t, String location) async {
  _container(t).read(routerProvider).go(location);
  await t.pumpAndSettle();
}

/// Puts [flowSectionId]'s heading at the top and waits for the place to be
/// saved.
Future<void> _scrollTo(WidgetTester t, String flowSectionId) async {
  final body = t.state<ReaderBodyState>(find.byType(ReaderBody));
  _scroll(t).jumpTo(body.offsetOfSection(flowSectionId));
  await t.pump(const Duration(milliseconds: 600));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('the title is the flow\'s name and the headings are in flow '
      'order, numbered 1, 2, 3', (t) async {
    await _open(t, Routes.reader('flow-1'), {
      'flow-1': [_ref('r1', 's03'), _ref('r1', 's01'), _ref('r1', 's02')],
    });
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('reader-top-bar')),
        matching: find.text('Flow one'),
      ),
      findsOneWidget,
    );
    final ids = ['r1~s03', 'r1~s01', 'r1~s02'];
    final headings = ['heading 3', 'heading 1', 'heading 2'];
    for (var i = 0; i < 3; i++) {
      expect(
        find.descendant(of: _heading(ids[i]), matching: find.text('${i + 1}')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _heading(ids[i]), matching: find.text(headings[i])),
        findsOneWidget,
      );
    }
    expect(
      t.getTopLeft(_heading(ids[0])).dy,
      lessThan(t.getTopLeft(_heading(ids[1])).dy),
    );
    expect(
      t.getTopLeft(_heading(ids[1])).dy,
      lessThan(t.getTopLeft(_heading(ids[2])).dy),
    );
  });

  for (final audio in [false, true]) {
    testWidgets('no favourite button and no recording, with a pirith in the '
        'flow (${audio ? 'every reading has a tone' : 'its own recording'})', (
      t,
    ) async {
      final pirith = (await realLibrary(t)).reading(mangalaReadingId)!;
      expect(pirith.audio?.blockTimes, isNotEmpty);
      await _open(
        t,
        Routes.reader('flow-1'),
        {
          'flow-1': [_ref('r1', 's01'), _ref(pirith.id, 'p')],
        },
        library: await _withPirith(t),
        audio: audio,
      );
      expect(_heading('${pirith.id}~p'), findsOneWidget);
      expect(find.byTooltip('Add to favourites'), findsNothing);
      expect(find.byTooltip('Remove from favourites'), findsNothing);
      expect(find.byKey(const ValueKey('chant-play')), findsNothing);
      expect(find.byKey(const ValueKey('chant-slider')), findsNothing);
      expect(find.byKey(const ValueKey('follow-chanting')), findsNothing);
      expect(find.byType(AudioControls), findsNothing);
      expect(
        find.text('Chanted by Ven. Nauyane Ariyadhamma Thero'),
        findsNothing,
      );
    });
  }

  testWidgets('a flow of two pirith: Next and Previous move between its '
      'sections, with the section tooltips', (t) async {
    final [a, b] = await _longPirith(t);
    await _open(t, Routes.reader('flow-1'), {
      'flow-1': [_ref(a.id, 'p'), _ref(b.id, 'p')],
    }, library: await _withPirith(t));
    expect(find.byKey(const ValueKey('chant-play')), findsNothing);
    expect(find.byTooltip('Add to favourites'), findsNothing);
    expect(find.byTooltip('Next pirith'), findsNothing);
    expect(find.byTooltip('Previous pirith'), findsNothing);
    expect(t.widget<NamoIconButton>(_prev).tooltip, 'Previous section');
    expect(t.widget<NamoIconButton>(_next).tooltip, 'Next section');
    _expectAtTop(t, '${a.id}~p');
    expect(_enabled(t, _next), isTrue);

    await t.tap(_next);
    await t.pumpAndSettle();
    expect(find.byType(ReaderBody), findsOneWidget);
    _expectAtTop(t, '${b.id}~p');
    expect(_enabled(t, _prev), isTrue);

    await t.tap(_prev);
    await t.pumpAndSettle();
    expect(_scroll(t).offset, 0);
    _expectAtTop(t, '${a.id}~p');
    expect(t.takeException(), isNull);
  });

  testWidgets('a bookmark in a flow is the original section\'s', (t) async {
    await _open(
      t,
      Routes.reader('flow-1'),
      {
        'flow-1': [_ref('r1', 's01'), _ref('r1', 's02')],
      },
      extras: {
        savedKey: jsonEncode(
          const SavedState(
            bookmarks: [Bookmark(readingId: 'r1', sectionId: 's01')],
          ).toJson(),
        ),
      },
    );
    // Made on the original, on in the flow.
    expect(
      find.descendant(
        of: _heading('r1~s01'),
        matching: find.byTooltip('Remove bookmark'),
      ),
      findsOneWidget,
    );

    await t.tap(
      find.descendant(
        of: _heading('r1~s02'),
        matching: find.byTooltip('Bookmark this section'),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: _heading('r1~s02'),
        matching: find.byTooltip('Remove bookmark'),
      ),
      findsOneWidget,
    );
    final stored = SavedState.fromJson(
      jsonDecode(_container(t).read(keyValueStoreProvider).read(savedKey)!),
    );
    expect(stored.bookmarks, [
      const Bookmark(readingId: 'r1', sectionId: 's02'),
      const Bookmark(readingId: 'r1', sectionId: 's01'),
    ]);
  });

  testWidgets('each flow keeps its own place, filed under its id', (t) async {
    await _open(t, Routes.reader('flow-1'), {
      'flow-1': [_ref('r1', 's01'), _ref('r1', 's02'), _ref('r1', 's03')],
      'flow-2': [_ref('r1', 's02'), _ref('r1', 's03')],
    });
    await _scrollTo(t, 'r1~s03');
    await _go(t, Routes.library);

    await _go(t, Routes.reader('flow-2'));
    expect(_scroll(t).offset, 0);
    await _scrollTo(t, 'r1~s03');
    await _go(t, Routes.library);

    await _go(t, Routes.reader('flow-1'));
    _expectAtTop(t, 'r1~s03');
    expect(_scroll(t).offset, greaterThan(0));

    final byReading = PositionState.fromJson(
      jsonDecode(_container(t).read(keyValueStoreProvider).read(positionKey)!),
    ).byReading;
    expect(byReading.keys, containsAll(['flow-1', 'flow-2']));
    expect(byReading['flow-1']!.position.sectionId, 'r1~s03');
    expect(byReading.keys.where((k) => !k.startsWith('flow-')), isEmpty);
  });

  testWidgets('the remembered section moved opens there; removed opens at '
      'the top', (t) async {
    await _open(t, Routes.reader('flow-1'), {
      'flow-1': [_ref('r1', 's01'), _ref('r1', 's02'), _ref('r1', 's03')],
    });
    await _scrollTo(t, 'r1~s03');
    await _go(t, Routes.library);

    _container(t).read(flowsProvider.notifier).move('flow-1', 2, 1);
    await _go(t, Routes.reader('flow-1'));
    _expectAtTop(t, 'r1~s03');
    expect(_scroll(t).offset, greaterThan(0));
    await _go(t, Routes.library);

    _container(t)
        .read(flowsProvider.notifier)
        .remove('flow-1', _ref('r1', 's03'));
    await _go(t, Routes.reader('flow-1'));
    expect(_heading('r1~s03'), findsNothing);
    expect(_scroll(t).offset, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('an unknown flow is not found', (t) async {
    await _open(t, Routes.reader('flow-99'), {
      'flow-1': [_ref('r1', 's01')],
    });
    expect(find.byType(NotFoundScreen), findsOneWidget);
    expect(find.byType(ReaderBody), findsNothing);
  });

  for (final dead in [false, true]) {
    testWidgets('a flow with no ${dead ? 'live ' : ''}sections says so, with '
        'nothing to press in the bar', (t) async {
      await _open(t, Routes.reader('flow-1'), {
        'flow-1': [if (dead) _ref('r1', 'gone')],
      });
      expect(find.byType(NotFoundScreen), findsNothing);
      expect(find.text('This flow has no sections yet.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reader-top-bar')),
          matching: find.text('Flow one'),
        ),
        findsOneWidget,
      );
      expect(_enabled(t, _prev), isFalse);
      expect(_enabled(t, _next), isFalse);
      expect(
        t
            .widget<Pressable>(
              find.descendant(
                of: find.byKey(const ValueKey('reader-play')),
                matching: find.byType(Pressable),
              ),
            )
            .onTap,
        isNull,
      );
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('a mixed flow, section by section: the same section is at the '
      'top after the languages change', (t) async {
    final [a, b] = await _longPirith(t);
    await _open(
      t,
      Routes.reader('flow-1'),
      {
        'flow-1': [_ref(a.id, 'p'), _ref('r1', 's02'), _ref(b.id, 'p')],
      },
      library: await _withPirith(t),
      settings: const AppSettings(layout: TwoLanguageLayout.section),
    );
    await t.tap(_next);
    await t.pumpAndSettle();
    _expectAtTop(t, 'r1~s02');

    final settings = _container(t).read(settingsProvider.notifier);
    settings.toggleLanguage(ReadingLanguage.sinhala);
    await t.pumpAndSettle();
    _expectAtTop(t, 'r1~s02');

    settings.toggleLanguage(ReadingLanguage.english);
    await t.pumpAndSettle();
    _expectAtTop(t, 'r1~s02');
    expect(t.takeException(), isNull);
  });
}
