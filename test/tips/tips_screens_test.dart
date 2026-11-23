import 'package:buddhist_gatha/app.dart';
import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/audio/recording_store.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/design/widgets/surface_card.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/reader/reader_bottom_bar.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:buddhist_gatha/tips/tips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../support/fake_chant_player.dart';
import '../support/fake_recording_store.dart';

final _bubble = find.byKey(const ValueKey('tip-bubble'));
final _scrim = find.byKey(const ValueKey('tip-scrim'));
final _gotIt = find.byKey(const ValueKey('tip-got-it'));

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(NamoApp)));

/// The bubble on show is [tip]'s.
void _expectBubble(Tip tip) {
  expect(_bubble, findsOneWidget);
  expect(
    find.descendant(of: _bubble, matching: find.text(tip.title)),
    findsOneWidget,
  );
}

/// The hole in the scrim, on screen.
Rect _cutout(WidgetTester t) {
  final paint = t.widget<CustomPaint>(_scrim);
  final local = (paint.painter! as dynamic).cutout as Rect;
  return local.shift(t.getTopLeft(_scrim));
}

void _expectInCutout(WidgetTester t, Finder target) {
  final cutout = _cutout(t);
  final rect = t.getRect(target);
  expect(
    cutout.expandToInclude(rect),
    cutout,
    reason: '$rect should lie inside the cut-out $cutout',
  );
}

const _downloaded = RecordingStatus(
  availability: Availability.downloaded,
  bytes: 1000,
);
const _waiting = RecordingStatus(
  availability: Availability.waiting,
  bytes: 1000,
);

/// A pirith's player whose recording runs past its last phrase.
Future<FakeChantPlayer> _mangalaPlayer(WidgetTester t) async {
  final lib = await realLibrary(t);
  final recording = ContentAudioCatalogue(lib).recordingFor(mangalaReadingId)!;
  final times = recording.blockTimes.whereType<BlockTime>().toList();
  return FakeChantPlayer(length: times.last.end + const Duration(seconds: 2));
}

ChantStatus _chantStatus(WidgetTester t) =>
    t.widget<ReaderBottomBar>(find.byType(ReaderBottomBar)).chantState!.status;

const _recordingsSeen = {tipsKey: '{"seen":["recordings"]}'};

/// Home tall enough for My flows to be on screen.
const _tallHome = Size(390, 2800);

void main() {
  testWidgets('Home shows the Recordings tip once over the tab bar', (t) async {
    await openReal(t, Routes.home, library: await realLibrary(t), tips: true);
    _expectBubble(Tip.recordings);
    final settings = find.byKey(const ValueKey('nav-settings'));
    _expectInCutout(t, settings);
    // The bar is at the foot of the screen: the bubble sits above it.
    expect(t.getRect(_bubble).bottom, lessThan(t.getRect(settings).top));

    await t.tap(_scrim);
    await t.pumpAndSettle();
    expect(_bubble, findsNothing);
    final saved = _container(t).read(keyValueStoreProvider).read(tipsKey);
    expect(saved, '{"seen":["recordings"]}');

    await t.pumpWidget(const SizedBox());
    await openReal(
      t,
      Routes.home,
      library: await realLibrary(t),
      tips: true,
      storeExtras: {tipsKey: saved!},
    );
    expect(find.byKey(const ValueKey('nav-settings')), findsOneWidget);
    expect(_bubble, findsNothing);
  });

  testWidgets('on the web Home shows no Recordings tip', (t) async {
    await openReal(
      t,
      Routes.home,
      library: await realLibrary(t),
      tips: true,
      overrides: [tipsProvider.overrideWith(() => TipsController(web: true))],
    );
    expect(find.byKey(const ValueKey('nav-settings')), findsOneWidget);
    expect(_bubble, findsNothing);
  });

  testWidgets(
    'Home shows My flows pointing at the card, or at New flow when flows exist',
    (t) async {
      await openReal(
        t,
        Routes.home,
        size: _tallHome,
        library: await realLibrary(t),
        tips: true,
        storeExtras: _recordingsSeen,
      );
      _expectBubble(Tip.myFlows);
      _expectInCutout(
        t,
        find.ancestor(
          of: find.text('Make your own flow'),
          matching: find.byType(SurfaceCard),
        ),
      );

      await t.pumpWidget(const SizedBox());
      await openReal(
        t,
        Routes.home,
        size: _tallHome,
        library: await realLibrary(t),
        tips: true,
        storeExtras: {
          ...await realFlowsStore(t),
          ..._recordingsSeen,
        },
      );
      _expectBubble(Tip.myFlows);
      _expectInCutout(t, find.byKey(const ValueKey('new-flow')));
    },
  );

  testWidgets(
    'the recordings tip does not appear under a reader opened from Home',
    (t) async {
      await openReal(
        t,
        Routes.home,
        library: await silentWandanaLibrary(t),
        tips: true,
      );
      _expectBubble(Tip.recordings);

      _container(t)
          .read(routerProvider)
          .go(Routes.reader(realReadingId, from: ReaderFrom.home));
      await t.pumpAndSettle();
      expect(find.byType(ReaderBody), findsOneWidget);
      expect(find.text(Tip.recordings.title), findsNothing);
      _expectBubble(Tip.readerSettings);

      // Back takes the tip away first, and only then the reader.
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(_bubble, findsNothing);
      expect(find.byType(ReaderBody), findsOneWidget);

      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(ReaderBody), findsNothing);
      _expectBubble(Tip.recordings);
    },
  );

  testWidgets(
    'a gatha reader without chanting shows Languages and layout pointing at the settings button',
    (t) async {
      await openReal(
        t,
        Routes.reader(realReadingId),
        library: await silentWandanaLibrary(t),
        tips: true,
      );
      _expectBubble(Tip.readerSettings);
      _expectInCutout(t, find.byKey(const ValueKey('reader-settings')));

      await t.tap(_gotIt);
      await t.pumpAndSettle();
      // A gatha has no chanting: there is no second tip.
      expect(_bubble, findsNothing);
    },
  );

  testWidgets(
    'a pirith with its recording downloaded shows Languages and layout, then Scroll and Chant',
    (t) async {
      await openReal(
        t,
        Routes.reader(mangalaReadingId),
        library: await realLibrary(t),
        tips: true,
        recordingStore: FakeRecordingStore(),
      );
      _expectBubble(Tip.readerSettings);
      _expectInCutout(t, find.byKey(const ValueKey('reader-settings')));

      await t.tap(_gotIt);
      await t.pumpAndSettle();
      _expectBubble(Tip.scrollChant);
      _expectInCutout(t, find.byKey(const ValueKey('reader-autoscroll')));
      _expectInCutout(t, find.byKey(const ValueKey('chant-play')));

      await t.tap(_gotIt);
      await t.pumpAndSettle();
      expect(_bubble, findsNothing);
    },
  );

  testWidgets(
    'a pirith whose recording is still waiting shows only the first tip until the store marks it downloaded',
    (t) async {
      final store = FakeRecordingStore()..set(mangalaReadingId, _waiting);
      await openReal(
        t,
        Routes.reader(mangalaReadingId),
        library: await realLibrary(t),
        tips: true,
        recordingStore: store,
      );
      _expectBubble(Tip.readerSettings);
      await t.tap(_gotIt);
      await t.pumpAndSettle();
      expect(_bubble, findsNothing);

      store.set(mangalaReadingId, _downloaded);
      await t.pumpAndSettle();
      _expectBubble(Tip.scrollChant);
    },
  );

  testWidgets('no tip appears while chanting', (t) async {
    final player = await _mangalaPlayer(t);
    await openReal(
      t,
      Routes.reader(mangalaReadingId),
      library: await realLibrary(t),
      tips: true,
      player: player,
      storeExtras: {tipsKey: '{"seen":["readerSettings","scrollChant"]}'},
    );
    expect(_bubble, findsNothing);
    await t.tap(find.byKey(const ValueKey('chant-play')));
    await t.pump();
    expect(_chantStatus(t), ChantStatus.playing);

    // The tips are offered again (as Settings will) while the chant plays.
    _container(t).read(tipsProvider.notifier).resetAll();
    await t.pump();
    await t.pump();
    expect(_bubble, findsNothing);

    await t.tap(find.byKey(const ValueKey('chant-play')));
    await t.pumpAndSettle();
    expect(_chantStatus(t), ChantStatus.paused);
    _expectBubble(Tip.readerSettings);
    await t.tap(_gotIt);
    await t.pumpAndSettle();
    _expectBubble(Tip.scrollChant);
  });

  testWidgets('openChanting still works with tips on after dismissing', (
    t,
  ) async {
    final player = await _mangalaPlayer(t);
    await openReal(
      t,
      Routes.reader(mangalaReadingId),
      library: await realLibrary(t),
      tips: true,
      player: player,
    );
    _expectBubble(Tip.readerSettings);
    await t.tap(_gotIt);
    await t.pumpAndSettle();
    _expectBubble(Tip.scrollChant);
    await t.tap(_gotIt);
    await t.pumpAndSettle();
    expect(_bubble, findsNothing);

    await t.tap(find.byKey(const ValueKey('chant-play')));
    await t.pump();
    expect(_chantStatus(t), ChantStatus.playing);
    expect(player.state.status, ChantStatus.playing);
  });

  testWidgets('Back on Home with a tip up dismisses it and stays', (t) async {
    await openReal(t, Routes.home, library: await realLibrary(t), tips: true);
    _expectBubble(Tip.recordings);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_bubble, findsNothing);
    expect(
      _container(t).read(tipsProvider).seen,
      contains(Tip.recordings),
    );
    expect(find.byKey(const ValueKey('screen-home')), findsOneWidget);
  });

  testWidgets('Back on Home with My flows up dismisses it and stays', (
    t,
  ) async {
    await openReal(
      t,
      Routes.home,
      size: _tallHome,
      library: await realLibrary(t),
      tips: true,
      storeExtras: _recordingsSeen,
    );
    _expectBubble(Tip.myFlows);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_bubble, findsNothing);
    expect(_container(t).read(tipsProvider).seen, contains(Tip.myFlows));
    expect(find.byKey(const ValueKey('screen-home')), findsOneWidget);
  });

  testWidgets(
    'the Recordings tip points at the Settings rail destination on a wide screen',
    (t) async {
      await openReal(
        t,
        Routes.home,
        library: await realLibrary(t),
        tips: true,
        size: const Size(1280, 800),
      );
      _expectBubble(Tip.recordings);
      _expectInCutout(t, find.byKey(const ValueKey('nav-settings')));
    },
  );
  testWidgets(
    'a tab switched under the My flows tip takes it away unread; it comes back with the tab',
    (t) async {
      await openReal(
        t,
        Routes.home,
        size: _tallHome,
        library: await realLibrary(t),
        tips: true,
        storeExtras: _recordingsSeen,
      );
      _expectBubble(Tip.myFlows);

      // As a browser Back does: the address changes, no Back is heard.
      final router = _container(t).read(routerProvider);
      router.go(Routes.library);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
      expect(_bubble, findsNothing);
      expect(_container(t).read(tipsProvider).active, isNull);
      expect(_container(t).read(tipsProvider).seen, {Tip.recordings});

      router.go(Routes.home);
      await t.pumpAndSettle();
      _expectBubble(Tip.myFlows);
    },
  );

  testWidgets(
    'no My flows tip over the flow editor; it shows back on Home',
    (t) async {
      await openReal(
        t,
        Routes.home,
        size: _tallHome,
        library: await realLibrary(t),
        tips: true,
        storeExtras: {
          ...await realFlowsStore(t),
          tipsKey: '{"seen":["myFlows","recordings"]}',
        },
      );
      expect(_bubble, findsNothing);
      final router = _container(t).read(routerProvider);
      router.go(Routes.flowEditor('flow-1'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('screen-home')), findsNothing);

      // As Settings' "Show the tips again" does.
      _container(t).read(tipsProvider.notifier).resetAll();
      await t.pumpAndSettle();
      expect(_bubble, findsNothing);
      expect(_container(t).read(tipsProvider).active, isNull);

      // Back on Home: Recordings first (the tips were reset), then My flows.
      router.go(Routes.home);
      await t.pumpAndSettle();
      _expectBubble(Tip.recordings);
      await t.tap(_gotIt);
      await t.pumpAndSettle();
      _expectBubble(Tip.myFlows);
    },
  );

  testWidgets(
    'the Pirith & Gatha search opened with tips on has its focus, and no tip',
    (t) async {
      await openReal(
        t,
        Routes.librarySearch,
        library: await realLibrary(t),
        tips: true,
      );
      expect(_bubble, findsNothing);
      final field = t.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('library-search')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.focusNode.hasFocus, isTrue);
    },
  );

  testWidgets(
    'a reader tip waits while Scroll runs and shows once it is paused',
    (t) async {
      final player = await _mangalaPlayer(t);
      await openReal(
        t,
        Routes.reader(mangalaReadingId),
        library: await realLibrary(t),
        tips: true,
        player: player,
        storeExtras: {tipsKey: '{"seen":["readerSettings","scrollChant"]}'},
      );
      expect(_bubble, findsNothing);
      final scroll = find.byKey(const ValueKey('reader-autoscroll'));
      await t.tap(scroll);
      await t.pump();
      await t.pump(const Duration(seconds: 1));

      _container(t).read(tipsProvider.notifier).resetAll();
      await t.pump();
      await t.pump();
      expect(_bubble, findsNothing);

      // Paused, not stopped: the tips come.
      await t.tap(scroll);
      await t.pumpAndSettle();
      _expectBubble(Tip.readerSettings);
    },
  );
}
