import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/model.dart';
import '../design/tokens.dart';

/// Category id -> bundled asset path of its picture. This is the one place a
/// picture gets registered (and its file listed in pubspec.yaml and credited
/// in docs/pictures.md and on the Sources page).
const Map<String, String> cardPictures = {
  'cat-namaskaraya': 'assets/pictures/buddha_wandanawa.jpg',
  'cat-pirith': 'assets/pictures/pirith.jpg',
};

/// Category id -> the wide (3 : 1) picture used for the Home banner on wide
/// screens. Registered, listed and credited like [cardPictures].
const Map<String, String> widePictures = {
  'cat-namaskaraya': 'assets/pictures/home_banner.jpg',
};

/// Category id -> the small label above the title on the featured card.
const Map<String, String> featuredOverlines = {
  'cat-namaskaraya': 'Buddha Vandana',
};

/// The least strength of [NamoPalette.pictureScrim] behind the first line of
/// text on a picture, and at the picture's bottom edge.
const pictureFadeAtText = 0.70;
const pictureFadeAtBottom = 0.90;

/// The number of sections in all of [c]'s readings.
int sectionCount(Category c) =>
    c.readings.fold(0, (sum, r) => sum + r.sections.length);

String sectionCountLabel(int n) => n == 1 ? '1 section' : '$n sections';

String pirithCountLabel(int n) => '$n pirith';

/// True for a topic whose readings are all phrased pirith: it is counted and
/// listed by reading, not by section.
bool isPirithTopic(Category c) =>
    c.readings.isNotEmpty && c.readings.every((r) => r.isPhrased);

/// The count shown for [c]: its pirith, or its sections.
String topicCountLabel(Category c) => isPirithTopic(c)
    ? pirithCountLabel(c.readings.length)
    : sectionCountLabel(sectionCount(c));

/// Width of the bundled pictures; decoding never goes wider.
const int _maxDecodeWidth = 1600;

/// The width to decode a picture at: the width it is shown at, rounded up to
/// whole steps of 128 logical pixels, times the device pixel ratio. Resizing
/// the window by a few pixels then keeps the same decode instead of
/// decoding the file again for every pixel.
@visibleForTesting
int pictureDecodeWidth(double shownWidth, double devicePixelRatio) {
  if (!shownWidth.isFinite || !devicePixelRatio.isFinite) {
    return _maxDecodeWidth;
  }
  final steps = (shownWidth / 128).ceil().clamp(1, 1 << 20);
  return (steps * 128 * devicePixelRatio).clamp(1, _maxDecodeWidth).round();
}

/// The proportion of the bundled card pictures (16 : 9); used to work out how
/// wide a picture must be decoded to cover a box.
const double _cardPictureAspect = 16 / 9;

/// A topic's bundled picture, filling the space it is given: the wide one
/// when [wide] and the topic has one. A topic with no picture (or a picture
/// that does not load) gets the drawn lotus panel. The picture is
/// decoration, so it is left out of the semantics tree.
class TopicPicture extends StatelessWidget {
  const TopicPicture({
    super.key,
    required this.categoryId,
    this.wide = false,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.pictures,
  });

  final String categoryId;
  final bool wide;
  final BoxFit fit;
  final Alignment alignment;

  /// Replaces [cardPictures] and [widePictures]; for tests.
  final Map<String, String>? pictures;

  String? get _asset {
    if (pictures != null) return pictures![categoryId];
    return (wide ? widePictures[categoryId] : null) ?? cardPictures[categoryId];
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    return ExcludeSemantics(
      child: asset == null
          ? const _LotusPanel()
          : LayoutBuilder(
              builder: (context, box) {
                // Decode at the size the picture is shown, not the full
                // file: wide enough to cover the box, and no wider.
                final cover = math.max(
                  box.maxWidth,
                  box.maxHeight * _cardPictureAspect,
                );
                return Image.asset(
                  asset,
                  key: const ValueKey('card-art-picture'),
                  fit: fit,
                  alignment: alignment,
                  width: double.infinity,
                  height: double.infinity,
                  cacheWidth: pictureDecodeWidth(
                    cover,
                    MediaQuery.devicePixelRatioOf(context),
                  ),
                  // The plain ground shows until the first frame is decoded.
                  // `sync` is true when the picture was already decoded (in
                  // the image cache): show it at once, with no one-frame
                  // flash of the ground.
                  frameBuilder: (context, child, frame, sync) =>
                      frame == null && !sync
                      ? const _LotusPanel(lotus: false)
                      : child,
                  errorBuilder: (context, error, stack) => const _LotusPanel(),
                );
              },
            ),
    );
  }
}

/// A square [TopicPicture] with rounded corners.
class TopicThumbnail extends StatelessWidget {
  const TopicThumbnail({super.key, required this.categoryId, this.size = 56});

  final String categoryId;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(NamoRadius.sm),
      child: TopicPicture(categoryId: categoryId),
    ),
  );
}

/// The [NamoPalette.backgroundAlt] ground with one fine-line lotus in gold
/// at low strength, centred. Without the lotus it is only the ground, shown
/// while a picture decodes.
class _LotusPanel extends StatelessWidget {
  const _LotusPanel({this.lotus = true});

  final bool lotus;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return DecoratedBox(
      key: ValueKey(lotus ? 'card-art-panel' : 'card-art-loading'),
      decoration: BoxDecoration(color: p.backgroundAlt),
      child: lotus
          ? LayoutBuilder(
              builder: (context, box) => Center(
                child: Icon(
                  Symbols.spa_rounded,
                  size: box.maxHeight * 0.4,
                  weight: 300,
                  color: p.gold.withValues(alpha: 0.45),
                ),
              ),
            )
          : const SizedBox.expand(),
    );
  }
}

/// Where the words sit on a picture.
enum TextSide {
  /// Across the bottom; the scrim darkens downwards.
  bottom,

  /// In the left half, centred top to bottom; the scrim darkens leftwards.
  left,
}

/// The words laid over a picture, with the [NamoPalette.pictureScrim]
/// gradient behind them. It is at least [minHeight] tall and grows when the
/// words need more room, so they never clip or overflow.
///
/// With [TextSide.bottom] the words sit at the bottom, full width; the scrim
/// runs from nothing at the top to [pictureFadeAtText] where the words start
/// and [pictureFadeAtBottom] at the bottom edge. With [TextSide.left] the
/// words take the left half; the scrim runs from nothing at the right edge to
/// [pictureFadeAtText] at the right of the words and [pictureFadeAtBottom] at
/// the left edge.
class PictureWords extends SingleChildRenderObjectWidget {
  const PictureWords({
    super.key,
    required this.minHeight,
    this.side = TextSide.bottom,
    required Widget super.child,
  });

  final double minHeight;
  final TextSide side;

  @override
  RenderPictureWords createRenderObject(BuildContext context) =>
      RenderPictureWords(minHeight: minHeight, side: side);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPictureWords renderObject,
  ) {
    renderObject
      ..minHeight = minHeight
      ..side = side;
  }
}

class RenderPictureWords extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  RenderPictureWords({required double minHeight, required TextSide side}) {
    _minHeight = minHeight;
    _side = side;
  }

  late double _minHeight;
  double get minHeight => _minHeight;
  set minHeight(double v) {
    if (v == _minHeight) return;
    _minHeight = v;
    markNeedsLayout();
  }

  late TextSide _side;
  TextSide get side => _side;
  set side(TextSide v) {
    if (v == _side) return;
    _side = v;
    markNeedsLayout();
  }

  /// The width the words are given out of [width].
  double _wordsWidth(double width) =>
      _side == TextSide.left ? width / 2 : width;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      (child?.getMinIntrinsicWidth(double.infinity) ?? 0) *
      (_side == TextSide.left ? 2 : 1);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      (child?.getMaxIntrinsicWidth(double.infinity) ?? 0) *
      (_side == TextSide.left ? 2 : 1);

  @override
  double computeMinIntrinsicHeight(double width) => math.max(
    _minHeight,
    child?.getMinIntrinsicHeight(_wordsWidth(width)) ?? 0,
  );

  @override
  double computeMaxIntrinsicHeight(double width) => math.max(
    _minHeight,
    child?.getMaxIntrinsicHeight(_wordsWidth(width)) ?? 0,
  );

  Size _sizeFor(BoxConstraints constraints, Size words) => constraints.constrain(
    Size(constraints.maxWidth, math.max(_minHeight, words.height)),
  );

  BoxConstraints _wordsConstraints(BoxConstraints constraints) =>
      BoxConstraints.tightFor(width: _wordsWidth(constraints.maxWidth));

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final words =
        child?.getDryLayout(_wordsConstraints(constraints)) ?? Size.zero;
    return _sizeFor(constraints, words);
  }

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth);
    final c = child;
    if (c == null) {
      size = _sizeFor(constraints, Size.zero);
      return;
    }
    c.layout(_wordsConstraints(constraints), parentUsesSize: true);
    size = _sizeFor(constraints, c.size);
    (c.parentData! as BoxParentData).offset = switch (_side) {
      TextSide.bottom => Offset(0, size.height - c.size.height),
      TextSide.left => Offset(0, (size.height - c.size.height) / 2),
    };
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    final offset = (c.parentData! as BoxParentData).offset;
    return result.addWithPaintOffset(
      offset: offset,
      position: position,
      hitTest: (result, transformed) => c.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = (child.parentData! as BoxParentData).offset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    final rect = offset & size;
    const scrim = NamoPalette.pictureScrim;
    final LinearGradient gradient;
    switch (_side) {
      case TextSide.bottom:
        final top = c == null ? size.height : size.height - c.size.height;
        gradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scrim.withValues(alpha: 0),
            scrim.withValues(alpha: pictureFadeAtText),
            scrim.withValues(alpha: pictureFadeAtBottom),
          ],
          stops: [0, size.height == 0 ? 1 : top / size.height, 1],
        );
      case TextSide.left:
        gradient = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            scrim.withValues(alpha: 0),
            scrim.withValues(alpha: pictureFadeAtText),
            scrim.withValues(alpha: pictureFadeAtBottom),
          ],
          stops: const [0, 0.5, 1],
        );
    }
    context.canvas.drawRect(
      rect,
      Paint()..shader = gradient.createShader(rect),
    );
    if (c != null) {
      context.paintChild(c, offset + (c.parentData! as BoxParentData).offset);
    }
  }
}
