import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/widgets/pressable.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:buddhist_gatha/tips/tip_anchor.dart';
import 'package:buddhist_gatha/tips/tip_host.dart';
import 'package:buddhist_gatha/tips/tips.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _bubble = ValueKey('tip-bubble');
const _gotIt = ValueKey('tip-got-it');
const _scrim = ValueKey('tip-scrim');
const _target = ValueKey('target');

final _bubbleFinder = find.byKey(_bubble);

/// Counts taps on the control the tip points at.
var taps = 0;

Widget _control({Key key = _target, double width = 120}) => Pressable(
      key: key,
      onTap: () => taps++,
      child: SizedBox(width: width, height: 48),
    );

/// A page whose one control is placed at [alignment].
Widget _hostPage({
  Alignment alignment = Alignment.topCenter,
  List<Tip> tips = const [Tip.myFlows],
}) =>
    TipHost(
      tipsFor: () => tips,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 100),
          child: Align(
            alignment: alignment,
            child: TipAnchor(tip: Tip.myFlows, child: _control()),
          ),
        ),
      ),
    );

ProviderContainer _container({bool allowed = true}) {
  final c = ProviderContainer(overrides: [
    keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
    tipsAllowedProvider.overrideWithValue(allowed),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<ProviderContainer> _pump(
  WidgetTester t,
  Widget home, {
  bool allowed = true,
  Size size = const Size(400, 800),
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  taps = 0;
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = _container(allowed: allowed);
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      theme: namoTheme(Brightness.light),
      navigatorKey: navigatorKey,
      home: home,
    ),
  ));
  return c;
}

Rect _rectOf(WidgetTester t, Key key) => t.getRect(find.byKey(key));

void main() {
  testWidgets(
      'a due tip appears after the first frame with a bubble below the control',
      (t) async {
    final c = await _pump(t, _hostPage());
    await t.pump();
    expect(_bubbleFinder, findsOneWidget);
    expect(c.read(tipsProvider).active, Tip.myFlows);
    await t.pumpAndSettle();
    expect(find.text(Tip.myFlows.title), findsOneWidget);
    expect(find.text(Tip.myFlows.body), findsOneWidget);
    expect(_rectOf(t, _bubble).top, greaterThan(_rectOf(t, _target).bottom));
  });

  testWidgets('near the bottom the bubble goes above', (t) async {
    await _pump(t, _hostPage(alignment: Alignment.bottomCenter));
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsOneWidget);
    expect(_rectOf(t, _bubble).bottom, lessThan(_rectOf(t, _target).top));
  });

  testWidgets('at 320 px the bubble stays inside the screen', (t) async {
    await _pump(
      t,
      _hostPage(alignment: Alignment.centerRight),
      size: const Size(320, 640),
    );
    await t.pumpAndSettle();
    final b = _rectOf(t, _bubble);
    expect(b.left, greaterThanOrEqualTo(16));
    expect(b.top, greaterThanOrEqualTo(16));
    expect(b.right, lessThanOrEqualTo(320 - 16));
    expect(b.bottom, lessThanOrEqualTo(640 - 16));
  });

  testWidgets('a tall bubble over a control near the top stays inside the screen',
      (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(
      t,
      TipHost(
        tipsFor: () => [Tip.myFlows],
        child: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: TipAnchor(tip: Tip.myFlows, child: _control()),
          ),
        ),
      ),
      size: const Size(320, 568),
    );
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsOneWidget);
    final b = _rectOf(t, _bubble);
    expect(b.left, greaterThanOrEqualTo(16));
    expect(b.top, greaterThanOrEqualTo(16));
    expect(b.right, lessThanOrEqualTo(320 - 16));
    expect(b.bottom, lessThanOrEqualTo(568 - 16));
  });

  testWidgets('two anchors are covered by one cut-out', (t) async {
    await _pump(
      t,
      TipHost(
        tipsFor: () => [Tip.scrollChant],
        child: Scaffold(
          body: Stack(children: [
            Positioned(
              left: 40,
              top: 200,
              child: TipAnchor(
                tip: Tip.scrollChant,
                child: _control(key: const ValueKey('scroll'), width: 80),
              ),
            ),
            Positioned(
              right: 40,
              top: 200,
              child: TipAnchor(
                tip: Tip.scrollChant,
                child: _control(key: const ValueKey('chant'), width: 80),
              ),
            ),
          ]),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsOneWidget);
    final a = _rectOf(t, const ValueKey('scroll'));
    final b = _rectOf(t, const ValueKey('chant'));
    final layout = t.widget<CustomSingleChildLayout>(
      find.byType(CustomSingleChildLayout),
    );
    final cutout = (layout.delegate as BubbleLayoutDelegate).cutout;
    expect(cutout, cutoutFor(unionRect([a, b])));
    expect(cutout.expandToInclude(a), cutout);
    expect(cutout.expandToInclude(b), cutout);
    expect(
      _rectOf(t, _bubble).center.dx,
      moreOrLessEquals(cutout.center.dx, epsilon: 0.5),
    );
  });

  testWidgets('a tap on the scrim dismisses and marks seen', (t) async {
    final semantics = t.ensureSemantics();
    final c = await _pump(t, _hostPage());
    await t.pumpAndSettle();
    expect(find.byKey(_scrim), findsOneWidget);
    expect(find.bySemanticsLabel('Dismiss tip'), findsOneWidget);
    await t.tapAt(const Offset(4, 4));
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsNothing);
    expect(find.byKey(_scrim), findsNothing);
    expect(c.read(tipsProvider).active, isNull);
    expect(c.read(tipsProvider).seen, {Tip.myFlows});
    semantics.dispose();
  });

  testWidgets('Got it dismisses and marks seen', (t) async {
    final c = await _pump(t, _hostPage());
    await t.pumpAndSettle();
    expect(find.text('Got it'), findsOneWidget);
    await t.tap(find.byKey(_gotIt));
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsNothing);
    expect(c.read(tipsProvider).seen, {Tip.myFlows});
  });

  testWidgets(
      'a tap on the control through the cut-out dismisses and does not activate it',
      (t) async {
    final c = await _pump(t, _hostPage());
    await t.pumpAndSettle();
    await t.tapAt(t.getCenter(find.byKey(_target)));
    await t.pumpAndSettle();
    expect(taps, 0);
    expect(_bubbleFinder, findsNothing);
    expect(c.read(tipsProvider).seen, {Tip.myFlows});
    // The tip is gone: the control works again.
    await t.tap(find.byKey(_target));
    expect(taps, 1);
  });

  testWidgets('Back dismisses without popping', (t) async {
    final nav = GlobalKey<NavigatorState>();
    final c = await _pump(
      t,
      const Scaffold(body: Text('below')),
      navigatorKey: nav,
    );
    nav.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => _hostPage()));
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byKey(_target), findsOneWidget);
    expect(_bubbleFinder, findsNothing);
    expect(c.read(tipsProvider).seen, {Tip.myFlows});
    // With the tip gone, Back pops as usual.
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byKey(_target), findsNothing);
    expect(find.text('below'), findsOneWidget);
  });

  testWidgets('Escape dismisses', (t) async {
    final c = await _pump(t, _hostPage());
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsNothing);
    expect(c.read(tipsProvider).seen, {Tip.myFlows});
  });

  testWidgets('keys go to the tip, not to a page control that had focus',
      (t) async {
    final c = await _pump(
      t,
      TipHost(
        tipsFor: () => [Tip.myFlows],
        child: Scaffold(
          body: Column(children: [
            const SizedBox(height: 100),
            // A page control that has focus and acts on Enter.
            Focus(
              autofocus: true,
              onKeyEvent: (_, e) {
                if (e is! KeyDownEvent ||
                    e.logicalKey != LogicalKeyboardKey.enter) {
                  return KeyEventResult.ignored;
                }
                taps++;
                return KeyEventResult.handled;
              },
              child: const SizedBox(width: 10, height: 10),
            ),
            TipAnchor(tip: Tip.myFlows, child: _control()),
          ]),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(taps, 0);
    expect(c.read(tipsProvider).active, Tip.myFlows);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsNothing);
    expect(c.read(tipsProvider).seen, {Tip.myFlows});
  });

  testWidgets(
      'an anchor scrolled out of view waits; scrolling it in shows the tip',
      (t) async {
    final c = await _pump(
      t,
      TipHost(
        tipsFor: () => [Tip.myFlows],
        child: Scaffold(
          body: ListView(children: [
            const SizedBox(height: 1500),
            Align(child: TipAnchor(tip: Tip.myFlows, child: _control())),
            const SizedBox(height: 1500),
          ]),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsNothing);
    expect(c.read(tipsProvider).active, isNull);
    await t.drag(find.byType(ListView), const Offset(0, -1200));
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsOneWidget);
    expect(_rectOf(t, _bubble).top, greaterThan(_rectOf(t, _target).bottom));
  });

  testWidgets('a host that is disposed withdraws without marking seen',
      (t) async {
    final c = await _pump(t, _hostPage());
    await t.pumpAndSettle();
    expect(c.read(tipsProvider).active, Tip.myFlows);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const SizedBox(),
    ));
    await t.pump();
    expect(c.read(tipsProvider).active, isNull);
    expect(c.read(tipsProvider).seen, isEmpty);
  });

  testWidgets('nothing shows while a modal route is on top', (t) async {
    final nav = GlobalKey<NavigatorState>();
    final c = await _pump(t, _hostPage(), navigatorKey: nav);
    showDialog<void>(
      context: nav.currentContext!,
      builder: (_) => const Center(child: SizedBox(width: 100, height: 100)),
    );
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsNothing);
    expect(c.read(tipsProvider).active, isNull);
    expect(c.read(tipsProvider).seen, isEmpty);
    nav.currentState!.pop();
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsOneWidget);
    expect(c.read(tipsProvider).active, Tip.myFlows);
  });

  testWidgets('one tip at a time across two hosts', (t) async {
    final c = await _pump(
      t,
      Scaffold(
        body: Column(children: [
          Expanded(
            child: TipHost(
              tipsFor: () => [Tip.myFlows],
              child: Center(
                child: TipAnchor(tip: Tip.myFlows, child: _control()),
              ),
            ),
          ),
          Expanded(
            child: TipHost(
              tipsFor: () => [Tip.readerSettings],
              child: Center(
                child: TipAnchor(
                  tip: Tip.readerSettings,
                  child: _control(key: const ValueKey('other')),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsOneWidget);
    final first = c.read(tipsProvider).active!;
    expect(find.text(first.title), findsOneWidget);
    await t.tap(find.byKey(_gotIt));
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsOneWidget);
    final second = c.read(tipsProvider).active!;
    expect({first, second}, {Tip.myFlows, Tip.readerSettings});
    expect(find.text(second.title), findsOneWidget);
    expect(find.text(first.title), findsNothing);
  });

  testWidgets('reduced motion: appears in one frame with no running animations',
      (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(t, _hostPage());
    await t.pump();
    expect(_bubbleFinder, findsOneWidget);
    final opacity = t.widget<AnimatedOpacity>(
      find.ancestor(of: _bubbleFinder, matching: find.byType(AnimatedOpacity)),
    );
    expect(opacity.opacity, 1);
    expect(t.hasRunningAnimations, isFalse);
    await t.pumpAndSettle();
  });

  testWidgets('tips off: nothing shows', (t) async {
    final c = await _pump(t, _hostPage(), allowed: false);
    await t.pumpAndSettle();
    expect(_bubbleFinder, findsNothing);
    expect(c.read(tipsProvider).active, isNull);
  });

  group('BubbleLayoutDelegate', () {
    const size = Size(400, 800);
    const child = Size(300, 100);
    BubbleLayoutDelegate at(Rect cutout) =>
        BubbleLayoutDelegate(cutout: cutout, margin: 16, gap: 12);

    test('below the cut-out when it fits, centred on it', () {
      final d = at(const Rect.fromLTWH(150, 100, 100, 48));
      expect(d.getPositionForChild(size, child), const Offset(50, 160));
    });

    test('exactly fitting below still goes below', () {
      // 672 + 12 + 100 == 800 - 16
      final d = at(const Rect.fromLTWH(150, 624, 100, 48));
      expect(d.getPositionForChild(size, child), const Offset(50, 684));
    });

    test('above the cut-out when it does not fit below', () {
      final d = at(const Rect.fromLTWH(150, 700, 100, 48));
      expect(d.getPositionForChild(size, child), const Offset(50, 588));
    });

    test('y is clamped to the margins when neither side has room', () {
      // A tall bubble over a control near the top of a 320 x 568 screen:
      // below does not fit (58 + 12 + 500 > 552), above would start at -502.
      final d = at(const Rect.fromLTWH(100, 10, 120, 48));
      expect(
        d.getPositionForChild(const Size(320, 568), const Size(288, 500)),
        const Offset(16, 16),
      );
    });

    test('x is clamped to the margins', () {
      final right = at(const Rect.fromLTWH(360, 100, 60, 48));
      expect(right.getPositionForChild(size, child).dx, 400 - 16 - 300);
      final left = at(const Rect.fromLTWH(-20, 100, 60, 48));
      expect(left.getPositionForChild(size, child).dx, 16);
      final wide = at(const Rect.fromLTWH(150, 100, 100, 48));
      expect(wide.getPositionForChild(size, const Size(390, 100)).dx, 16);
    });

    test('the bubble is laid out within the margins', () {
      final d = at(const Rect.fromLTWH(150, 100, 100, 48));
      expect(
        d.getConstraintsForChild(BoxConstraints.tight(size)),
        BoxConstraints.loose(const Size(368, 768)),
      );
    });

    test('relayout only when an input changes', () {
      final d = at(const Rect.fromLTWH(150, 100, 100, 48));
      expect(
        d.shouldRelayout(at(const Rect.fromLTWH(150, 100, 100, 48))),
        isFalse,
      );
      expect(
        d.shouldRelayout(at(const Rect.fromLTWH(150, 120, 100, 48))),
        isTrue,
      );
    });
  });

  test('unionRect covers every rect; cutoutFor adds 6 on each side', () {
    expect(
      unionRect(const [
        Rect.fromLTWH(10, 20, 30, 40),
        Rect.fromLTWH(100, 5, 10, 10),
      ]),
      const Rect.fromLTRB(10, 5, 110, 60),
    );
    expect(
      cutoutFor(const Rect.fromLTRB(10, 20, 30, 40)),
      const Rect.fromLTRB(4, 14, 36, 46),
    );
  });
}
