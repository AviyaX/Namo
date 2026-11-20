import 'dart:async';

import 'audio_catalogue.dart';
import 'chant_player.dart';
import 'chant_programme.dart';

/// A leg whose file is not on the device yet, and where in it the chant goes
/// on when it arrives.
typedef Awaiting = ({int leg, Duration at});

/// How far before a leg's end a position past it is held: the next leg
/// starts at that end, and its first block often at 0 s in its file.
const _belowLegEnd = Duration(microseconds: 1);

/// Plays a ChantProgramme's legs in turn on one ChantPlayer and reports one
/// state on the programme's timeline.
///
/// One leg: the inner state as it is. Several legs: position = the leg's
/// start + the inner position (held just below the leg's end), duration = the
/// programme's total. While a leg's file is awaited: paused at that leg's
/// start + the awaited point.
class ProgrammePlayer {
  ProgrammePlayer(this._inner, {required this._isAvailable}) {
    _subscription = _inner.states.listen(_onInner);
  }

  final ChantPlayer _inner;
  final bool Function(Recording) _isAvailable;
  final _controller = StreamController<ChantState>.broadcast();
  late final StreamSubscription<ChantState> _subscription;

  ChantProgramme? _programme;
  int? _leg;
  Awaiting? _awaiting;
  bool _armed = false;

  /// True while this player's own load of a leg is under way.
  bool _loading = false;

  /// Whether the leg being loaded plays once it is; a pause while it loads
  /// clears it.
  bool _playOnLoad = false;

  /// Counts playLeg, bind and dispose, so an overtaken playLeg can tell.
  int _gen = 0;

  /// After [dispose] nothing reaches the inner player, which outlives this.
  bool _disposed = false;
  ChantState _state = const ChantState();

  /// Called when the chant needs a leg whose file is not available; the
  /// reader starts the download.
  void Function(int leg)? onAwait;

  ChantState get state => _state;

  /// Broadcast; a state is sent only when it differs from the last.
  Stream<ChantState> get states => _controller.stream;

  ChantProgramme? get programme => _programme;

  /// The leg loaded in the inner player.
  int? get leg => _leg;

  Awaiting? get awaiting => _awaiting;

  /// The chant should go on when the awaited file arrives.
  bool get armed => _armed;

  /// Stores [p]; loads nothing (the first [play] loads).
  void bind(ChantProgramme p) {
    if (_disposed) return;
    _gen++;
    _programme = p;
    _leg = null;
    _awaiting = null;
    _armed = false;
    _loading = false;
    _publish(const ChantState());
  }

  void _publish(ChantState next) {
    if (_controller.isClosed || next == _state) return;
    _state = next;
    _controller.add(next);
  }

  void _onInner(ChantState s) {
    final p = _programme;
    final k = _leg;
    // Only this player's own leg is reported, and nothing while waiting.
    if (p == null || k == null || _awaiting != null) return;
    // A state already replaced by a newer one; that one follows.
    if (s != _inner.state) return;
    if (p.single) {
      _publish(s);
      return;
    }
    if (s.status == ChantStatus.completed &&
        !_loading &&
        k < p.legs.length - 1) {
      unawaited(playLeg(k + 1));
      return;
    }
    final leg = p.legs[k];
    final length = leg.recording.duration;
    // Never the leg's end itself: that is where the next leg begins.
    final inLeg = s.position < length ? s.position : length - _belowLegEnd;
    var status = s.status;
    // Past the programme's very start, a stop reads "paused", not "ready".
    if (status == ChantStatus.ready && (k > 0 || s.position > Duration.zero)) {
      status = ChantStatus.paused;
    }
    _publish(
      ChantState(
        status: status,
        position: status == ChantStatus.completed ? p.total : leg.start + inLeg,
        duration: p.total,
      ),
    );
  }

  /// Plays [leg] from [at] (or stays paused there); waits for it when its file
  /// is not available.
  Future<void> playLeg(
    int leg, {
    Duration at = Duration.zero,
    bool play = true,
  }) async {
    final p = _programme;
    if (p == null || _disposed) return;
    final gen = ++_gen;
    final target = p.legs[leg];
    if (!_isAvailable(target.recording)) {
      _loading = false;
      _awaiting = (leg: leg, at: at);
      _armed = play;
      _publish(
        ChantState(
          status: ChantStatus.paused,
          position: target.start + at,
          duration: p.total,
        ),
      );
      onAwait?.call(leg);
      // The leg playing now stops while the next one is awaited.
      await _inner.pause();
      return;
    }
    _awaiting = null;
    _armed = false;
    final status = _inner.state.status;
    // A load still under way is not loaded: an overtaking call loads again.
    final loaded =
        _leg == leg &&
        status != ChantStatus.idle &&
        status != ChantStatus.loading &&
        status != ChantStatus.failed;
    // The newest call owns the flags; an overtaken one leaves them alone.
    _loading = !loaded;
    _playOnLoad = play;
    if (!loaded) {
      // just_audio stays "playing" after the end, and a file opened then
      // starts by itself; a leg that should not play is paused first.
      if (!play) await _inner.pause();
      if (gen != _gen) return;
      _leg = leg;
      await _inner.load(target.recording);
      if (gen != _gen) return;
      _loading = false;
      if (_inner.state.status == ChantStatus.failed) return;
    }
    if (at > Duration.zero || loaded) {
      await _inner.seek(at);
      if (gen != _gen) return;
    }
    if (_playOnLoad) {
      await _inner.play();
    } else {
      await _inner.pause();
    }
  }

  /// Loads the awaited leg, seeks to its point and plays when [armed]; does
  /// nothing when no leg is awaited or its file is still unavailable.
  Future<void> arrived() async {
    final p = _programme;
    final waiting = _awaiting;
    if (p == null || waiting == null || _disposed) return;
    if (!_isAvailable(p.legs[waiting.leg].recording)) return;
    await playLeg(waiting.leg, at: waiting.at, play: _armed);
  }

  Future<void> play() async {
    final p = _programme;
    if (p == null || _disposed) return;
    final waiting = _awaiting;
    if (waiting != null) {
      _armed = true;
      onAwait?.call(waiting.leg);
      return;
    }
    final k = _leg;
    if (k == null) return playLeg(0);
    if (_loading) {
      _playOnLoad = true;
      return;
    }
    if (_state.status == ChantStatus.failed) return playLeg(k);
    // Play after the end starts the whole programme again.
    if (!p.single && _state.status == ChantStatus.completed) return playLeg(0);
    await _inner.play();
  }

  Future<void> pause() async {
    if (_disposed) return;
    if (_awaiting != null) {
      _armed = false;
      return;
    }
    _playOnLoad = false;
    await _inner.pause();
  }

  /// A leg of this player's is loaded and none is awaited.
  bool get _ready => _leg != null && _awaiting == null;

  /// From the start, playing.
  Future<void> restart() async {
    final p = _programme;
    if (p == null || _disposed) return;
    if (p.single && _ready) return _inner.restart();
    await playLeg(0);
  }

  /// [to] is on the programme's timeline; another leg is loaded when needed.
  Future<void> seek(Duration to) async {
    final p = _programme;
    if (p == null || _disposed) return;
    if (p.single && _ready) return _inner.seek(to);
    final k = p.legAt(to);
    final at = to - p.legs[k].start;
    if (_awaiting == null && _leg == k) return _inner.seek(at);
    // While a leg loads, Play has been pressed when it is to play on load.
    final playing = _awaiting != null
        ? _armed
        : _loading
        ? _playOnLoad
        : _state.status == ChantStatus.playing;
    await playLeg(k, at: at, play: playing);
  }

  /// Kept across loads by the inner player.
  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    await _inner.setSpeed(speed);
  }

  /// The inner player belongs to its provider and is not disposed here.
  Future<void> dispose() async {
    _disposed = true;
    _gen++;
    await _subscription.cancel();
    await _controller.close();
  }
}
