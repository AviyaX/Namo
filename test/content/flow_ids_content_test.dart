import 'package:buddhist_gatha/flows/flow_reading.dart';
import 'package:buddhist_gatha/flows/flows.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

void main() {
  testWidgets('bundled content ids leave room for flows', (t) async {
    final lib = await realLibrary(t);
    final readings = [for (final c in lib.categories) ...c.readings];
    expect(readings, isNotEmpty);
    for (final r in readings) {
      expect(r.id.startsWith(flowIdPrefix), isFalse, reason: r.id);
      expect(r.id, isNot(contains(flowIdSeparator)));
      final sectionIds = <String>{};
      final verseIds = <String>{};
      for (final s in r.sections) {
        expect(s.id, isNot(contains(flowIdSeparator)), reason: r.id);
        expect(sectionIds.add(s.id), isTrue, reason: '${r.id}/${s.id}');
        for (final v in s.verses) {
          expect(v.id, isNot(contains(flowIdSeparator)), reason: r.id);
          expect(verseIds.add(v.id), isTrue, reason: '${r.id}/${v.id}');
        }
      }
    }
  });
}
