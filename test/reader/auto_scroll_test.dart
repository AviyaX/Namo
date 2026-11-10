import 'package:buddhist_gatha/reader/auto_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _frame = Duration(milliseconds: 16);

/// A 5000-px page on a real [ScrollController], and an engine on it at
/// [speed]. Frames are fed to the engine by hand.
Future<(ScrollController, AutoScrollEngine)> pumpPage(
  WidgetTester t, {
  required double speed,
}) async {
  final controller = ScrollController();
  final engine = AutoScrollEngine(controller: controller, speed: speed);
  addTearDown(() {
    engine.dispose();
    controller.dispose();
  });
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SingleChildScrollView(
        controller: controller,
        child: const SizedBox(height: 5000),
      ),
    ),
  );
  return (controller, engine);
}

/// Feeds [count] frames of [each] to [engine].
void frames(AutoScrollEngine engine, int count, [Duration each = _frame]) {
  for (var i = 0; i < count; i++) {
    engine.onFrame(each);
  }
}

/// One second of 20-ms frames.
void oneSecond(AutoScrollEngine engine) =>
    frames(engine, 50, const Duration(milliseconds: 20));

void main() {
  testWidgets('moves by speed x time, keeping sub-pixel progress', (t) async {
    final (c, engine) = await pumpPage(t, speed: 6);
    expect(engine.status, AutoScrollStatus.stopped);
    engine.play();
    expect(engine.status, AutoScrollStatus.running);
    frames(engine, 60);
    // 0.096 px a frame: rounding each frame to a pixel would never move.
    expect(c.offset, closeTo(5.76, 0.01));
  });

  testWidgets('a speed change applies from the next frame with no jump', (
    t,
  ) async {
    final (c, engine) = await pumpPage(t, speed: 12);
    engine.play();
    oneSecond(engine);
    expect(c.offset, closeTo(12, 0.01));

    engine.speed = 36;
    expect(engine.speed, 36);
    expect(c.offset, closeTo(12, 0.01));
    expect(engine.status, AutoScrollStatus.running);
    oneSecond(engine);
    expect(c.offset, closeTo(48, 0.01));
  });

  testWidgets('pause holds the page; play resumes from where the page now is', (
    t,
  ) async {
    final (c, engine) = await pumpPage(t, speed: 22);
    engine.play();
    oneSecond(engine);
    expect(c.offset, closeTo(22, 0.01));

    engine.pause();
    expect(engine.status, AutoScrollStatus.paused);
    oneSecond(engine);
    expect(c.offset, closeTo(22, 0.01));

    c.jumpTo(900);
    oneSecond(engine);
    expect(c.offset, 900);
    expect(engine.status, AutoScrollStatus.paused);

    engine.play();
    expect(engine.status, AutoScrollStatus.running);
    oneSecond(engine);
    expect(c.offset, closeTo(922, 0.01));
  });

  testWidgets('a long gap between frames moves at most 100 ms of distance', (
    t,
  ) async {
    final (c, engine) = await pumpPage(t, speed: 60);
    engine.play();
    engine.onFrame(const Duration(seconds: 30));
    expect(c.offset, closeTo(6.0, 0.01));
    expect(engine.status, AutoScrollStatus.running);
  });

  testWidgets('scrolling by other means pauses and is not pulled back', (
    t,
  ) async {
    final (c, engine) = await pumpPage(t, speed: 22);
    engine.play();
    oneSecond(engine);
    c.jumpTo(400);
    engine.onFrame(_frame);
    expect(engine.status, AutoScrollStatus.paused);
    expect(c.offset, 400);
    oneSecond(engine);
    expect(c.offset, 400);
  });

  testWidgets('a move made on purpose and synced does not pause it', (
    t,
  ) async {
    final (c, engine) = await pumpPage(t, speed: 22);
    engine.play();
    oneSecond(engine);
    c.jumpTo(400);
    engine.syncToPage();
    oneSecond(engine);
    expect(engine.status, AutoScrollStatus.running);
    expect(c.offset, closeTo(422, 0.01));
  });

  testWidgets('stops by itself at the end; play then starts again from the '
      'top', (t) async {
    final (c, engine) = await pumpPage(t, speed: 60);
    final max = c.position.maxScrollExtent;
    expect(max, greaterThan(4000));
    var changes = 0;
    engine.addListener(() => changes++);

    c.jumpTo(max - 10);
    engine.play();
    oneSecond(engine);
    expect(c.offset, max);
    expect(engine.status, AutoScrollStatus.finished);
    expect(changes, 2); // running, then finished
    oneSecond(engine);
    expect(c.offset, max);

    engine.play();
    expect(engine.status, AutoScrollStatus.running);
    expect(c.offset, 0);
    oneSecond(engine);
    expect(c.offset, closeTo(60, 0.01));
  });

  testWidgets('reset returns to the top and stops', (t) async {
    final (c, engine) = await pumpPage(t, speed: 22);
    c.jumpTo(300);
    engine.play();
    oneSecond(engine);
    expect(c.offset, closeTo(322, 0.01));

    engine.reset();
    expect(c.offset, 0);
    expect(engine.status, AutoScrollStatus.stopped);
    oneSecond(engine);
    expect(c.offset, 0);

    // Reset while paused also stops.
    engine.play();
    engine.pause();
    engine.reset();
    expect(engine.status, AutoScrollStatus.stopped);
  });

  testWidgets('speed is clamped to 6-60', (t) async {
    final (_, engine) = await pumpPage(t, speed: 1);
    expect(engine.speed, AutoScrollEngine.minSpeed);
    engine.speed = 100;
    expect(engine.speed, AutoScrollEngine.maxSpeed);
    engine.speed = 2;
    expect(engine.speed, 6);
    engine.speed = 60.5;
    expect(engine.speed, 60);
    engine.speed = AutoScrollEngine.normal;
    expect(engine.speed, 22);
    expect(AutoScrollEngine.slow, 12);
    expect(AutoScrollEngine.fast, 36);
  });
}
