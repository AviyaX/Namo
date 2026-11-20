import 'package:buddhist_gatha/books/curl/page_curl.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _curlPaint = ValueKey('page-curl-paint');

class _Host {
  _Host({this.hasNext = true, this.hasPrevious = true});

  final bool hasNext;
  final bool hasPrevious;
  final controller = PageCurlController();
  var forward = 0;
  var back = 0;

  Widget build({bool reducedMotion = false}) => Theme(
    data: ThemeData(extensions: const [NamoPalette.light]),
    child: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 640),
        disableAnimations: reducedMotion,
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
            ),
          ),
        ),
      ),
    ),
  );
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
    await t.timedDragFrom(
      const Offset(180, 300),
      const Offset(-170, 0),
      const Duration(seconds: 1),
    );
    await t.pumpAndSettle();
    expect(h.forward + h.back, 0);
  });

  testWidgets('a vertical swipe does nothing', (t) async {
    final h = _Host();
    await t.pumpWidget(h.build());
    await t.flingFrom(const Offset(350, 500), const Offset(-10, -300), 1500);
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
    // A second call while turning is ignored.
    await h.controller.turnForward();
    await t.pumpAndSettle();
    expect(done, isTrue);
    expect(h.forward, 1);
    expect(h.controller.turning, isFalse);
  });

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
}
