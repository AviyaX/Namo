import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

void main() {
  // A flow's legs follow one another at each recording's duration_ms, so a
  // recording listed shorter than its timed words would hand the highlight
  // to the next section while it still sounds. The build tools measure the
  // length from the file; this holds them to it.
  testWidgets('every timed recording lasts at least to its last block\'s end',
      (t) async {
    final recordings = ContentAudioCatalogue(await realLibrary(t)).recordings;
    final timed = [for (final r in recordings) if (r.timed) r];
    expect(timed, hasLength(greaterThanOrEqualTo(40)));
    for (final r in timed) {
      final last = r.blockTimes.lastWhere((b) => b != null)!;
      expect(r.duration, greaterThanOrEqualTo(last.end), reason: r.readingId);
    }
  });
}
