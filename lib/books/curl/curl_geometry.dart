/// The shapes of a page curl: where a page folds when its corner is held
/// at a point, which part still lies flat, and where its lifted back lands.
/// Pure functions of the page size and the finger, so they can be tested
/// without drawing anything.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A straight line through two points.
@immutable
class Line {
  const Line(this.a, this.b);

  final Offset a;
  final Offset b;

  @override
  bool operator ==(Object other) =>
      other is Line && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);

  @override
  String toString() => 'Line($a, $b)';
}

/// One frame of a page curl on a page of a given size.
///
/// The turning page's outer corner ([corner], bottom or top right) is held
/// at [point]; the page folds along [fold], the perpendicular bisector of
/// the two. [frontVisible] is the part of the turning page still lying
/// flat, [backFlap] is the lifted part mirrored over the fold (the page's
/// back, seen on top), and [revealed] is the part of the page beneath that
/// shows where the corner was lifted away. The spine is the left edge.
class CurlGeometry {
  CurlGeometry._({
    required this.size,
    required this.corner,
    required this.point,
    required this.frontVisible,
    required this.backFlap,
    required this.revealed,
    required this.fold,
    required this.progress,
    required this.mirror,
  });

  /// A forward turn: the current page's corner is held under [finger].
  /// [progress] is 0 with the finger on the right edge and 1 at the spine.
  /// The finger may go past the spine (to `-width`) to finish the turn.
  /// With [top] the top right corner is lifted instead of the bottom one.
  static CurlGeometry forward(Size page, Offset finger, {bool top = false}) {
    final progress = (1 - finger.dx / page.width).clamp(0.0, 1.0);
    return _fold(page, finger, top: top, progress: progress);
  }

  /// A backward turn: the previous page comes back over the current one.
  /// [finger] runs from the left edge (nothing back yet, [progress] 0) to
  /// the right edge (the previous page flat again, [progress] 1); the paths
  /// describe the returning previous page, and the current page is beneath.
  static CurlGeometry backward(Size page, Offset finger, {bool top = false}) {
    final progress = (finger.dx / page.width).clamp(0.0, 1.0);
    final held = Offset(2 * finger.dx - page.width, finger.dy);
    return _fold(page, held, top: top, progress: progress);
  }

  final Size size;

  /// The corner of the turning page that is lifted, where it lies flat.
  final Offset corner;

  /// Where the corner is held, kept within the paper's reach of the spine.
  final Offset point;

  final Path frontVisible;
  final Path backFlap;
  final Path revealed;
  final Line fold;

  /// How far the turn has gone, 0..1.
  final double progress;

  /// The reflection over [fold], as a column-major 4×4 matrix for
  /// [Canvas.transform]: draws the turning page onto [backFlap].
  final Float64List mirror;

  /// The unit vector across the fold, from [corner] towards [point].
  Offset get across {
    final d = point - corner;
    final length = d.distance;
    return length == 0 ? const Offset(-1, 0) : d / length;
  }

  /// How far the flap reaches from the fold (half the corner's travel).
  double get flapDepth => (point - corner).distance / 2;

  static CurlGeometry _fold(
    Size page,
    Offset finger, {
    required bool top,
    required double progress,
  }) {
    final w = page.width;
    final h = page.height;
    final corner = Offset(w, top ? 0 : h);
    final point = _withinReach(page, finger, top: top);
    final rect = [Offset.zero, Offset(w, 0), Offset(w, h), Offset(0, h)];

    final travel = point - corner;
    final distance = travel.distance;
    if (distance < 1e-3) {
      return CurlGeometry._(
        size: page,
        corner: corner,
        point: point,
        frontVisible: _path(rect),
        backFlap: Path(),
        revealed: Path(),
        fold: Line(corner, corner),
        progress: progress,
        mirror: _identity,
      );
    }

    final n = travel / distance;
    final mid = corner + travel / 2;
    final along = Offset(-n.dy, n.dx);
    final reach = page.longestSide * 2;

    final flat = _clip(rect, mid, n);
    final lifted = _clip(rect, mid, -n);
    var flap = [for (final p in lifted) _reflect(p, mid, n)];
    flap = _clip(flap, Offset.zero, const Offset(1, 0));
    flap = _clip(flap, Offset(w, 0), const Offset(-1, 0));
    flap = _clip(flap, Offset.zero, const Offset(0, 1));
    flap = _clip(flap, Offset(0, h), const Offset(0, -1));

    // Reflection over the line through `mid` with unit direction `along`.
    final r00 = along.dx * along.dx - along.dy * along.dy;
    final r01 = 2 * along.dx * along.dy;
    final r11 = -r00;
    final tx = mid.dx - (r00 * mid.dx + r01 * mid.dy);
    final ty = mid.dy - (r01 * mid.dx + r11 * mid.dy);

    return CurlGeometry._(
      size: page,
      corner: corner,
      point: point,
      frontVisible: _path(flat),
      backFlap: _path(flap),
      revealed: _path(lifted),
      fold: Line(mid - along * reach, mid + along * reach),
      progress: progress,
      mirror: Float64List.fromList([
        r00, r01, 0, 0, //
        r01, r11, 0, 0, //
        0, 0, 1, 0, //
        tx, ty, 0, 1, //
      ]),
    );
  }

  /// Paper is fixed at the spine, so the held corner can be no further than
  /// the page's width from the spine's end on its side, nor further than
  /// the diagonal from the other end.
  static Offset _withinReach(Size page, Offset p, {required bool top}) {
    final near = Offset(0, top ? 0 : page.height);
    final far = Offset(0, top ? page.height : 0);
    final diagonal = math.sqrt(
      page.width * page.width + page.height * page.height,
    );
    var held = _withinCircle(p, near, page.width);
    held = _withinCircle(held, far, diagonal);
    return held;
  }

  static Offset _withinCircle(Offset p, Offset centre, double radius) {
    final d = p - centre;
    final length = d.distance;
    return length <= radius ? p : centre + d / length * radius;
  }

  static Offset _reflect(Offset p, Offset mid, Offset n) {
    final s = (p - mid).dx * n.dx + (p - mid).dy * n.dy;
    return p - n * (2 * s);
  }

  /// The part of [polygon] on the side of the line through [origin] that
  /// [normal] points to (Sutherland–Hodgman against one edge).
  static List<Offset> _clip(
    List<Offset> polygon,
    Offset origin,
    Offset normal,
  ) {
    double side(Offset p) =>
        (p - origin).dx * normal.dx + (p - origin).dy * normal.dy;
    final out = <Offset>[];
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      final sa = side(a);
      final sb = side(b);
      if (sa >= 0) out.add(a);
      if ((sa >= 0) != (sb >= 0)) {
        out.add(Offset.lerp(a, b, sa / (sa - sb))!);
      }
    }
    return out;
  }

  static Path _path(List<Offset> points) =>
      points.length < 3 ? Path() : (Path()..addPolygon(points, true));

  static final _identity = Float64List.fromList([
    1, 0, 0, 0, //
    0, 1, 0, 0, //
    0, 0, 1, 0, //
    0, 0, 0, 1, //
  ]);
}
