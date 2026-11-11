import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quality_support.dart';

void main() {
  // Only the names in the bundle's manifest are read here, never the bytes of
  // a recording.
  Future<Set<String>> bundled() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest
        .listAssets()
        .where((a) => a.startsWith('assets/audio/pirith/'))
        .toSet();
  }

  testWidgets('every pirith reading names a recording in the bundle', (t) async {
    final lib = await realLibrary(t);
    final names = await bundled();
    final readings = lib.category(pirithCategoryId)!.readings;
    expect(readings, hasLength(39));
    for (final r in readings) {
      expect(r.audio, isNotNull, reason: r.id);
      expect(names, contains(r.audio!.asset), reason: r.id);
    }
  });

  testWidgets('the bundle has exactly 39 files under assets/audio/pirith/', (t) async {
    final names = await bundled();
    expect(names, hasLength(39));
    final lib = await realLibrary(t);
    final used = {
      for (final r in lib.category(pirithCategoryId)!.readings) r.audio!.asset,
    };
    expect(names, used, reason: 'no recording is unused or shared');
  });
}
