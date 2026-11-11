import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/floating_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_support.dart';

void main() {
  group('FloatingBar', () {
    for (final b in Brightness.values) {
      testWidgets('surface, 1 px border, radius 24, the float shadow ($b)', (t) async {
        final p = paletteOf(b);
        await pumpThemed(t, const FloatingBar(child: Text('Bar')), brightness: b);
        final d = t.widget<Container>(find.byType(Container)).decoration! as BoxDecoration;
        expect(d.color, p.surface);
        expect(d.border!.top.color, p.border);
        expect(d.border!.top.width, 1);
        expect(d.borderRadius, BorderRadius.circular(NamoRadius.lg));
        expect(d.boxShadow, p.floatShadow);
      });
    }

    testWidgets('padding can be changed', (t) async {
      await pumpThemed(
        t,
        const FloatingBar(padding: EdgeInsets.all(NamoSpace.xl), child: SizedBox(width: 10, height: 10)),
      );
      expect(t.getSize(find.byType(FloatingBar)), const Size(10 + 48 + 2, 10 + 48 + 2));
    });
  });
}
