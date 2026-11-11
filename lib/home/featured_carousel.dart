import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../reader/position_controller.dart';
import 'featured_card.dart';
import 'topic_progress.dart';

const _dotSize = 6.0;

/// One [FeaturedCard] per topic, in library order, side by side: swipe, the
/// screen reader's increase and decrease, or (with a card focused) the left
/// and right arrow keys move a page. It never moves by itself. Dots under it
/// show the page. It starts on the topic of the last-read reading.
///
/// It is as tall as its tallest page at the current width and text size, so
/// no page is ever cut off (every page is laid out unseen to measure it).
/// With one topic it is that topic's card alone.
class FeaturedCarousel extends ConsumerStatefulWidget {
  const FeaturedCarousel({super.key, required this.library});

  final Library library;

  @override
  ConsumerState<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends ConsumerState<FeaturedCarousel> {
  late final PageController _controller;
  late int _page;

  /// One per page, round the page's card, to move the focus with the page.
  final _pageNodes = <int, FocusNode>{};

  List<Category> get _topics => widget.library.categories;

  @override
  void initState() {
    super.initState();
    // Read once: the carousel does not jump when a place is saved later.
    _page = startTopicIndex(widget.library, ref.read(positionProvider));
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final n in _pageNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _nodeFor(int i) => _pageNodes.putIfAbsent(
    i,
    () => FocusNode(debugLabel: 'featured page $i', skipTraversal: true),
  );

  /// Moves to [target]; with [refocus], the focus goes to its card.
  Future<void> _goTo(int target, {bool refocus = false}) async {
    if (target < 0 || target >= _topics.length || !_controller.hasClients) {
      return;
    }
    final duration = NamoMotion.of(context, NamoMotion.open);
    if (duration == Duration.zero) {
      _controller.jumpToPage(target);
    } else {
      await _controller.animateToPage(
        target,
        duration: duration,
        curve: NamoMotion.curve,
      );
    }
    if (!refocus) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _nodeFor(target).traversalDescendants.firstOrNull?.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.arrowLeft => -1,
      _ => 0,
    };
    if (step == 0) return KeyEventResult.ignored;
    final target = _page + step;
    if (target < 0 || target >= _topics.length) return KeyEventResult.ignored;
    _goTo(target, refocus: true);
    return KeyEventResult.handled;
  }

  String _value(int page) => 'Page ${page + 1} of ${_topics.length}';

  @override
  Widget build(BuildContext context) {
    final topics = _topics;
    if (topics.isEmpty) return const SizedBox.shrink();
    if (topics.length == 1) return FeaturedCard(category: topics.single);

    final p = NamoPalette.of(context);
    final page = _page.clamp(0, topics.length - 1);
    final pager = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: PageView.builder(
        controller: _controller,
        itemCount: topics.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (context, i) => Focus(
          focusNode: _nodeFor(i),
          canRequestFocus: false,
          child: FeaturedCard(category: topics[i]),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: 'Featured collections',
      value: _value(page),
      increasedValue: page < topics.length - 1 ? _value(page + 1) : null,
      decreasedValue: page > 0 ? _value(page - 1) : null,
      onIncrease: page < topics.length - 1 ? () => _goTo(page + 1) : null,
      onDecrease: page > 0 ? () => _goTo(page - 1) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TallestPage(
            children: [
              pager,
              // Laid out to measure, never painted, hit, focused or read.
              for (final c in topics)
                ExcludeSemantics(
                  child: ExcludeFocus(
                    child: TickerMode(
                      enabled: false,
                      child: FeaturedCard(category: c),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: NamoSpace.md),
          ExcludeSemantics(
            child: Row(
              key: const ValueKey('featured-dots'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < topics.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _dotSize / 2),
                    child: SizedBox.square(
                      dimension: _dotSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == page ? p.gold : p.border,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows its first child at the height of the tallest of the others, which
/// are laid out at the full width only to be measured: they are not
/// painted, hit tested or put in the semantics tree, and finders treat them
/// as offstage.
class _TallestPage extends MultiChildRenderObjectWidget {
  const _TallestPage({required super.children});

  @override
  MultiChildRenderObjectElement createElement() => _TallestPageElement(this);

  @override
  _RenderTallestPage createRenderObject(BuildContext context) =>
      _RenderTallestPage();
}

class _TallestPageElement extends MultiChildRenderObjectElement {
  _TallestPageElement(super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final shown = children.firstOrNull;
    if (shown != null) visitor(shown);
  }
}

class _TallestPageParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTallestPage extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TallestPageParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TallestPageParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TallestPageParentData) {
      child.parentData = _TallestPageParentData();
    }
  }

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth);
    final width = constraints.maxWidth;
    var height = 0.0;
    for (var m = childAfter(firstChild!); m != null; m = childAfter(m)) {
      m.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
      height = math.max(height, m.size.height);
    }
    size = constraints.constrain(Size(width, height));
    firstChild!.layout(BoxConstraints.tight(size));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(firstChild!, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      firstChild!.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final shown = firstChild;
    if (shown != null) visitor(shown);
  }
}
