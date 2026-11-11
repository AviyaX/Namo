import 'dart:async';

import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_player.dart';

/// A player with no sound: time passes only when a test calls [advance].
class FakeChantPlayer implements ChantPlayer {
  FakeChantPlayer({
    this.failOnLoad = false,
    this.length = const Duration(seconds: 20),
  });

  /// Makes [load] end in [ChantStatus.failed]; a test may switch it off.
  bool failOnLoad;

  /// The length of every recording this player loads.
  final Duration length;

  /// While set, [load] stays in [ChantStatus.loading] until it completes.
  Completer<void>? gate;

  /// Every recording passed to [load], in order.
  final loaded = <Recording>[];

  final _controller = StreamController<ChantState>.broadcast();
  ChantState _state = const ChantState();
  bool disposed = false;

  @override
  ChantState get state => _state;

  @override
  Stream<ChantState> get states => _controller.stream;

  void _set(ChantState s) {
    _state = s;
    if (!_controller.isClosed) _controller.add(s);
  }

  /// Lets [d] of the recording pass, if it is playing.
  void advance(Duration d) {
    if (_state.status != ChantStatus.playing) return;
    final to = _state.position + d;
    if (to >= length) {
      _set(ChantState(
          status: ChantStatus.completed, position: length, duration: length));
    } else {
      _set(ChantState(
          status: ChantStatus.playing, position: to, duration: length));
    }
  }

  @override
  Future<void> load(Recording r) async {
    loaded.add(r);
    final g = gate;
    if (g != null) {
      _set(const ChantState(status: ChantStatus.loading));
      await g.future;
    }
    _set(failOnLoad
        ? const ChantState(status: ChantStatus.failed)
        : ChantState(status: ChantStatus.ready, duration: length));
  }

  @override
  Future<void> play() async {
    if (_state.status == ChantStatus.idle ||
        _state.status == ChantStatus.loading ||
        _state.status == ChantStatus.failed) {
      return;
    }
    final from = _state.status == ChantStatus.completed
        ? Duration.zero
        : _state.position;
    _set(ChantState(
        status: ChantStatus.playing, position: from, duration: length));
  }

  @override
  Future<void> pause() async {
    if (_state.status != ChantStatus.playing) return;
    _set(ChantState(
        status: ChantStatus.paused,
        position: _state.position,
        duration: length));
  }

  @override
  Future<void> restart() async {
    await seek(Duration.zero);
    await play();
  }

  @override
  Future<void> seek(Duration to) async {
    if (_state.status == ChantStatus.idle ||
        _state.status == ChantStatus.failed) {
      return;
    }
    final status = _state.status == ChantStatus.completed
        ? ChantStatus.paused
        : _state.status;
    _set(ChantState(status: status, position: to, duration: length));
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}
