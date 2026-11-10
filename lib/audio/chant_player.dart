import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_catalogue.dart';

enum ChantStatus { idle, loading, ready, playing, paused, completed, failed }

class ChantState {
  const ChantState({
    this.status = ChantStatus.idle,
    this.position = Duration.zero,
    this.duration,
  });

  final ChantStatus status;
  final Duration position;

  /// Null until the length is known.
  final Duration? duration;

  @override
  bool operator ==(Object other) =>
      other is ChantState &&
      other.status == status &&
      other.position == position &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(status, position, duration);
}

/// Plays one recording at a time. "Resume" is [play] after [pause].
abstract interface class ChantPlayer {
  ChantState get state;
  Stream<ChantState> get states;

  /// Never throws: a file that cannot be opened ends in
  /// [ChantStatus.failed].
  Future<void> load(Recording r);
  Future<void> play();
  Future<void> pause();

  /// From the start, playing.
  Future<void> restart();
  Future<void> seek(Duration to);
  Future<void> dispose();
}

/// [ChantPlayer] on `just_audio`; the only file that imports it. Needs the
/// platform's audio, so it is not covered by automated tests.
class JustAudioChantPlayer implements ChantPlayer {
  JustAudioChantPlayer() {
    _subscriptions = [
      _player.playerStateStream.listen((_) => _publish()),
      _player.positionStream.listen((_) => _publish()),
      _player.durationStream.listen((_) => _publish()),
    ];
  }

  final _player = AudioPlayer();
  final _controller = StreamController<ChantState>.broadcast();
  late final List<StreamSubscription<Object?>> _subscriptions;
  bool _loading = false;
  bool _failed = false;

  /// Set at the first play of a load: from then on a stop at the very start
  /// is "paused", not the untouched "ready".
  bool _played = false;

  /// Counts loads, so a load that was overtaken can tell.
  int _loadGen = 0;
  ChantState _state = const ChantState();

  @override
  ChantState get state => _state;

  @override
  Stream<ChantState> get states => _controller.stream;

  ChantStatus _status() {
    if (_failed) return ChantStatus.failed;
    if (_loading) return ChantStatus.loading;
    final s = _player.playerState;
    return switch (s.processingState) {
      ProcessingState.idle => ChantStatus.idle,
      // Only our own load is "loading"; a seek or a moment of buffering
      // while the recording is open keeps showing playing or paused.
      ProcessingState.loading || ProcessingState.buffering =>
        _loading
            ? ChantStatus.loading
            : (s.playing ? ChantStatus.playing : ChantStatus.paused),
      ProcessingState.completed => ChantStatus.completed,
      ProcessingState.ready =>
        s.playing ? ChantStatus.playing : ChantStatus.ready,
    };
  }

  void _publish() {
    if (_controller.isClosed) return;
    var status = _status();
    // Paused is "paused"; ready is the untouched start (never played).
    if (status == ChantStatus.ready &&
        (_played || _player.position > Duration.zero)) {
      status = ChantStatus.paused;
    }
    final next = ChantState(
      status: status,
      position: _player.position,
      duration: _player.duration,
    );
    if (next == _state) return;
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> load(Recording r) async {
    final gen = ++_loadGen;
    _failed = false;
    _played = false;
    _loading = true;
    _publish();
    try {
      await _player.setAsset(r.asset);
    } catch (_) {
      // An overtaken load is interrupted by the newer one; that is not a
      // failure of the newer one.
      if (gen == _loadGen) _failed = true;
    }
    if (gen != _loadGen) return;
    _loading = false;
    _publish();
  }

  @override
  Future<void> play() async {
    if (_failed) return;
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    _played = true;
    // Completes when playback ends, so it is not awaited.
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> restart() async {
    if (_failed) return;
    await _player.seek(Duration.zero);
    _played = true;
    unawaited(_player.play());
  }

  @override
  Future<void> seek(Duration to) async {
    // just_audio keeps `playing` true after the end, so a seek would start
    // the sound again by itself; stay paused, as the fake does.
    if (_player.processingState == ProcessingState.completed) {
      await _player.pause();
    }
    await _player.seek(to);
  }

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _controller.close();
    await _player.dispose();
  }
}

/// One player for the reader that is open; disposed when it is left.
final chantPlayerProvider = Provider.autoDispose<ChantPlayer>((ref) {
  final player = JustAudioChantPlayer();
  ref.onDispose(player.dispose);
  return player;
});
