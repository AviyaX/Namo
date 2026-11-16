import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quality_support.dart';

void main() {
  // Only the names in the bundle's manifest are read here, never the bytes of
  // a recording.
  Future<List<String>> bundled() async =>
      (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();

  testWidgets('nothing under assets/audio/ is bundled', (t) async {
    final names = (await t.runAsync(bundled))!;
    expect(names.where((a) => a.startsWith('assets/audio/')), isEmpty);
  });

  testWidgets('the development tone is still bundled', (t) async {
    final names = (await t.runAsync(bundled))!;
    expect(names, contains('assets/audio_dev/placeholder_tone_not_a_chant.wav'));
  });

  testWidgets('every pirith recording names a hosted file with its size and checksum', (t) async {
    final lib = await realLibrary(t);
    final readings = lib.category(pirithCategoryId)!.readings;
    expect(readings, hasLength(39));
    final hex = RegExp(r'^[0-9a-f]{64}$');
    for (final r in readings) {
      final a = r.audio;
      expect(a, isNotNull, reason: r.id);
      expect(a!.path, startsWith('audio/pirith/'), reason: r.id);
      expect(a.path, endsWith('.m4a'), reason: r.id);
      expect(a.bytes, greaterThan(0), reason: r.id);
      expect(hex.hasMatch(a.sha256), isTrue, reason: r.id);
    }
    expect({for (final r in readings) r.audio!.path}, hasLength(39));
  });
}
