/// Turning pages with a curl drawn by the app: the page's corner follows the
/// finger, and arrows, taps and keys turn with the same curl on their own.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../design/tokens.dart';
import 'curl_geometry.dart';

/// Turns the pages of a [PageCurl] from outside it (arrows, keys).
class PageCurlController extends ChangeNotifier {
  _PageCurlState? _state;

  /// Whether a page is being turned (dragged or animating).
  bool get turning => _state?._busy ?? false;

  /// Turns to the next page with the curl; completes when the turn has
  /// ended. Does nothing while turning or when there is no next page.
  Future<void> turnForward() => _state?._turnAlone(_Turn.forward) ?? _done;

  /// Turns back to the previous page; as [turnForward].
  Future<void> turnBack() => _state?._turnAlone(_Turn.back) ?? _done;

  void _changed() => notifyListeners();

  static final _done = Future<void>.value();
}

/// Shows [current] and turns it like paper: a drag from near the right edge
/// lifts the bottom (or top) corner and turns forward to [next], a drag
/// from near the left edge brings [previous] back. Released past half the
/// page width, or flung faster than 700 px/s the turn's way, the turn
/// completes and [onTurnedForward] / [onTurnedBack] is called (the caller
/// then gives new pages); otherwise the page falls back. A tap in the outer
/// fifth of either side turns too. With reduced motion pages change at
/// once with no curl.
///
/// [next] and [previous] are kept laid out and painted beneath [current]
/// (hidden from touch, focus and screen readers) so that each can be
/// photographed when a turn starts; the curl then animates those pictures.
class PageCurl extends StatefulWidget {
  const PageCurl({
    super.key,
    required this.current,
    required this.next,
    required this.previous,
    required this.onTurnedForward,
    required this.onTurnedBack,
    required this.controller,
  });

  final Widget current;
  final Widget? next;
  final Widget? previous;
  final VoidCallback onTurnedForward;
  final VoidCallback onTurnedBack;
  final PageCurlController controller;

  @override
  State<PageCurl> createState() => _PageCurlState();
}

enum _Turn { forward, back }

/// A drag can start a turn this close to a side: 15% of the width, at least
/// 48 px.
double _edgeWidth(double width) => math.max(width * 0.15, 48);

/// A turn flung faster than this (logical px/s) its own way completes.
const _flingVelocity = 700.0;

/// A turn under way: which way, which corner, and the pictures it animates
/// (none when they could not be taken; then the live pages are clipped).
class _Curl {
  _Curl({
    required this.turn,
    required this.top,
    required this.drawn,
    this.turning,
    this.beneath,
  });

  final _Turn turn;
  final bool top;

  /// False under reduced motion: the turn is tracked but nothing is drawn.
  final bool drawn;

  /// The page being turned (current going forward, previous coming back).
  final ui.Image? turning;

  /// The page beneath it (next going forward, current coming back).
  final ui.Image? beneath;

  bool get pictured => turning != null && beneath != null;

  void dispose() {
    turning?.dispose();
    beneath?.dispose();
  }
}

class _PageCurlState extends State<PageCurl>
    with SingleTickerProviderStateMixin {
  final _currentKey = GlobalKey(debugLabel: 'page-curl-current');
  final _nextKey = GlobalKey(debugLabel: 'page-curl-next');
  final _previousKey = GlobalKey(debugLabel: 'page-curl-previous');
  final _geometry = ValueNotifier<CurlGeometry?>(null);
  late final _frontClip = _FrontClipper(_geometry);
  late final AnimationController _animation;

  Size _size = Size.zero;
  _Curl? _curl;

  /// A turn with no finger is waiting for the pages to be painted.
  bool _starting = false;

  bool get _busy => _curl != null || _starting;

  /// Where the turning corner is held, as the finger given to
  /// [CurlGeometry.forward] or [CurlGeometry.backward].
  Offset _held = Offset.zero;

  // The drag in progress: the way it may turn, where it went down, and
  // whether it has started a turn.
  _Turn? _dragTurn;
  Offset _down = Offset.zero;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this);
    widget.controller._state = this;
  }

  @override
  void didUpdateWidget(PageCurl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller._state == this) {
        oldWidget.controller._state = null;
      }
      widget.controller._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _animation.dispose();
    _curl?.dispose();
    _geometry.dispose();
    super.dispose();
  }

  Duration get _duration => NamoMotion.of(context, NamoMotion.open);

  double get _cornerY => (_curl?.top ?? false) ? 0 : _size.height;

  Widget? _target(_Turn turn) =>
      turn == _Turn.forward ? widget.next : widget.previous;

  // --- Turning -------------------------------------------------------------

  /// Starts a turn: photographs the turning page and the one beneath, unless
  /// nothing will be drawn.
  void _begin(_Turn turn, {required bool top, required bool drawn}) {
    ui.Image? turning;
    ui.Image? beneath;
    if (drawn) {
      final forward = turn == _Turn.forward;
      turning = _snapshot(forward ? _currentKey : _previousKey);
      beneath = _snapshot(forward ? _nextKey : _currentKey);
    }
    setState(() {
      _curl = _Curl(
        turn: turn,
        top: top,
        drawn: drawn,
        turning: turning,
        beneath: beneath,
      );
    });
    widget.controller._changed();
  }

  ui.Image? _snapshot(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary) return null;
    try {
      return box.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } catch (_) {
      // Not painted yet, or no pictures on this renderer: the live pages
      // are clipped instead.
      return null;
    }
  }

  CurlGeometry _shape(Offset held) {
    final curl = _curl!;
    return curl.turn == _Turn.forward
        ? CurlGeometry.forward(_size, held, top: curl.top)
        : CurlGeometry.backward(_size, held, top: curl.top);
  }

  void _hold(Offset held) {
    _held = held;
    if (_curl!.drawn) _geometry.value = _shape(held);
  }

  /// Ends the turn; calls back when it completed.
  void _end({required bool completed}) {
    final curl = _curl;
    if (curl == null || !mounted) return;
    curl.dispose();
    _geometry.value = null;
    setState(() => _curl = null);
    widget.controller._changed();
    if (completed) {
      curl.turn == _Turn.forward
          ? widget.onTurnedForward()
          : widget.onTurnedBack();
    }
  }

  /// Moves the held corner from where it is to [to]; with [lift] it rises a
  /// little on the way, as a hand turning a page would lift it.
  Future<void> _move(Offset to, {bool lift = false}) async {
    final from = _held;
    // A forward turn's corner travels from the right edge past the spine
    // (2 widths), a back turn's held finger across the page (1 width).
    final range = _curl!.turn == _Turn.forward ? 2 * _size.width : _size.width;
    final share = ((to - from).distance / range).clamp(0.35, 1.0);
    _animation.duration = _duration * share;
    final curve = lift ? Curves.easeInOut : Curves.easeOut;
    void step() {
      final t = curve.transform(_animation.value);
      final rise = lift ? math.sin(math.pi * t) * _size.height * 0.12 : 0.0;
      final at = Offset.lerp(from, to, t)!;
      _hold(Offset(at.dx, _curl!.top ? at.dy + rise : at.dy - rise));
    }

    _animation.addListener(step);
    try {
      await _animation.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Disposed mid-turn.
    } finally {
      _animation.removeListener(step);
    }
  }

  /// Where a turn's corner rests when it has completed or fallen back.
  Offset _rest(_Turn turn, {required bool completed}) {
    final w = _size.width;
    return switch ((turn, completed)) {
      (_Turn.forward, true) => Offset(-w, _cornerY),
      (_Turn.forward, false) => Offset(w, _cornerY),
      (_Turn.back, true) => Offset(w, _cornerY),
      (_Turn.back, false) => Offset(0, _cornerY),
    };
  }

  /// A turn with no finger: arrows, taps and keys.
  Future<void> _turnAlone(_Turn turn) async {
    if (_busy || _target(turn) == null || _size.isEmpty) return;
    if (_duration == Duration.zero) {
      turn == _Turn.forward ? widget.onTurnedForward() : widget.onTurnedBack();
      return;
    }
    // The pages may have been given this very frame (a turn straight after
    // a turn): wait until they are painted, so the pictures are of them and
    // not of the pages before.
    _starting = true;
    widget.controller._changed();
    await SchedulerBinding.instance.endOfFrame;
    _starting = false;
    if (!mounted) return;
    if (_target(turn) == null || _size.isEmpty) {
      widget.controller._changed();
      return;
    }
    _begin(turn, top: false, drawn: true);
    _hold(_rest(turn, completed: false));
    await _move(_rest(turn, completed: true), lift: true);
    _end(completed: true);
  }

  // --- Gestures ------------------------------------------------------------

  void _tapUp(TapUpDetails d) {
    final x = d.localPosition.dx;
    final fifth = _size.width / 5;
    if (x >= _size.width - fifth) {
      _turnAlone(_Turn.forward);
    } else if (x <= fifth) {
      _turnAlone(_Turn.back);
    }
  }

  void _panDown(DragDownDetails d) {
    _dragging = false;
    _dragTurn = null;
    if (_busy) return;
    _down = d.localPosition;
    final edge = _edgeWidth(_size.width);
    if (_down.dx >= _size.width - edge && widget.next != null) {
      _dragTurn = _Turn.forward;
    } else if (_down.dx <= edge && widget.previous != null) {
      _dragTurn = _Turn.back;
    }
  }

  void _panUpdate(DragUpdateDetails d) {
    final turn = _dragTurn;
    if (turn == null) return;
    final finger = d.localPosition;
    if (!_dragging) {
      final moved = finger - _down;
      if (moved.distance < kTouchSlop) return;
      if (moved.dy.abs() > moved.dx.abs() || _busy) {
        _dragTurn = null;
        return;
      }
      _begin(
        turn,
        top: _down.dy < _size.height / 2,
        drawn: _duration != Duration.zero,
      );
      _dragging = true;
    }
    _hold(_heldFor(turn, finger));
  }

  /// The corner keeps its offset from the finger, so it does not jump to the
  /// finger when the drag starts.
  Offset _heldFor(_Turn turn, Offset finger) {
    final w = _size.width;
    final y = (finger.dy + _cornerY - _down.dy).clamp(0.0, _size.height);
    final x = turn == _Turn.forward
        ? (finger.dx + w - _down.dx).clamp(-w, w)
        : (finger.dx - _down.dx).clamp(0.0, w);
    return Offset(x, y);
  }

  void _panEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final curl = _curl!;
    final velocity = d.velocity.pixelsPerSecond.dx;
    final along = curl.turn == _Turn.forward ? -velocity : velocity;
    final completed = _shape(_held).progress > 0.5 || along > _flingVelocity;
    _settle(completed: completed);
  }

  void _panCancel() {
    if (!_dragging) return;
    _dragging = false;
    _settle(completed: false);
  }

  Future<void> _settle({required bool completed}) async {
    final curl = _curl!;
    if (curl.drawn) await _move(_rest(curl.turn, completed: completed));
    _end(completed: completed);
  }

  // --- Drawing -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = NamoPalette.of(context);
    final curl = _curl;
    final drawn = curl != null && curl.drawn;
    final live = drawn && !curl.pictured;
    final back = curl?.turn == _Turn.back;

    Widget layer(
      String name,
      GlobalKey key,
      Widget child, {
      bool active = false,
      bool clipped = false,
    }) => KeyedSubtree(
      key: ValueKey('page-curl-$name'),
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeSemantics(
          excluding: !active,
          child: ExcludeFocus(
            excluding: !active,
            child: ClipPath(
              clipper: clipped ? _frontClip : null,
              clipBehavior: clipped ? Clip.antiAlias : Clip.none,
              child: RepaintBoundary(
                key: key,
                child: ColoredBox(color: palette.background, child: child),
              ),
            ),
          ),
        ),
      ),
    );

    final previous = widget.previous == null
        ? null
        : layer(
            'previous',
            _previousKey,
            widget.previous!,
            clipped: live && back,
          );
    final next = widget.next == null
        ? null
        : layer('next', _nextKey, widget.next!);
    final current = layer(
      'current',
      _currentKey,
      widget.current,
      active: true,
      clipped: live && !back,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _tapUp,
          onPanDown: _panDown,
          onPanUpdate: _panUpdate,
          onPanEnd: _panEnd,
          onPanCancel: _panCancel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The page turning back comes over the current one.
              if (back) ...[
                ?next,
                current,
                ?previous,
              ] else ...[
                ?previous,
                ?next,
                current,
              ],
              if (drawn)
                IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('page-curl-paint'),
                    painter: _CurlPainter(
                      geometry: _geometry,
                      turning: curl.turning,
                      beneath: curl.beneath,
                      palette: palette,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Clips a live page to the part still lying flat.
class _FrontClipper extends CustomClipper<Path> {
  _FrontClipper(this.geometry) : super(reclip: geometry);

  final ValueListenable<CurlGeometry?> geometry;

  @override
  Path getClip(Size size) =>
      geometry.value?.frontVisible ?? (Path()..addRect(Offset.zero & size));

  @override
  bool shouldReclip(_FrontClipper oldClipper) =>
      oldClipper.geometry != geometry;
}

/// Paints one frame of the curl: the page beneath, a shadow on it along the
/// fold, the flat part of the turning page, and its back as a tinted mirror
/// with a highlight across the bend. Without pictures only the shading and
/// an untextured back are painted over the clipped live pages.
class _CurlPainter extends CustomPainter {
  _CurlPainter({
    required this.geometry,
    required this.turning,
    required this.beneath,
    required this.palette,
  }) : super(repaint: geometry);

  final ValueListenable<CurlGeometry?> geometry;
  final ui.Image? turning;
  final ui.Image? beneath;
  final NamoPalette palette;

  static final _picture = Paint()..filterQuality = FilterQuality.low;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry.value;
    if (g == null) return;
    final page = Offset.zero & size;
    final turning = this.turning;
    final beneath = this.beneath;
    final pictured = turning != null && beneath != null;
    final shadow = palette.curlShadow;
    final across = g.across;
    final fold = (g.corner + g.point) / 2;
    final depth = g.flapDepth;

    if (pictured) _draw(canvas, beneath, page);

    if (depth > 0) {
      // The page beneath is shaded where the turning page bends over it.
      final reach = (depth * 0.5).clamp(6.0, 40.0);
      canvas
        ..save()
        ..clipPath(g.revealed)
        ..drawRect(
          page,
          Paint()
            ..shader = ui.Gradient.linear(fold, fold - across * reach, [
              shadow,
              shadow.withValues(alpha: 0),
            ]),
        )
        ..restore();
    }

    if (pictured) {
      canvas
        ..save()
        ..clipPath(g.frontVisible);
      _draw(canvas, turning, page);
      canvas.restore();
    }

    if (depth > 0) {
      canvas
        ..drawShadow(g.backFlap, shadow, 3, false)
        ..save()
        ..clipPath(g.backFlap);
      if (pictured) {
        canvas
          ..save()
          ..transform(g.mirror);
        _draw(canvas, turning, page);
        canvas.restore();
      }
      final highlight = palette.curlHighlight;
      canvas
        ..drawRect(
          page,
          Paint()
            ..color = palette.surface.withValues(alpha: pictured ? 0.85 : 1),
        )
        ..drawRect(
          page,
          Paint()
            ..shader = ui.Gradient.linear(
              fold,
              fold + across * depth,
              [
                shadow.withValues(alpha: shadow.a * 0.6),
                highlight,
                highlight.withValues(alpha: 0),
              ],
              const [0, 0.35, 1],
            ),
        )
        ..restore();
    }
  }

  void _draw(Canvas canvas, ui.Image image, Rect page) => canvas.drawImageRect(
    image,
    Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
    page,
    _picture,
  );

  @override
  bool shouldRepaint(_CurlPainter old) =>
      old.geometry != geometry ||
      old.turning != turning ||
      old.beneath != beneath ||
      old.palette != palette;
}
