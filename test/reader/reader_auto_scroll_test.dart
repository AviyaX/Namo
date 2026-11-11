import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reader_body.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';

const _start = 'Start auto-scroll';
const _pause = 'Pause auto-scroll';
const _resume = 'Resume auto-scroll';

Future<ProviderContainer> openAt(WidgetTester t, String location) async {
  await pumpApp(
    t,
    overrides: [
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
    ],
    location: location,
  );
  return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
}

/// Counts the writes of the reading place.
class _CountingStore extends InMemoryKeyValueStore {
  int positionWrites = 0;

  @override
  Future<void> write(String key, String value) {
    if (key == positionKey) positionWrites++;
    return super.write(key, value);
  }
}

ScrollController scroll(WidgetTester t) =>
    t.state<ReaderBodyState>(find.byType(ReaderBody)).controller;

final _play = find.byKey(const ValueKey('reader-play'));

/// The play button's label, which is also its tooltip.
String playLabel(WidgetTester t) => t.widget<Tooltip>(_play).message!;

/// The semantics node of the button [f] finds: the one its icon belongs to.
SemanticsNode buttonNode(WidgetTester t, Finder f) =>
    t.getSemantics(find.descendant(of: f, matching: find.byType(Icon)));

/// Lets [time] pass in 16-ms screen frames.
Future<void> runFor(WidgetTester t, Duration time) async {
  const frame = Duration(milliseconds: 16);
  for (var passed = Duration.zero; passed < time; passed += frame) {
    await t.pump(frame);
  }
}

const _second = Duration(seconds: 1);

/// How far the page moves in [time].
Future<double> distanceIn(WidgetTester t, Duration time) async {
  final before = scroll(t).offset;
  await runFor(t, time);
  return scroll(t).offset - before;
}

Future<void> startPlaying(WidgetTester t) async {
  expect(playLabel(t), _start);
  await t.tap(_play);
  await t.pump();
  expect(playLabel(t), _pause);
}

/// Opens the reader settings while the page keeps moving (a settle would
/// wait for the scrolling to end).
Future<void> openSheetWhileScrolling(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('reader-settings')));
  await runFor(t, const Duration(milliseconds: 500));
}

Future<void> tapInSheet(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump();
}

void main() {
  testWidgets('the play button starts scrolling and a touch on the text '
      'pauses it at once', (t) async {
    await openAt(t, Routes.reader('r1'));
    final size = t.getSize(_play);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(
      buttonNode(t, _play),
      isSemantics(tooltip: _start, isButton: true, isEnabled: true),
    );

    await startPlaying(t);
    await runFor(t, _second);
    final moved = scroll(t).offset;
    expect(moved, closeTo(22, 1));
    expect(buttonNode(t, _play), isSemantics(tooltip: _pause));

    final touch = await t.startGesture(t.getCenter(find.byType(ReaderBody)));
    await t.pump();
    expect(playLabel(t), _resume);
    expect(scroll(t).offset, moved);
    await runFor(t, _second);
    expect(scroll(t).offset, moved);
    await touch.up();
    await t.pump();

    // Resume carries on from where the page is.
    await t.tap(_play);
    await t.pump();
    expect(playLabel(t), _pause);
    expect(await distanceIn(t, _second), closeTo(22, 1));
    // The button pauses as well.
    await t.tap(_play);
    await t.pump();
    expect(playLabel(t), _resume);
    expect(await distanceIn(t, _second), 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('a mouse-wheel scroll pauses it', (t) async {
    await openAt(t, Routes.reader('r1'));
    await startPlaying(t);
    await runFor(t, _second);

    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await t.sendEventToBinding(
      mouse.hover(t.getCenter(find.byType(ReaderBody))),
    );
    await t.sendEventToBinding(mouse.scroll(const Offset(0, 50)));
    await t.pump();
    expect(playLabel(t), _resume);
    final after = scroll(t).offset;
    await runFor(t, _second);
    expect(scroll(t).offset, after);
    expect(t.takeException(), isNull);
  });

  testWidgets('next section does not pause auto-scroll', (t) async {
    await openAt(t, Routes.reader('r1'));
    await startPlaying(t);
    await runFor(t, const Duration(milliseconds: 500));

    await t.tap(find.byKey(const ValueKey('reader-next')));
    await t.pump();
    final s02 = t
        .state<ReaderBodyState>(find.byType(ReaderBody))
        .offsetOfSection('s02');
    expect(scroll(t).offset, closeTo(s02, 1));
    expect(playLabel(t), _pause);
    expect(await distanceIn(t, _second), closeTo(22, 1));
    expect(playLabel(t), _pause);

    await t.tap(find.byKey(const ValueKey('reader-prev')));
    await t.pump();
    expect(playLabel(t), _pause);
    expect(await distanceIn(t, _second), closeTo(22, 1));
    expect(t.takeException(), isNull);
  });

  testWidgets('speed can be changed from the sheet while scrolling', (t) async {
    final c = await openAt(t, Routes.reader('r1'));
    await startPlaying(t);
    await openSheetWhileScrolling(t);
    expect(find.text('Scroll speed'), findsOneWidget);
    expect(find.text('Custom'), findsNothing);

    await tapInSheet(t, find.text('Fast'));
    expect(c.read(settingsProvider).scrollSpeed, 36);
    expect(playLabel(t), _pause);
    expect(await distanceIn(t, _second), closeTo(36, 1));

    await tapInSheet(t, find.text('Slow'));
    expect(c.read(settingsProvider).scrollSpeed, 12);
    expect(await distanceIn(t, _second), closeTo(12, 1));

    // A slider value that is not a preset shows Custom.
    final slider = find.byKey(const ValueKey('reader-scroll-speed'));
    await t.ensureVisible(slider);
    await t.pump();
    await t.drag(slider, const Offset(1000, 0));
    await t.pump();
    expect(c.read(settingsProvider).scrollSpeed, 60);
    expect(find.text('Custom'), findsOneWidget);
    expect(playLabel(t), _pause);
    expect(
      await distanceIn(t, const Duration(milliseconds: 500)),
      closeTo(30, 1),
    );

    await tapInSheet(t, find.text('Normal'));
    expect(c.read(settingsProvider).scrollSpeed, 22);
    expect(find.text('Custom'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('the speed choices are labelled 48-px buttons that show which '
      'is on', (t) async {
    await openAt(t, Routes.reader('r1'));
    await t.tap(find.byKey(const ValueKey('reader-settings')));
    await t.pumpAndSettle();
    for (final label in ['Slow', 'Normal', 'Fast']) {
      final choice = find.text(label);
      await t.ensureVisible(choice);
      await t.pumpAndSettle();
      expect(
        t.getSemantics(choice),
        isSemantics(
          label: label,
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: label == 'Normal',
        ),
      );
      expect(
        t.getSize(find.bySemanticsLabel(label)).height,
        greaterThanOrEqualTo(48),
      );
    }
    expect(
      t.getSemantics(find.byKey(const ValueKey('reader-scroll-speed'))),
      isSemantics(label: 'Scroll speed', value: 'Normal'),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('Back to the beginning stops auto-scroll', (t) async {
    await openAt(t, Routes.reader('r1'));
    await startPlaying(t);
    await runFor(t, _second);
    await openSheetWhileScrolling(t);
    await tapInSheet(t, find.text('Back to the beginning'));
    await t.pumpAndSettle();
    expect(scroll(t).offset, 0);
    expect(playLabel(t), _start);
    expect(t.takeException(), isNull);
  });

  testWidgets('at the end the button offers to start again from the top', (
    t,
  ) async {
    await openAt(t, Routes.reader('r1', sectionId: 's03'));
    final c = scroll(t);
    c.jumpTo(c.position.maxScrollExtent - 5);
    await t.pump();
    await startPlaying(t);
    await runFor(t, _second);
    expect(c.offset, c.position.maxScrollExtent);
    expect(playLabel(t), _start);

    await t.tap(_play);
    await t.pump();
    expect(c.offset, 0);
    expect(playLabel(t), _pause);
    expect(await distanceIn(t, _second), closeTo(22, 1));
    expect(t.takeException(), isNull);
  });

  testWidgets('while the page keeps moving its place is saved every few '
      'seconds, and once more when it stops', (t) async {
    final store = _CountingStore();
    await pumpApp(
      t,
      overrides: [
        contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
        keyValueStoreProvider.overrideWithValue(store),
      ],
      location: Routes.reader('r1'),
      // A short window, so the page has room to move for ten seconds.
      size: const Size(390, 400),
    );
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    expect(scroll(t).position.maxScrollExtent, greaterThan(250));
    expect(store.positionWrites, 0);

    await startPlaying(t);
    await runFor(t, _second);
    expect(store.positionWrites, 0);
    await runFor(t, const Duration(seconds: 2));
    expect(store.positionWrites, 1);
    final first = c.read(positionProvider).byReading['r1']!.progress;
    expect(first, greaterThan(0));

    await runFor(t, const Duration(seconds: 3));
    expect(store.positionWrites, 2);
    expect(
      c.read(positionProvider).byReading['r1']!.progress,
      greaterThan(first),
    );
    expect(playLabel(t), _pause);

    // Pausing saves once, after the page is still.
    await t.tap(_play);
    await t.pump();
    await runFor(t, const Duration(seconds: 3));
    expect(store.positionWrites, 3);
    expect(t.takeException(), isNull);
  });

  testWidgets('going to the background pauses it', (t) async {
    await openAt(t, Routes.reader('r1'));
    await startPlaying(t);
    await runFor(t, _second);
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await t.pump();
    expect(playLabel(t), _resume);
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(await distanceIn(t, _second), 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('leaving the reader while scrolling stops the ticker', (t) async {
    final c = await openAt(t, Routes.reader('r1'));
    await startPlaying(t);
    await runFor(t, _second);
    c.read(routerProvider).go(Routes.contents('r1'));
    // Settles only once nothing asks for more frames.
    await t.pumpAndSettle();
    expect(find.byType(ReaderBody), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('changing text size while scrolling keeps the verse and keeps '
      'scrolling', (t) async {
    final container = await openAt(t, Routes.reader('r1'));
    final c = scroll(t);
    double fromTop(String key) =>
        t.getTopLeft(find.byKey(ValueKey(key))).dy -
        t.getTopLeft(find.byType(ReaderBody)).dy;
    // Put a verse at the top, then start from there.
    c.jumpTo(c.offset + fromTop('verse-s01-v2-pi'));
    await t.pump();
    await startPlaying(t);
    await runFor(t, const Duration(milliseconds: 500));
    final into = -fromTop('verse-s01-v2-pi');
    expect(into, closeTo(11, 1));
    final before = c.offset;

    container.read(settingsProvider.notifier).setFontScale(1.6);
    await t.pump();
    await t.pump();
    expect(c.offset, isNot(closeTo(before, 2)));
    expect(playLabel(t), _pause);
    // Still inside the same verse, as far into it in proportion.
    final verse = t.getSize(find.byKey(const ValueKey('verse-s01-v2-pi')));
    final nowInto = -fromTop('verse-s01-v2-pi');
    expect(nowInto, greaterThan(into));
    expect(nowInto, lessThan(verse.height));
    expect(await distanceIn(t, _second), closeTo(22, 1));
    expect(playLabel(t), _pause);
    expect(t.takeException(), isNull);
  });
}
