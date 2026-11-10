import 'package:buddhist_gatha/audio/chant_player.dart';
import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/reader/chant_bar.dart';
import 'package:buddhist_gatha/reader/reader_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget bar, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: namoTheme(brightness),
      home: Scaffold(bottomNavigationBar: bar),
    );

ReaderBottomBar _bar(ChantState? state, {void Function(Duration)? onSeek}) =>
    ReaderBottomBar(
      onPrevious: () {},
      onNext: () {},
      onPlay: () {},
      chantState: state,
      onChantPlay: () {},
      onChantRestart: () {},
      onChantSeek: onSeek,
    );

void main() {
  testWidgets('without a chant state the bar is the plain one', (t) async {
    await t.pumpWidget(_app(_bar(null)));
    expect(find.byKey(const ValueKey('reader-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('chant-play')), findsNothing);
    expect(find.byKey(const ValueKey('chant-slider')), findsNothing);
    expect(find.byKey(const ValueKey('reader-autoscroll')), findsNothing);
  });

  testWidgets('five controls, left to right, with their names', (t) async {
    await t.pumpWidget(_app(_bar(const ChantState())));
    final keys = [
      'reader-prev',
      'reader-autoscroll',
      'chant-play',
      'chant-restart',
      'reader-next',
    ];
    var last = -1.0;
    for (final k in keys) {
      final f = find.byKey(ValueKey(k));
      expect(f, findsOneWidget, reason: k);
      final x = t.getCenter(f).dx;
      expect(x, greaterThan(last), reason: k);
      last = x;
    }
    expect(find.byTooltip('Previous section'), findsOneWidget);
    expect(find.byTooltip('Start auto-scroll'), findsOneWidget);
    expect(find.byTooltip('Play chanting'), findsOneWidget);
    expect(find.byTooltip('Restart chanting'), findsOneWidget);
    expect(find.byTooltip('Next section'), findsOneWidget);
    expect(t.getSize(find.byKey(const ValueKey('chant-play'))), const Size(56, 56));
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

  test('ChantSlider keeps the key the reader finds it by', () {
    const s = ChantSlider(
      position: Duration.zero,
      duration: null,
      onSeek: null,
    );
    expect(s.key, const ValueKey('chant-slider'));
  });
}
