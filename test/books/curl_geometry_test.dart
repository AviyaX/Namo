import 'package:buddhist_gatha/books/curl/curl_geometry.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _page = Size(360, 640);

/// The area of a closed polygon path, from the path's bounds sampled on a
/// grid (good enough to compare "nothing", "half" and "all").
double _area(Path path) {
  var hits = 0;
  for (var x = 0.5; x < _page.width; x += 4) {
    for (var y = 0.5; y < _page.height; y += 4) {
      if (path.contains(Offset(x, y))) hits++;
    }
  }
  return hits * 16.0;
}

void main() {
  const full = 360.0 * 640.0;

  test('a finger at the right edge folds nothing; at the left edge the page '
      'is turned', () {
    final none = CurlGeometry.forward(_page, const Offset(360, 600));
    expect(none.progress, 0);
    final turned = CurlGeometry.forward(_page, const Offset(0, 600));
    expect(turned.progress, 1);
    // The corner held at the spine leaves about half the page flat.
    expect(
      _area(turned.frontVisible),
      inInclusiveRange(full * 0.4, full * 0.65),
    );
  });

  test('the corner held where it starts folds nothing at all', () {
    final g = CurlGeometry.forward(_page, const Offset(360, 640));
    expect(g.progress, 0);
    expect(_area(g.frontVisible), closeTo(full, full * 0.01));
    expect(_area(g.backFlap), 0);
  });

  test('the fold is the perpendicular bisector of corner and finger', () {
    const finger = Offset(200, 500);
    const corner = Offset(360, 640);
    final g = CurlGeometry.forward(_page, finger);
    for (final p in [g.fold.a, g.fold.b]) {
      expect((p - corner).distance, closeTo((p - finger).distance, 1e-6));
    }
    final along = g.fold.b - g.fold.a;
    final across = finger - corner;
    expect(along.dx * across.dx + along.dy * across.dy, closeTo(0, 1e-6));
  });

  test('the flap is the lifted corner mirrored over the fold', () {
    const finger = Offset(200, 500);
    final g = CurlGeometry.forward(_page, finger);
    // The corner lands under the finger: just inside it is flap, and the
    // lifted corner region now shows the page beneath.
    expect(g.backFlap.contains(const Offset(201, 501)), isTrue);
    expect(g.revealed.contains(const Offset(358, 638)), isTrue);
    expect(g.frontVisible.contains(const Offset(358, 638)), isFalse);
    expect(g.frontVisible.contains(const Offset(10, 10)), isTrue);
  });

  test('a corner pulled past the spine is kept on the page', () {
    // Far above the page: the corner cannot leave the spine's reach.
    final g = CurlGeometry.forward(_page, const Offset(100, -400));
    expect(
      g.point.dx * g.point.dx + (g.point.dy - 640) * (g.point.dy - 640),
      lessThanOrEqualTo(360 * 360 + 1e-6),
    );
  });

  test('turned fully, nothing of the page is left', () {
    final g = CurlGeometry.forward(_page, const Offset(-360, 640));
    expect(_area(g.frontVisible), 0);
    expect(_area(g.backFlap), 0);
    expect(_area(g.revealed), closeTo(full, full * 0.01));
  });

  test('the top corner can be lifted too', () {
    final g = CurlGeometry.forward(_page, const Offset(200, 100), top: true);
    expect(g.corner, const Offset(360, 0));
    expect(g.revealed.contains(const Offset(358, 2)), isTrue);
    expect(g.frontVisible.contains(const Offset(10, 630)), isTrue);
  });

  test('backward: from the left edge nothing is back; at the right edge the '
      'page lies flat again', () {
    final start = CurlGeometry.backward(_page, const Offset(0, 640));
    expect(start.progress, 0);
    expect(_area(start.frontVisible), 0);
    final done = CurlGeometry.backward(_page, const Offset(360, 640));
    expect(done.progress, 1);
    expect(_area(done.frontVisible), closeTo(full, full * 0.01));
    final half = CurlGeometry.backward(_page, const Offset(180, 600));
    expect(half.progress, 0.5);
  });
}
