/// Some lines of a justified text, as a printed page shows them: the whole
/// text is laid out once, justified, and only the lines of one slice are
/// drawn, so a slice's last line is justified like the rest unless it is
/// the text's own last line, and the lines break exactly where the
/// paginator measured them.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../design/tokens.dart';
import 'measure.dart';

/// How far past each side a slice's glyphs may be drawn: a glyph whose
/// ink reaches a little past its advance (an italic, a Sinhala vowel sign)
/// at the start or end of a line is not cut off. Above and below, a slice
/// is clipped exactly to its lines.
const justifiedOverhang = NamoSpace.xs;

/// The lines of [text] holding the characters [charStart] to [charEnd],
/// with the text laid out in full, justified, at the width given, in
/// [style] at [scaler]. As tall as those lines and no taller.
///
/// A hard line break at [charEnd] belongs to the next slice (see
/// `LinesSlice`), so it adds no line here.
class JustifiedLines extends LeafRenderObjectWidget {
  const JustifiedLines({
    super.key,
    required this.text,
    required this.style,
    required this.scaler,
    required this.direction,
    required this.charStart,
    required this.charEnd,
  });

  final String text;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final int charStart, charEnd;

  @override
  RenderJustifiedLines createRenderObject(BuildContext context) =>
      RenderJustifiedLines(
        text: text,
        style: style,
        scaler: scaler,
        direction: direction,
        charStart: charStart,
        charEnd: charEnd,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderJustifiedLines renderObject,
  ) {
    renderObject.update(
      text: text,
      style: style,
      scaler: scaler,
      direction: direction,
      charStart: charStart,
      charEnd: charEnd,
    );
  }
}

/// Draws a [JustifiedLines]: the whole text's layout shifted up to the
/// slice's first line and clipped to its lines.
class RenderJustifiedLines extends RenderBox {
  RenderJustifiedLines({
    required String text,
    required TextStyle style,
    required TextScaler scaler,
    required TextDirection direction,
    required this._charStart,
    required this._charEnd,
  }) : _text = text,
       _painter = TextPainter(
         text: TextSpan(text: text, style: style),
         textAlign: TextAlign.justify,
         textDirection: direction,
         textScaler: scaler,
       );

  final TextPainter _painter;
  String _text;
  int _charStart, _charEnd;

  /// How far the slice's first line is below the text's top.
  double _top = 0;

  (int, int) _lineRange = (0, 0);

  /// The whole text's justified layout.
  @visibleForTesting
  TextPainter get painter => _painter;

  /// The lines `[first, end)` of the whole text this slice draws.
  @visibleForTesting
  (int, int) get lineRange => _lineRange;

  /// Takes a new text, style, size, direction and slice all at once, so
  /// the slice always lies within the text.
  void update({
    required String text,
    required TextStyle style,
    required TextScaler scaler,
    required TextDirection direction,
    required int charStart,
    required int charEnd,
  }) {
    final span = TextSpan(text: text, style: style);
    if (_painter.text == span &&
        _painter.textScaler == scaler &&
        _painter.textDirection == direction &&
        _charStart == charStart &&
        _charEnd == charEnd) {
      return;
    }
    _text = text;
    _charStart = charStart;
    _charEnd = charEnd;
    _painter
      ..text = span
      ..textScaler = scaler
      ..textDirection = direction;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    assert(width.isFinite, 'JustifiedLines needs a bounded width');
    _painter.layout(minWidth: width, maxWidth: width);
    final metrics = _painter.computeLineMetrics();
    final starts = lineStarts(_painter, metrics);
    // The slice's first line holds charStart; it ends before the first
    // line after it that starts at or past charEnd.
    var first = 0;
    while (first + 1 < starts.length && starts[first + 1] <= _charStart) {
      first++;
    }
    var end = first + 1;
    while (end < starts.length && starts[end] < _charEnd) {
      end++;
    }
    if (starts.isEmpty) end = 0;
    var top = 0.0, height = 0.0;
    for (var i = 0; i < end; i++) {
      if (i < first) {
        top += metrics[i].height;
      } else {
        height += metrics[i].height;
      }
    }
    _top = top;
    _lineRange = (first, end);
    size = constraints.constrain(Size(width, height));
  }

  @override
  bool hitTestSelf(Offset position) => true;

  final _clip = LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTRB(
        -justifiedOverhang,
        0,
        size.width + justifiedOverhang,
        size.height,
      ),
      (context, offset) =>
          _painter.paint(context.canvas, offset + Offset(0, -_top)),
      oldLayer: _clip.layer,
    );
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..label = _text.substring(_charStart, _charEnd)
      ..textDirection = _painter.textDirection;
  }

  @override
  void dispose() {
    _clip.layer = null;
    _painter.dispose();
    super.dispose();
  }
}
