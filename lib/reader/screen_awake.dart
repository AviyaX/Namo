import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen from dimming and locking while the reader moves or
/// plays on its own. Neither call ever throws.
abstract interface class ScreenAwake {
  Future<void> hold();
  Future<void> release();
}

/// [ScreenAwake] through the `wakelock_plus` package, which works the same
/// way on Android, iOS and the web (where it uses a script bundled with
/// the app). A failure only means the screen may dim, so it is ignored.
class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> hold() => _quietly(WakelockPlus.enable);

  @override
  Future<void> release() => _quietly(WakelockPlus.disable);

  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {
      // The screen may dim as it normally would; nothing to tell anyone.
    }
  }
}

final screenAwakeProvider = Provider<ScreenAwake>(
  (ref) => const WakelockScreenAwake(),
);
