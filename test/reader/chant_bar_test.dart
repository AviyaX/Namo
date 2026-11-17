import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/audio/recording_store.dart';
import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/reader/auto_scroll.dart';
import 'package:buddhist_gatha/reader/chant_bar.dart';
import 'package:buddhist_gatha/reader/reader_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

Widget _app(Widget bar, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: namoTheme(brightness),
      home: Scaffold(bottomNavigationBar: bar),
    );

ReaderBottomBar _bar(
  ChantState? state, {
  void Function(Duration)? onSeek,
  double chantSpeed = 1.0,
  VoidCallback? onChantSpeed,
}) =>
    ReaderBottomBar(
      onPrevious: () {},
      onNext: () {},
      onPlay: () {},
      chantState: state,
      onChantPlay: () {},
      onChantRestart: () {},
      onChantSeek: onSeek,
      chantSpeed: chantSpeed,
      onChantSpeed: onChantSpeed,
    );

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('without a chant state the bar is the plain one', (t) async {
    await t.pumpWidget(_app(_bar(null)));
    expect(find.byKey(const ValueKey('reader-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('chant-play')), findsNothing);
    expect(find.byKey(const ValueKey('chant-slider')), findsNothing);
    expect(find.byKey(const ValueKey('reader-autoscroll')), findsNothing);
  });

  testWidgets('two rows: restart, slider, speed above; prev, Scroll, Chant, next below', (t) async {
    await t.pumpWidget(_app(_bar(const ChantState())));
    double x(String k) => t.getCenter(find.byKey(ValueKey(k))).dx;
    double y(String k) => t.getCenter(find.byKey(ValueKey(k))).dy;
    expect(x('chant-restart'), lessThan(x('chant-slider')));
    expect(x('chant-slider'), lessThan(x('chant-speed')));
    expect(x('reader-prev'), lessThan(x('reader-autoscroll')));
    expect(x('reader-autoscroll'), lessThan(x('chant-play')));
    expect(x('chant-play'), lessThan(x('reader-next')));
    expect(y('chant-slider'), lessThan(y('chant-play')));
    for (final tip in ['Previous section', 'Start auto-scroll', 'Play chanting', 'Restart chanting', 'Next section']) {
      expect(find.byTooltip(tip), findsOneWidget, reason: tip);
    }
    expect(find.text('Scroll'), findsOneWidget);
    expect(find.text('Chant'), findsOneWidget);
    expect(find.text('1×'), findsOneWidget);
    expect(t.getSize(find.byKey(const ValueKey('chant-play'))), const Size(56, 56));
    final scroll = find.descendant(of: find.byKey(const ValueKey('reader-autoscroll')), matching: find.byType(DecoratedBox)).first;
    expect(t.getSize(scroll), const Size(56, 56));
  });

  testWidgets('previous and next are centred on the round buttons', (t) async {
    await t.pumpWidget(_app(_bar(const ChantState())));
    double y(String k) => t.getCenter(find.byKey(ValueKey(k))).dy;
    expect(y('reader-prev'), closeTo(y('chant-play'), 0.5));
    expect(y('reader-next'), closeTo(y('chant-play'), 0.5));
  });

  testWidgets('the speed button keeps its width as the speed changes', (t) async {
    double width() => t.getSize(find.byKey(const ValueKey('chant-speed'))).width;
    await t.pumpWidget(_app(_bar(const ChantState(), chantSpeed: 1.0)));
    final one = width();
    await t.pumpWidget(_app(_bar(const ChantState(), chantSpeed: 0.75)));
    expect(width(), one);
  });

  testWidgets('the Scroll button fills while auto-scroll runs', (t) async {
    await t.pumpWidget(_app(ReaderBottomBar(onPrevious: () {}, onNext: () {}, onPlay: () {},
        autoScroll: AutoScrollStatus.running, chantState: const ChantState(),
        onChantPlay: () {}, onChantRestart: () {})));
    expect(find.byTooltip('Pause auto-scroll'), findsOneWidget);
    final context = t.element(find.byKey(const ValueKey('reader-autoscroll')));
    final box = t.widget<DecoratedBox>(find.descendant(
        of: find.byKey(const ValueKey('reader-autoscroll')), matching: find.byType(DecoratedBox)).first);
    expect((box.decoration as BoxDecoration).color, NamoPalette.of(context).sage);
  });

  testWidgets('the speed button shows the speed, names the next one and calls back', (t) async {
    var taps = 0;
    await t.pumpWidget(_app(_bar(const ChantState(), chantSpeed: 1.25, onChantSpeed: () => taps++)));
    final handle = t.ensureSemantics();
    expect(find.text('1.25×'), findsOneWidget);
    final node = t.getSemantics(find.byKey(const ValueKey('chant-speed')));
    expect(node.label, 'Chanting speed 1.25×');
    expect(node.hint, 'Tap for 1.5×');
    await t.tap(find.byKey(const ValueKey('chant-speed')));
    expect(taps, 1);
    handle.dispose();
  });

  test('speed labels', () {
    expect([0.75, 1.0, 1.25, 1.5].map(speedLabel), ['0.75×', '1×', '1.25×', '1.5×']);
  });

  testWidgets('playing shows Pause chanting; loading shows a spinner', (
    t,
  ) async {
    await t.pumpWidget(
      _app(_bar(const ChantState(status: ChantStatus.playing))),
    );
    expect(find.byTooltip('Pause chanting'), findsOneWidget);
    await t.pumpWidget(
      _app(_bar(const ChantState(status: ChantStatus.loading))),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('loading under reduced motion shows a still ring', (t) async {
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(_bar(const ChantState(status: ChantStatus.loading))),
      ),
    );
    final ring = t.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, 1);
    await t.pumpWidget(
      _app(_bar(const ChantState(status: ChantStatus.loading))),
    );
    expect(
      t.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator))
          .value,
      isNull,
    );
  });

  testWidgets('the slider is named, valued, and disabled until loaded', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(_app(_bar(const ChantState())));
    expect(t.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    await t.pumpWidget(
      _app(
        _bar(
          const ChantState(
            status: ChantStatus.paused,
            position: Duration(seconds: 5),
            duration: Duration(seconds: 20),
          ),
          onSeek: (_) {},
        ),
      ),
    );
    expect(find.text('0:05'), findsOneWidget);
    expect(find.text('0:20'), findsOneWidget);
    // The name and the value are one spoken control: the slider's node is
    // merged up into the one that carries the name.
    final tree = t.renderObject(find.byType(Scaffold)).owner!.semanticsOwner!.rootSemanticsNode!
        .toStringDeep();
    expect(tree, contains('label: "Chanting position"'));
    expect(tree, contains('value: "0:05 of 0:20"'));
    expect(tree, contains('merged up'));
    handle.dispose();
  });

  testWidgets('a failed load puts the message in the slider\'s place', (
    t,
  ) async {
    await t.pumpWidget(
      _app(_bar(const ChantState(status: ChantStatus.failed))),
    );
    expect(find.text('The recording could not be played.'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byKey(const ValueKey('chant-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('chant-speed')), findsOneWidget);
    expect(find.byKey(const ValueKey('chant-restart')), findsOneWidget);
  });

  testWidgets('dragging seeks once, when it ends', (t) async {
    final seeks = <Duration>[];
    await t.pumpWidget(
      _app(
        _bar(
          const ChantState(
            status: ChantStatus.paused,
            duration: Duration(seconds: 20),
          ),
          onSeek: seeks.add,
        ),
      ),
    );
    final box = find.byType(Slider);
    final g = await t.startGesture(t.getCenter(box));
    await g.moveBy(const Offset(5, 0));
    await t.pump();
    expect(seeks, isEmpty);
    await g.up();
    await t.pump();
    expect(seeks, hasLength(1));
    expect(seeks.single.inSeconds, inInclusiveRange(8, 12));
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'fits 320 wide, dark $dark, text $scale, with 48 px targets',
        (t) async {
          t.view.physicalSize = const Size(320, 568);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await t.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(scale),
              ),
              child: _app(
                _bar(
                  const ChantState(
                    status: ChantStatus.paused,
                    duration: Duration(seconds: 20),
                  ),
                  onSeek: (_) {},
                ),
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
            ),
          );
          expect(t.takeException(), isNull);
          for (final k in [
            'reader-prev',
            'reader-autoscroll',
            'chant-play',
            'chant-restart',
            'chant-speed',
            'reader-next',
          ]) {
            final s = t.getSize(find.byKey(ValueKey(k)));
            expect(s.width, greaterThanOrEqualTo(48), reason: k);
            expect(s.height, greaterThanOrEqualTo(48), reason: k);
          }
        },
      );
    }
  }

  testWidgets('the coverage line sits where the slider goes until the chant '
      'starts', (t) async {
    ReaderBottomBar bar(ChantState state, {String? coverage}) =>
        ReaderBottomBar(
          onPrevious: () {},
          onNext: () {},
          onPlay: () {},
          chantState: state,
          onChantPlay: () {},
          onChantRestart: () {},
          onChantSeek: (_) {},
          coverage: coverage,
        );
    final coverage = find.byKey(const ValueKey('chant-coverage'));
    final slider = find.byKey(const ValueKey('chant-slider'));
    const line = 'Chant plays 2 of 5 sections';

    await t.pumpWidget(_app(bar(const ChantState(), coverage: line)));
    expect(t.widget<Text>(coverage).data, line);
    expect(slider, findsNothing);
    double x(Finder f) => t.getCenter(f).dx;
    expect(x(find.byKey(const ValueKey('chant-restart'))),
        lessThan(x(coverage)));
    expect(x(coverage), lessThan(x(find.byKey(const ValueKey('chant-speed')))));
    final live = find.ancestor(
      of: coverage,
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      ),
    );
    expect(live, findsWidgets);

    for (final status in [
      ChantStatus.loading,
      ChantStatus.playing,
      ChantStatus.paused,
    ]) {
      await t.pumpWidget(
        _app(bar(ChantState(status: status), coverage: line)),
      );
      expect(coverage, findsNothing, reason: '$status');
      expect(slider, findsOneWidget, reason: '$status');
    }
    await t.pumpWidget(
      _app(bar(const ChantState(status: ChantStatus.failed), coverage: line)),
    );
    expect(coverage, findsNothing);
    expect(find.text('The recording could not be played.'), findsOneWidget);

    // A reading that chants all its sections has no line.
    await t.pumpWidget(_app(bar(const ChantState())));
    expect(coverage, findsNothing);
    expect(slider, findsOneWidget);
  });

  test('ChantSlider keeps the key the reader finds it by', () {
    const s = ChantSlider(
      position: Duration.zero,
      duration: null,
      onSeek: null,
    );
    expect(s.key, const ValueKey('chant-slider'));
  });

  test('recordingLine says where the recording is', () {
    const bytes = 1046598;
    expect(
      recordingLine(
        const RecordingStatus(availability: Availability.waiting, bytes: bytes),
      ),
      'Waiting to download · 1.0 MB',
    );
    expect(
      recordingLine(
        const RecordingStatus(
          availability: Availability.notDownloaded,
          bytes: bytes,
        ),
      ),
      'Recording not downloaded · 1.0 MB',
    );
    expect(
      recordingLine(
        const RecordingStatus(
          availability: Availability.downloading,
          progress: 0.426,
          bytes: bytes,
        ),
      ),
      'Downloading recording… 42%',
    );
    expect(
      recordingLine(
        const RecordingStatus(
          availability: Availability.failed,
          reason: notOnServerMessage,
          bytes: bytes,
        ),
      ),
      notOnServerMessage,
    );
    expect(
      recordingLine(
        const RecordingStatus(availability: Availability.failed, bytes: bytes),
      ),
      connectionMessage,
    );
    expect(
      recordingLine(
        const RecordingStatus(
          availability: Availability.downloaded,
          bytes: bytes,
        ),
      ),
      '',
    );
  });
}
