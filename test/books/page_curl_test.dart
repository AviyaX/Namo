import 'package:buddhist_gatha/books/curl/page_curl.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _curlPaint = ValueKey('page-curl-paint');

class _Host {
  _Host({this.hasNext = true, this.hasPrevious = true});

  final bool hasNext;
  final bool hasPrevious;
  final controller = PageCurlController();
  var forward = 0;
  var back = 0;

  Widget build({
    bool reducedMotion = false,
    EdgeInsets gestureInsets = EdgeInsets.zero,
  }) => Theme(
    data: ThemeData(extensions: const [NamoPalette.light]),
    child: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 640),
        disableAnimations: reducedMotion,
        systemGestureInsets: gestureInsets,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 360,
            height: 640,
            child: PageCurl(
              controller: controller,
              current: const Center(child: Text('Current page')),
              next: hasNext ? const Center(child: Text('Next page')) : null,
              previous: hasPrevious
                  ? const Center(child: Text('Previous page'))
                  : null,
              onTurnedForward: () => forward++,
              onTurnedBack: () => back++,
              flapColour: NamoPalette.light.bookPaper,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Drags from [start] by [step] twenty times, quickly, then holds still
/// and lifts; the curl must never be painted along the way.
Future<void> _dragWithoutCurl(WidgetTester t, Offset start, Offset step) async {
  final drag = await t.startGesture(start);
  for (var i = 0; i < 20; i++) {
    await drag.moveBy(step);
    await t.pump(const Duration(milliseconds: 8));
    expect(find.byKey(_curlPaint), findsNothing);
  }
  await drag.up();
  await t.pump();
  expect(find.byKey(_curlPaint), findsNothing);
}

/// Pumps 10 ms frames until [done], returning how long that took.
Future<Duration> _timeUntil(WidgetTester t, bool Function() done) async {
  var elapsed = Duration.zero;
  while (!done()) {
    await t.pump(const Duration(milliseconds: 10));
    elapsed += const Duration(milliseconds: 10);
    if (elapsed > const Duration(seconds: 5)) fail('never finished');
  }
  return elapsed;
}

/// Pages that are whole blocks of colour, turned for real: the host moves
/// on to the next colour when told the page turned.
class _ColourBook extends StatefulWidget {
  const _ColourBook(this.controller, this.boundary);

  final PageCurlController controller;
  final GlobalKey boundary;

  static const colours = [
    Color(0xFFFF0000),
    Color(0xFF00FF00),
    Color(0xFF0000FF),
    Color(0xFFFFFF00),
  ];

  @override
  State<_ColourBook> createState() => _ColourBookState();
}

class _ColourBookState extends State<_ColourBook> {
  var page = 0;

  Widget? _page(int i) => i < 0 || i >= _ColourBook.colours.length
      ? null
      : ColoredBox(color: _ColourBook.colours[i]);

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(extensions: const [NamoPalette.light]),
    child: MediaQuery(
      data: const MediaQueryData(size: Size(360, 640)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: widget.boundary,
            child: SizedBox(
              width: 360,
              height: 640,
              child: PageCurl(
                controller: widget.controller,
                current: _page(page)!,
                next: _page(page + 1),
                previous: _page(page - 1),
                onTurnedForward: () => setState(() => page++),
                onTurnedBack: () => setState(() => page--),
                flapColour: NamoPalette.light.bookPaper,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The colour drawn at [at] inside [boundary].
Future<Color> _colourAt(WidgetTester t, GlobalKey boundary, Offset at) async {
  final box =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = (await t.runAsync(() async {
    final image = await box.toImage();
    final data = await image.toByteData();
    final width = image.width;
    image.dispose();
    final i = (at.dy.toInt() * width + at.dx.toInt()) * 4;
    return [for (var k = 0; k < 4; k++) data!.getUint8(i + k)];
  }))!;
  return Color.fromARGB(bytes[3], bytes[0], bytes[1], bytes[2]);
}

/// How many pixels inside [boundary] are clearly blue.
Future<int> _bluePixels(WidgetTester t, GlobalKey boundary) async {
  final box =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await t.runAsync(() async {
    final image = await box.toImage();
    final data = (await image.toByteData())!;
    image.dispose();
    var blue = 0;
    for (var i = 0; i < data.lengthInBytes; i += 4) {
      final r = data.getUint8(i), b = data.getUint8(i + 2);
      if (b > r + 100) blue++;
    }
    return blue;
  }))!;
}

void main() {
  testWidgets('drag past half completes the turn', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    final drag = await t.startGesture(const Offset(350, 500));
    for (var i = 1; i <= 25; i++) {
      await drag.moveBy(const Offset(-10, 0));
      await t.pump(const Duration(milliseconds: 40));
    }
    expect(find.byKey(_curlPaint), findsOneWidget);
    await t.pump(const Duration(milliseconds: 200));
    await drag.up();
    await t.pumpAndSettle();
    expect(h.forward, 1);
    expect(h.back, 0);
    expect(find.byKey(_curlPaint), findsNothing);
  });

  testWidgets('drag short of half falls back', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    await t.timedDragFrom(
      const Offset(350, 500),
      const Offset(-100, 0),
      const Duration(seconds: 1),
    );
    await t.pumpAndSettle();
    expect(h.forward, 0);
    expect(find.byKey(_curlPaint), findsNothing);
    expect(find.text('Current page').hitTestable(), findsOneWidget);
  });

  testWidgets('a fast short fling completes', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    await t.flingFrom(const Offset(350, 500), const Offset(-60, 0), 1000);
    await t.pumpAndSettle();
    expect(h.forward, 1);
  });

  testWidgets('a slow drag from the left edge turns back', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    await t.timedDragFrom(
      const Offset(10, 500),
      const Offset(250, 0),
      const Duration(seconds: 1),
    );
    await t.pumpAndSettle();
    expect(h.back, 1);
    expect(h.forward, 0);
  });

  testWidgets('a drag from the middle does nothing', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    // Far and fast enough to complete, were it allowed to start.
    await _dragWithoutCurl(t, const Offset(180, 300), const Offset(-12, 0));
    await t.pumpAndSettle();
    expect(h.forward + h.back, 0);
  });

  testWidgets('a vertical swipe does nothing', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    // Past half the width, but more up than across.
    await _dragWithoutCurl(t, const Offset(350, 560), const Offset(-10, -20));
    await t.pumpAndSettle();
    expect(h.forward + h.back, 0);
  });

  testWidgets('reduced motion turns at once with no curl painted', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build(reducedMotion: true));
    final drag = await t.startGesture(const Offset(350, 500));
    for (var i = 1; i <= 25; i++) {
      await drag.moveBy(const Offset(-10, 0));
      await t.pump(const Duration(milliseconds: 40));
      expect(find.byKey(_curlPaint), findsNothing);
    }
    await t.pump(const Duration(milliseconds: 200));
    await drag.up();
    await t.pump();
    expect(h.forward, 1);

    await h.controller.turnBack();
    await t.pump();
    expect(h.back, 1);
    expect(find.byKey(_curlPaint), findsNothing);
  });

  testWidgets('no next page: forward does nothing', (t) async {
    final h = _Host(hasNext: false);
    await t.pumpWidget(h.build());
    await t.flingFrom(const Offset(350, 500), const Offset(-200, 0), 1000);
    await t.pumpAndSettle();
    await t.tapAt(const Offset(350, 300));
    await t.pumpAndSettle();
    await h.controller.turnForward();
    expect(h.forward, 0);
    expect(h.controller.turning, isFalse);
  });

  testWidgets('no previous page: back does nothing', (t) async {
    final h = _Host(hasPrevious: false);
    await t.pumpWidget(h.build());
    await t.flingFrom(const Offset(10, 500), const Offset(200, 0), 1000);
    await t.pumpAndSettle();
    await h.controller.turnBack();
    expect(h.back, 0);
  });

  testWidgets('controller.turnForward animates and calls back', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    var done = false;
    h.controller.turnForward().then((_) => done = true);
    await t.pump();
    expect(h.controller.turning, isTrue);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(_curlPaint), findsOneWidget);
    expect(h.forward, 0);
    await t.pumpAndSettle();
    expect(done, isTrue);
    expect(h.forward, 1);
    expect(h.controller.turning, isFalse);
  });

  testWidgets('a turn asked for while turning follows it; one waits at most', (
    t,
  ) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    var second = false, third = false;
    h.controller.turnForward();
    await t.pump(const Duration(milliseconds: 100));
    h.controller.turnForward().then((_) => second = true);
    h.controller.turnBack().then((_) => third = true);
    await t.pumpAndSettle();
    expect(second, isTrue);
    expect(third, isTrue, reason: 'one not kept still completes');
    expect(h.forward, 2);
    expect(h.back, 0);
    expect(h.controller.turning, isFalse);
    // The other way waits too.
    h.controller.turnForward();
    await t.pump(const Duration(milliseconds: 100));
    await t.tapAt(const Offset(20, 300));
    await t.pumpAndSettle();
    expect(h.forward, 3);
    expect(h.back, 1);
  });

  testWidgets(
    "with gesture navigation a drag in the system's edge band does nothing; "
    'the drag zone starts past it',
    (t) async {
      const insets = EdgeInsets.symmetric(horizontal: 30);
      final h = _Host();
      await t.pumpWidget(h.build(gestureInsets: insets));
      // Inside the right band and the left band: the system's Back swipe.
      await _dragWithoutCurl(t, const Offset(350, 500), const Offset(-12, 0));
      await _dragWithoutCurl(t, const Offset(10, 500), const Offset(12, 0));
      await t.pumpAndSettle();
      expect(h.forward + h.back, 0);
      // Just inside each zone, past the band.
      await t.timedDragFrom(
        const Offset(325, 500),
        const Offset(-250, 0),
        const Duration(seconds: 1),
      );
      await t.pumpAndSettle();
      expect(h.forward, 1);
      await t.timedDragFrom(
        const Offset(35, 500),
        const Offset(250, 0),
        const Duration(seconds: 1),
      );
      await t.pumpAndSettle();
      expect(h.back, 1);
      // The zone is 54 px wide past the band: 30 + 54 = 84 from each side.
      await t.timedDragFrom(
        const Offset(80, 500),
        const Offset(250, 0),
        const Duration(seconds: 1),
      );
      await t.pumpAndSettle();
      expect(h.back, 2);
      await _dragWithoutCurl(t, const Offset(90, 500), const Offset(12, 0));
      await t.pumpAndSettle();
      expect(h.back, 2);
      // Taps in the outer fifth still turn, even in the band.
      await t.tapAt(const Offset(350, 300));
      await t.pumpAndSettle();
      expect(h.forward, 2);
    },
  );

  testWidgets('a tap in the outer fifth turns; in the middle it does not', (
    t,
  ) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    await t.tapAt(const Offset(180, 300));
    await t.pumpAndSettle();
    expect(h.forward + h.back, 0);
    await t.tapAt(const Offset(340, 300));
    await t.pumpAndSettle();
    expect(h.forward, 1);
    await t.tapAt(const Offset(20, 300));
    await t.pumpAndSettle();
    expect(h.back, 1);
  });

  testWidgets('only the current page is read by a screen reader', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    expect(find.bySemanticsLabel('Current page'), findsOneWidget);
    expect(find.bySemanticsLabel('Next page'), findsNothing);
    expect(find.bySemanticsLabel('Previous page'), findsNothing);
  });

  testWidgets('a back turn takes as long as a forward turn', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    h.controller.turnForward();
    final forwardTime = await _timeUntil(t, () => h.forward == 1);
    h.controller.turnBack();
    final backTime = await _timeUntil(t, () => h.back == 1);
    expect(forwardTime, greaterThanOrEqualTo(NamoMotion.open));
    expect(
      (backTime - forwardTime).abs(),
      lessThanOrEqualTo(const Duration(milliseconds: 20)),
    );
  });

  testWidgets('a turn straight after a turn pictures the new pages', (t) async {
    final controller = PageCurlController();
    final boundary = GlobalKey();
    await t.pumpWidget(_ColourBook(controller, boundary));
    Future<void>? second;
    // The second turn is asked for the moment the first one ends, before
    // the host has drawn its new pages.
    controller.turnForward().then((_) => second = controller.turnForward());
    while (second == null) {
      await t.pump(const Duration(milliseconds: 10));
    }
    // Part way into the second turn the flat part of the turning page is
    // the second page (green), not a picture of the first (red).
    await t.pump(const Duration(milliseconds: 20));
    await t.pump(const Duration(milliseconds: 60));
    expect(find.byKey(_curlPaint), findsOneWidget);
    expect(
      await _colourAt(t, boundary, const Offset(10, 10)),
      _ColourBook.colours[1],
    );
    await t.pumpAndSettle();
    expect(
      await _colourAt(t, boundary, const Offset(10, 10)),
      _ColourBook.colours[2],
    );
  });

  testWidgets('the back of a turning page is tinted the flap colour', (
    t,
  ) async {
    final controller = PageCurlController();
    final boundary = GlobalKey();
    const white = ColoredBox(color: Color(0xFFFFFFFF));
    await t.pumpWidget(
      Theme(
        data: ThemeData(extensions: const [NamoPalette.light]),
        child: MediaQuery(
          data: const MediaQueryData(size: Size(360, 640)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                  width: 360,
                  height: 640,
                  child: PageCurl(
                    controller: controller,
                    current: white,
                    next: white,
                    previous: null,
                    onTurnedForward: () {},
                    onTurnedBack: () {},
                    flapColour: const Color(0xFF0000FF),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(await _bluePixels(t, boundary), 0);
    final drag = await t.startGesture(const Offset(350, 500));
    for (var i = 1; i <= 15; i++) {
      await drag.moveBy(const Offset(-10, -5));
      await t.pump(const Duration(milliseconds: 40));
    }
    expect(find.byKey(_curlPaint), findsOneWidget);
    expect(await _bluePixels(t, boundary), greaterThan(500));
    await drag.up();
    await t.pumpAndSettle();
  });
  testWidgets('peek lifts the corner and settles without turning', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    var done = false;
    h.controller.peek().then((_) => done = true);
    await t.pump();
    expect(h.controller.turning, isTrue);
    // As a turn does, the peel starts a frame later, once the pages are
    // painted.
    await t.pump(const Duration(milliseconds: 16));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(_curlPaint), findsOneWidget);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byKey(_curlPaint), findsOneWidget);
    // The whole peel, up and down, is over in 1.2 s.
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 16));
    expect(find.byKey(_curlPaint), findsNothing);
    expect(h.controller.turning, isFalse);
    expect(done, isTrue);
    expect(h.forward, 0);
    expect(find.text('Current page').hitTestable(), findsOneWidget);
  });

  testWidgets('a drag cancels the peel', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    h.controller.peek();
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(_curlPaint), findsOneWidget);
    final drag = await t.startGesture(const Offset(350, 500));
    await t.pump();
    expect(find.byKey(_curlPaint), findsNothing);
    expect(h.controller.turning, isFalse);
    // The same finger then turns the page as any drag does.
    for (var i = 1; i <= 25; i++) {
      await drag.moveBy(const Offset(-10, 0));
      await t.pump(const Duration(milliseconds: 40));
    }
    expect(find.byKey(_curlPaint), findsOneWidget);
    await drag.up();
    await t.pumpAndSettle();
    expect(h.forward, 1);
  });

  testWidgets('an arrow turn during the peel turns at once', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    h.controller.peek();
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    h.controller.turnForward();
    // A plain turn, not one waiting the rest of the peel out.
    final took = await _timeUntil(t, () => h.forward == 1);
    expect(took, lessThan(NamoMotion.open + NamoMotion.close));
    await t.pumpAndSettle();
  });

  testWidgets('reduced motion: no peel', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build(reducedMotion: true));
    h.controller.peek();
    for (var f = 0; f < 20; f++) {
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byKey(_curlPaint), findsNothing);
      expect(h.controller.turning, isFalse);
    }
    expect(h.forward, 0);
  });

  testWidgets('no next page: no peel', (t) async {
    final h = _Host(hasNext: false);
    await t.pumpWidget(h.build());
    h.controller.peek();
    for (var f = 0; f < 20; f++) {
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byKey(_curlPaint), findsNothing);
    }
  });
}
