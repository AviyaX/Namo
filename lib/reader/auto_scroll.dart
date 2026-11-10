import 'package:flutter/widgets.dart';

enum AutoScrollStatus { stopped, running, paused, finished }

/// Moves the page down at an even speed, one step per screen frame.
///
/// The engine has no clock of its own: its owner calls [onFrame] once per
/// frame (from a `Ticker`) while [status] is [AutoScrollStatus.running].
/// It keeps its own fractional target, so slow speeds still move by less
/// than a pixel a frame. If the page is found away from that target,
/// something else moved it (a finger, a mouse wheel, the keyboard), and the
/// engine pauses rather than pull the page back.
class AutoScrollEngine extends ChangeNotifier {
  AutoScrollEngine({required this._controller, required double speed})
    : _speed = _clamp(speed);

  /// Speeds in logical pixels per second.
  static const slow = 12.0,
      normal = 22.0,
      fast = 36.0,
      minSpeed = 6.0,
      maxSpeed = 60.0;

  /// The most time one frame may account for, so a long gap (a stalled tab,
  /// a debugger) does not throw the page forward.
  static const maxStep = Duration(milliseconds: 100);

  /// How far the page may be from the target before it counts as moved by
  /// something else.
  static const _drift = 1.0;

  final ScrollController _controller;
  double _speed;
  double _target = 0;
  AutoScrollStatus _status = AutoScrollStatus.stopped;

  static double _clamp(double v) => v.clamp(minSpeed, maxSpeed);

  AutoScrollStatus get status => _status;

  double get speed => _speed;

  /// Clamped to [minSpeed]–[maxSpeed]; while running, the next frame moves
  /// at the new speed.
  set speed(double v) {
    final next = _clamp(v);
    if (next == _speed) return;
    _speed = next;
    notifyListeners();
  }

  void _setStatus(AutoScrollStatus next) {
    if (next == _status) return;
    _status = next;
    notifyListeners();
  }

  /// Starts from the page's current offset; after finishing, or with the
  /// page already at its very end, from the top.
  void play() {
    if (!_controller.hasClients) return;
    final end = _controller.position.maxScrollExtent;
    final atEnd = end > 0 && _controller.offset >= end;
    if (_status == AutoScrollStatus.finished || atEnd) _controller.jumpTo(0);
    _target = _controller.offset;
    _setStatus(AutoScrollStatus.running);
  }

  void pause() {
    if (_status == AutoScrollStatus.running) {
      _setStatus(AutoScrollStatus.paused);
    }
  }

  /// Back to the top, stopped.
  void reset() {
    if (_controller.hasClients) _controller.jumpTo(0);
    _target = 0;
    _setStatus(AutoScrollStatus.stopped);
  }

  /// The page was moved on purpose (previous/next, a restore): carry on
  /// from where it now is.
  void syncToPage() {
    if (_controller.hasClients) _target = _controller.offset;
  }

  /// Moves the page by [speed] for [sinceLastFrame], at most [maxStep].
  void onFrame(Duration sinceLastFrame) {
    if (_status != AutoScrollStatus.running || !_controller.hasClients) {
      return;
    }
    if ((_controller.offset - _target).abs() > _drift) {
      pause();
      return;
    }
    final step = sinceLastFrame > maxStep ? maxStep : sinceLastFrame;
    _target += _speed * step.inMicroseconds / Duration.microsecondsPerSecond;
    final end = _controller.position.maxScrollExtent;
    if (_target >= end) {
      _target = end;
      _controller.jumpTo(end);
      _setStatus(AutoScrollStatus.finished);
    } else {
      _controller.jumpTo(_target);
    }
  }
}
