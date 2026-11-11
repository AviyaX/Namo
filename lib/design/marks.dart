import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// The small drawn marks of the Home screen: thin gold line art, drawn with
/// curves in a 24 × 24 box, symmetric about the vertical centre line.
enum NamoMark {
  /// An open lotus: five petals over a short base curve (beside "Namo").
  lotus,

  /// A bodhi leaf, upright.
  leaf,

  /// Two hands joined, pointing up (Namaskara).
  palms,

  /// The dhamma wheel: rim, hub, eight spokes, knobs outside the rim.
  wheel,

  /// A lotus bud: three petals with two side leaves.
  lotusBud,

  /// A simple seated figure: head, shoulders, folded legs.
  seated,
}

/// One [NamoMark] as line work in [color], or the palette gold.
class NamoMarkIcon extends StatelessWidget {
  const NamoMarkIcon(
    this.mark, {
    super.key,
    this.size = 28,
    this.color,
    this.strokeWidth = 1.5,
    this.semanticLabel,
  });

  final NamoMark mark;

  /// Width and height, in logical pixels.
  final double size;

  /// The line colour; the palette gold when null.
  final Color? color;

  /// The line width in logical pixels, whatever the [size].
  final double strokeWidth;

  /// What a screen reader says; when null the mark is decoration only.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final paint = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MarkPainter(
          mark,
          color ?? NamoPalette.of(context).gold,
          strokeWidth,
        ),
      ),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: paint);
    return Semantics(
      container: true,
      image: true,
      label: label,
      child: ExcludeSemantics(child: paint),
    );
  }
}

/// A large, faint bodhi leaf filling its box: the watermark of the gatha card.
class LeafWatermark extends StatelessWidget {
  const LeafWatermark({super.key, this.opacity = 0.10});

  /// How strongly the gold leaf shows, 0–1.
  final double opacity;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.expand(
          child: CustomPaint(
            painter: _LeafPainter(NamoPalette.of(context).gold, opacity),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Painting

/// A line of a mark. An [occludes] part hides whatever was drawn before it
/// inside its outline, so petals in front cover the ones behind on any
/// background.
class _Part {
  const _Part(this.path, {this.occludes = false});
  final Path path;
  final bool occludes;
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.mark, this.color, this.strokeWidth);

  final NamoMark mark;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 24;
    if (scale <= 0) return;
    final m = Float64List.fromList([
      scale, 0, 0, 0, //
      0, scale, 0, 0,
      0, 0, 1, 0,
      (size.width - 24 * scale) / 2, (size.height - 24 * scale) / 2, 0, 1,
    ]);
    _paintParts(canvas, Offset.zero & size, _parts[mark]!, m,
        _stroke(color, strokeWidth));
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.mark != mark || old.color != color || old.strokeWidth != strokeWidth;
}

class _LeafPainter extends CustomPainter {
  const _LeafPainter(this.color, this.opacity);

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    // The leaf is drawn in a 24 × 32 box, scaled to fit and centred.
    final scale = math.min(size.width / 24, size.height / 32);
    if (scale <= 0 || opacity <= 0) return;
    final m = Float64List.fromList([
      scale, 0, 0, 0, //
      0, scale, 0, 0,
      0, 0, 1, 0,
      (size.width - 24 * scale) / 2, (size.height - 32 * scale) / 2, 0, 1,
    ]);
    final ink = color.withValues(alpha: color.a * opacity.clamp(0.0, 1.0));
    // Lines thicken a little with the leaf, but stay fine.
    final line = (scale * 0.32).clamp(1.0, 2.2);
    canvas.drawPath(_leafOutline.transform(m), _stroke(ink, line));
    canvas.drawPath(_leafVeins.transform(m), _stroke(ink, line * 0.7));
  }

  @override
  bool shouldRepaint(_LeafPainter old) =>
      old.color != color || old.opacity != opacity;
}

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

void _paintParts(
  Canvas canvas,
  Rect bounds,
  List<_Part> parts,
  Float64List m,
  Paint stroke,
) {
  final layered = parts.any((p) => p.occludes);
  if (layered) canvas.saveLayer(bounds.inflate(stroke.strokeWidth), Paint());
  final clear = Paint()..blendMode = BlendMode.clear;
  for (final part in parts) {
    final path = part.path.transform(m);
    if (part.occludes) canvas.drawPath(path, clear);
    canvas.drawPath(path, stroke);
  }
  if (layered) canvas.restore();
}

// ---------------------------------------------------------------------------
// Drawings, in a 24 × 24 box (the leaf in 24 × 32).

final Map<NamoMark, List<_Part>> _parts = {
  NamoMark.lotus: _lotus(),
  NamoMark.leaf: [_Part(_leafOutline), _Part(_iconLeafVeins)].map(_fitLeaf).toList(),
  NamoMark.palms: _palms(),
  NamoMark.wheel: _wheel(),
  NamoMark.lotusBud: _lotusBud(),
  NamoMark.seated: _seated(),
};

/// The [path] mirrored about the vertical centre line x = 12.
Path _mirror(Path path) => path.transform(Float64List.fromList([
      -1, 0, 0, 0, //
      0, 1, 0, 0,
      0, 0, 1, 0,
      24, 0, 0, 1,
    ]));

/// [path] and its mirror image.
List<_Part> _pair(Path path, {bool occludes = false}) => [
      _Part(path, occludes: occludes),
      _Part(_mirror(path), occludes: occludes),
    ];

/// A closed, pointed petal from [base] to [tip], [width] to each side at its
/// widest; [belly] (0–1) is where along its length it is widest.
Path _petal(Offset base, Offset tip, double width, {double belly = 0.4}) {
  final d = tip - base;
  final n = Offset(-d.dy, d.dx) / d.distance;
  final path = Path()..moveTo(base.dx, base.dy);
  void side(double s, Offset end) {
    final a = base + d * (belly * 0.55) + n * (s * width * 1.15);
    final b = base + d * (belly + 0.35) + n * (s * width * 0.95);
    if (s > 0) {
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, end.dx, end.dy);
    } else {
      path.cubicTo(b.dx, b.dy, a.dx, a.dy, end.dx, end.dy);
    }
  }

  side(1, tip);
  side(-1, base);
  return path..close();
}

List<_Part> _lotus() => [
      // Outer petals, lying out low to each side.
      ..._pair(_petal(const Offset(11, 19), const Offset(1.6, 13.4), 2.0),
          occludes: true),
      // Inner side petals.
      ..._pair(_petal(const Offset(11.4, 19), const Offset(5.6, 7.6), 2.5),
          occludes: true),
      // The centre petal, in front.
      _Part(_petal(const Offset(12, 19.2), const Offset(12, 3.4), 3.1),
          occludes: true),
      // The base curve.
      _Part(Path()
        ..moveTo(5.2, 20.2)
        ..quadraticBezierTo(12, 23.4, 18.8, 20.2)),
    ];

List<_Part> _palms() {
  // The left hand; the right is its mirror image.
  // Fingertips meeting at the top, the outer edge running down and out to
  // the wrist, the palm edge pressed to the other hand, parting at the heel.
  final hand = Path()
    ..moveTo(12, 2.4)
    ..cubicTo(10.9, 2.4, 10.1, 3.4, 9.5, 5.0)
    ..cubicTo(8.4, 8.0, 6.8, 11.6, 5.2, 14.8)
    ..lineTo(8.6, 17.4)
    ..cubicTo(9.6, 15.8, 10.8, 14.0, 12, 12.6)
    ..close();
  // The thumb, lying up along the palm.
  final thumb = Path()
    ..moveTo(11.2, 13.6)
    ..cubicTo(10.3, 12.2, 10.0, 10.4, 10.4, 8.6);
  // The cuff of the sleeve, a band below the wrist.
  final cuff = Path()
    ..moveTo(5.2, 14.8)
    ..lineTo(3.9, 16.6)
    ..lineTo(7.4, 19.2)
    ..lineTo(8.6, 17.4);
  // Drawn from y 2.4 to 19.2; moved down to sit in the middle of the box.
  final down = Float64List.fromList([
    1, 0, 0, 0, //
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 1.2, 0, 1,
  ]);
  return [
    for (final p in [hand, thumb, cuff].map((p) => p.transform(down)))
      ..._pair(p),
  ];
}

List<_Part> _wheel() {
  const c = Offset(12, 12);
  final rim = Path()..addOval(Rect.fromCircle(center: c, radius: 7.2));
  final hub = Path()..addOval(Rect.fromCircle(center: c, radius: 1.8));
  final spokes = Path();
  final knobs = Path();
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    final u = Offset(math.sin(a), -math.cos(a));
    final from = c + u * 1.8, to = c + u * 7.2, out = c + u * 9.0;
    spokes
      ..moveTo(from.dx, from.dy)
      ..lineTo(to.dx, to.dy)
      ..moveTo(to.dx, to.dy)
      ..lineTo(out.dx, out.dy);
    knobs.addOval(Rect.fromCircle(center: c + u * 10.0, radius: 1.0));
  }
  return [_Part(rim), _Part(hub), _Part(spokes), _Part(knobs)];
}

List<_Part> _lotusBud() => [
      // Two leaves at the foot, sweeping out to each side.
      ..._pair(
          _petal(const Offset(11.2, 18.6), const Offset(2.0, 15.6), 1.9,
              belly: 0.5),
          occludes: true),
      ..._pair(Path()
        ..moveTo(10.2, 18.0)
        ..quadraticBezierTo(6.5, 17.2, 3.4, 15.9)),
      // Two side petals hugging the bud.
      ..._pair(_petal(const Offset(11.6, 18.4), const Offset(6.6, 9.0), 2.4),
          occludes: true),
      // The bud.
      _Part(
          _petal(const Offset(12, 18.6), const Offset(12, 4.0), 3.9,
              belly: 0.32),
          occludes: true),
      // A short stem.
      _Part(Path()
        ..moveTo(12, 18.6)
        ..lineTo(12, 21.6)),
    ];

List<_Part> _seated() {
  // Neck, sloping shoulders, upper arms down to the lap.
  final torso = Path()
    ..moveTo(10.9, 8.6)
    ..cubicTo(10.4, 9.6, 8.4, 9.6, 7.4, 10.8)
    ..cubicTo(6.4, 12.0, 6.4, 15.0, 7.2, 17.6)
    ..lineTo(16.8, 17.6)
    ..cubicTo(17.6, 15.0, 17.6, 12.0, 16.6, 10.8)
    ..cubicTo(15.6, 9.6, 13.6, 9.6, 13.1, 8.6)
    ..close();
  // The inner line of each arm, from the shoulder to the hands.
  final arm = Path()
    ..moveTo(8.9, 12.0)
    ..cubicTo(8.8, 14.2, 9.4, 16.2, 10.4, 17.4);
  final legs = Path()
    ..moveTo(3.4, 19.6)
    ..cubicTo(4.2, 17.2, 8.0, 16.4, 12, 17.0)
    ..cubicTo(16.0, 16.4, 19.8, 17.2, 20.6, 19.6)
    ..cubicTo(20.2, 21.0, 16.0, 21.4, 12, 21.4)
    ..cubicTo(8.0, 21.4, 3.8, 21.0, 3.4, 19.6)
    ..close();
  final hands = Path()
    ..moveTo(9.8, 18.0)
    ..quadraticBezierTo(12, 19.8, 14.2, 18.0);
  final head = Path()
    ..addOval(Rect.fromCircle(center: const Offset(12, 6.3), radius: 2.4));
  // The small rise on the crown of the head, meeting the head's outline.
  final crown = Path()
    ..moveTo(10.9, 4.17)
    ..quadraticBezierTo(12, 1.7, 13.1, 4.17);
  return [
    _Part(torso, occludes: true),
    ..._pair(arm),
    _Part(legs, occludes: true),
    _Part(hands),
    _Part(head, occludes: true),
    _Part(crown),
  ];
}

/// The bodhi leaf (24 × 32) squeezed into the 24 × 24 box of an icon.
_Part _fitLeaf(_Part p) => _Part(p.path.transform(Float64List.fromList([
      0.75, 0, 0, 0, //
      0, 0.75, 0, 0,
      0, 0, 1, 0,
      3, 0, 0, 1,
    ])));

/// A heart-shaped bodhi leaf with a long drawn-out tip, in a 24 × 32 box.
final Path _leafOutline = () {
  final right = Path()
    ..moveTo(12, 0.4)
    ..cubicTo(12.3, 3.4, 13.4, 6.0, 15.4, 7.8)
    ..cubicTo(19.4, 10.6, 23.0, 14.0, 23.0, 18.8)
    ..cubicTo(23.0, 24.6, 18.6, 29.4, 14.8, 29.4)
    ..cubicTo(13.5, 29.4, 12.5, 29.0, 12, 28.4);
  return Path()
    ..addPath(right, Offset.zero)
    ..addPath(_mirror(right), Offset.zero)
    // The stem.
    ..moveTo(12, 28.4)
    ..quadraticBezierTo(12.2, 30.4, 13.2, 31.6);
}();

/// The midrib and six pairs of side veins, curving up towards the edge.
final Path _leafVeins = _veins(const [
  // start y on the midrib, reach out, rise
  (26.0, 7.2, 3.2),
  (22.4, 9.2, 4.6),
  (18.6, 9.4, 5.2),
  (14.8, 8.0, 5.0),
  (11.4, 5.4, 3.8),
  (8.6, 2.6, 2.0),
]);

/// Fewer veins for the small leaf, so it does not fill in.
final Path _iconLeafVeins = _veins(const [
  (24.6, 8.4, 4.2),
  (18.8, 9.4, 5.2),
  (13.2, 6.8, 4.4),
]);

Path _veins(List<(double, double, double)> v) {
  final veins = Path()
    ..moveTo(12, 28.4)
    ..quadraticBezierTo(11.9, 16, 12, 3.2);
  for (final (y, dx, dy) in v) {
    final r = Path()
      ..moveTo(12, y)
      ..quadraticBezierTo(12 + dx * 0.55, y - dy * 0.15, 12 + dx, y - dy);
    veins
      ..addPath(r, Offset.zero)
      ..addPath(_mirror(r), Offset.zero);
  }
  return veins;
}
