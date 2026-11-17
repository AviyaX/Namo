import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import 'tip_anchor.dart';
import 'tip_bubble.dart';
import 'tips.dart';

/// The smallest rect holding every one of [rects] (there must be one).
Rect unionRect(Iterable<Rect> rects) =>
    rects.reduce((a, b) => a.expandToInclude(b));

/// The hole in the scrim round the anchors: a little room on every side.
Rect cutoutFor(Rect anchorsUnion) => anchorsUnion.inflate(6);

/// Puts the bubble below the cut-out when it fits there, else above, centred
/// on the cut-out and kept [margin] from every edge.
class BubbleLayoutDelegate extends SingleChildLayoutDelegate {
  BubbleLayoutDelegate({
    required this.cutout,
    required this.margin,
    required this.gap,
  });

  final Rect cutout;
  final double margin;

  /// Between the cut-out and the bubble.
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.deflate(EdgeInsets.all(margin)).loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below =
        cutout.bottom + gap + childSize.height <= size.height - margin;
    // A bubble too tall for either side stays on screen over the cut-out.
    final maxY = math.max(margin, size.height - margin - childSize.height);
    final y = (below ? cutout.bottom + gap : cutout.top - gap - childSize.height)
        .clamp(margin, maxY);
    final maxX = math.max(margin, size.width - margin - childSize.width);
    final x = (cutout.center.dx - childSize.width / 2).clamp(margin, maxX);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(BubbleLayoutDelegate oldDelegate) =>
      cutout != oldDelegate.cutout ||
      margin != oldDelegate.margin ||
      gap != oldDelegate.gap;
}

/// Shows the first due tip of [tipsFor] whose anchors are all on screen,
/// over [child]: a scrim with a hole round the anchors and a bubble beside
/// it. One tap anywhere, Back or Escape dismisses it for good.
class TipHost extends ConsumerStatefulWidget {
  const TipHost({
    super.key,
    required this.tipsFor,
    required this.child,
    this.canShow,
    this.reevaluateOn = const [],
  });

  /// This screen's tips, in the order they are offered.
  final List<Tip> Function() tipsFor;
  final Widget child;

  /// False keeps [tip] back for now (for instance while a sheet is open).
  final bool Function(Tip tip)? canShow;

  /// Changes that can make a tip showable, or not, without a rebuild here.
  final List<Listenable> reevaluateOn;

  @override
  ConsumerState<TipHost> createState() => _TipHostState();
}

class _TipHostState extends ConsumerState<TipHost> {
  late final ProviderContainer _container;
  late final TipAnchors _anchors;

  /// The tip this host asked for and is showing, if any.
  Tip? _mine;
  Rect _cutout = Rect.zero;
  bool _evaluateScheduled = false;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _anchors = ref.read(tipAnchorsProvider)..addListener(_schedule);
    for (final l in widget.reevaluateOn) {
      l.addListener(_schedule);
    }
  }

  @override
  void didUpdateWidget(TipHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final l in oldWidget.reevaluateOn) {
      l.removeListener(_schedule);
    }
    for (final l in widget.reevaluateOn) {
      l.addListener(_schedule);
    }
  }

  @override
  void dispose() {
    _anchors.removeListener(_schedule);
    for (final l in widget.reevaluateOn) {
      l.removeListener(_schedule);
    }
    final mine = _mine;
    if (mine != null) {
      // No provider may change while the tree is being torn down.
      final container = _container;
      scheduleMicrotask(() {
        try {
          container.read(tipsProvider.notifier).withdraw(mine);
        } on StateError {
          // The whole scope went with this host: nothing is left to withdraw.
        }
      });
    }
    super.dispose();
  }

  /// Evaluates once the frame now being built, or the next one, is laid out.
  void _schedule() {
    if (_evaluateScheduled || !mounted) return;
    _evaluateScheduled = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _evaluate())
      ..ensureVisualUpdate();
  }

  void _evaluate() {
    _evaluateScheduled = false;
    if (!mounted) return;
    final host = context.findRenderObject();
    if (host is! RenderBox || !host.hasSize) return;
    final tips = ref.read(tipsProvider.notifier);
    final active = ref.read(tipsProvider).active;

    final mine = _mine;
    if (mine != null && active == mine) {
      final rects = _showable(mine, host);
      if (rects == null) {
        _mine = null;
        tips.withdraw(mine);
      } else {
        final cutout = cutoutFor(unionRect(rects));
        if (cutout != _cutout) setState(() => _cutout = cutout);
      }
      return;
    }
    _mine = null;
    if (active != null) return;

    for (final tip in widget.tipsFor()) {
      if (!tips.isDue(tip)) continue;
      final rects = _showable(tip, host);
      if (rects == null) continue;
      if (tips.request(tip)) {
        setState(() {
          _mine = tip;
          _cutout = cutoutFor(unionRect(rects));
        });
      }
      return;
    }
  }

  /// The rects of [tip]'s anchors, measured in this host, when the tip may
  /// show now; null when it may not.
  List<Rect>? _showable(Tip tip, RenderBox host) {
    if (!ref.read(tipsAllowedProvider)) return null;
    if (ModalRoute.of(context)?.isCurrent != true) return null;
    final bounds = Offset.zero & host.size;
    final rects = <Rect>[];
    for (final key in _anchors.keysFor(tip)) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox ||
          !box.attached ||
          !box.hasSize ||
          box.size.isEmpty ||
          !_isWithin(box, host)) {
        continue;
      }
      final rect = box.localToGlobal(Offset.zero, ancestor: host) & box.size;
      // A control partly off screen waits until it is scrolled in.
      if (rect.left < bounds.left ||
          rect.top < bounds.top ||
          rect.right > bounds.right ||
          rect.bottom > bounds.bottom) {
        return null;
      }
      rects.add(rect);
    }
    if (rects.isEmpty) return null;
    if (widget.canShow?.call(tip) == false) return null;
    return rects;
  }

  /// Anchors of the same tip on another screen are not this host's.
  static bool _isWithin(RenderObject box, RenderObject host) {
    for (RenderObject? o = box; o != null; o = o.parent) {
      if (identical(o, host)) return true;
    }
    return false;
  }

  void _dismiss() {
    _mine = null;
    ref.read(tipsProvider.notifier).dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(tipsProvider).active;
    ref.watch(tipsAllowedProvider);
    // Rebuilt, and so re-evaluated, when a route goes over this one or away.
    ModalRoute.isCurrentOf(context);
    _schedule();
    final showing = _mine != null && active == _mine ? _mine : null;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        ExcludeSemantics(
          excluding: showing != null,
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              _schedule();
              return false;
            },
            child: widget.child,
          ),
        ),
        if (showing != null)
          Positioned.fill(
            child: _TipLayer(
              tip: showing,
              cutout: _cutout,
              onDismiss: _dismiss,
            ),
          ),
      ],
    );
  }
}

/// The scrim, its hole and the bubble. Every tap, Back and Escape dismiss;
/// nothing reaches the page underneath, not even through the hole.
class _TipLayer extends StatefulWidget {
  const _TipLayer({
    required this.tip,
    required this.cutout,
    required this.onDismiss,
  });

  final Tip tip;
  final Rect cutout;
  final VoidCallback onDismiss;

  @override
  State<_TipLayer> createState() => _TipLayerState();
}

class _TipLayerState extends State<_TipLayer> {
  bool _faded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _faded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final duration = NamoMotion.of(context, NamoMotion.open);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onDismiss();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): widget.onDismiss,
        },
        child: Focus(
          autofocus: true,
          child: AnimatedOpacity(
            opacity: _faded || duration == Duration.zero ? 1 : 0,
            duration: duration,
            curve: NamoMotion.curve,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              // The bubble's text has no Material page under it.
              child: Material(
                type: MaterialType.transparency,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Dismiss tip',
                      onTap: widget.onDismiss,
                      child: CustomPaint(
                        key: const ValueKey('tip-scrim'),
                        painter: _ScrimPainter(widget.cutout),
                      ),
                    ),
                    CustomSingleChildLayout(
                      delegate: BubbleLayoutDelegate(
                        cutout: widget.cutout,
                        margin: NamoSpace.lg,
                        gap: NamoSpace.md,
                      ),
                      child: TipBubble(
                        tip: widget.tip,
                        onGotIt: widget.onDismiss,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  _ScrimPainter(this.cutout);

  final Rect cutout;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          cutout,
          const Radius.circular(NamoRadius.md),
        )),
    );
    canvas.drawPath(
      scrim,
      Paint()..color = NamoPalette.pictureScrim.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) => cutout != oldDelegate.cutout;
}
