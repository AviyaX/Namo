import 'package:buddhist_gatha/reader/screen_awake.dart';

/// A [ScreenAwake] that does nothing but note each call.
class FakeScreenAwake implements ScreenAwake {
  /// 'hold' and 'release', in the order they were called.
  final calls = <String>[];

  /// Whether the last call asked for the screen to stay on.
  bool get held => calls.isNotEmpty && calls.last == 'hold';

  @override
  Future<void> hold() async => calls.add('hold');

  @override
  Future<void> release() async => calls.add('release');
}
