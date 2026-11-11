import 'package:flutter/foundation.dart';

import '../audio/chant_player.dart';
import '../audio/chant_timing.dart';
import '../content/model.dart';

/// Where the chanting is on the page, and whether the page follows it.
///
/// The place is a block and a phrase, worked out from the player's position.
/// It is shown only after the chanting has been started, while it plays or is
/// paused; it clears when the recording ends. Following is the page moving
/// with the place: a hand on the text pauses it, and only [resume] (the
/// person's own word) starts it again.
///
/// This notifies when [started] or [following] changes; the place has its own
/// listenable so a place change does not wake what only reads the other two.
class ChantFollow extends ChangeNotifier {
  ChantFollow({
    required this.times,
    required this.paliLengths,
    this.lineTimes = const [],
  });

  final List<BlockTime?> times;
  final List<List<int>> paliLengths;

  /// Start time of every line, one list per block; empty where a recording
  /// has none.
  final List<List<Duration?>> lineTimes;

  /// When line [phrase] of [block] starts; the block's start when that line
  /// has no time or does not exist; null when the block is untimed too.
  Duration? lineStart(int block, int phrase) {
    if (block >= 0 &&
        block < lineTimes.length &&
        phrase >= 0 &&
        phrase < lineTimes[block].length) {
      final at = lineTimes[block][phrase];
      if (at != null) return at;
    }
    return blockStart(times, block);
  }

  final _place = ValueNotifier<ChantPlace?>(null);
  bool _started = false;
  bool _following = true;

  ValueListenable<ChantPlace?> get place => _place;

  /// True from the first playing state until [reset].
  bool get started => _started;

  /// Whether the page moves with the place. Starts true.
  bool get following => _following;

  /// Takes the player's latest state.
  void onState(ChantState s) {
    var changed = false;
    if (s.status == ChantStatus.playing && !_started) {
      _started = true;
      changed = true;
    }
    final shown =
        _started &&
        (s.status == ChantStatus.playing || s.status == ChantStatus.paused);
    _place.value = shown
        ? placeAt(s.position, times, paliLengths, lineTimes: lineTimes)
        : null;
    if (changed) notifyListeners();
  }

  /// A hand on the text: following stops. Nothing changes before the
  /// chanting has started.
  void pausedByHand() {
    if (!_started || !_following) return;
    _following = false;
    notifyListeners();
  }

  /// Following starts again (only ever by the person's own request).
  void resume() {
    if (_following) return;
    _following = true;
    notifyListeners();
  }

  /// Leaving the pirith: nothing is started, nothing is shown.
  void reset() {
    final changed = _started || !_following;
    _started = false;
    _following = true;
    _place.value = null;
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }
}
