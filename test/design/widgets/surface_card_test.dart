import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/surface_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_support.dart';

BoxDecoration _decoration(WidgetTester t) {
  final box = t.widget<DecoratedBox>(find
      .descendant(of: find.byType(SurfaceCard), matching: find.byType(DecoratedBox))
      .first);
  return box.decoration as BoxDecoration;
}

void main() {
  group('SurfaceCard', () {
    for (final b in Brightness.values) {
      testWidgets('surface fill, border edge, no shadow ($b)', (t) async {
        final p = paletteOf(b);
        await pumpThemed(t, const SurfaceCard(child: Text('Body')), brightness: b);
        final d = _decoration(t);
        expect(d.color, isNull);
        final g = d.gradient as LinearGradient;
        expect(g.colors, [p.surface, p.backgroundAlt]);
        expect(g.begin, Alignment.topCenter);
        expect(g.end, Alignment.bottomCenter);
        expect(d.border!.top.color, p.border);
        expect(d.border!.top.width, 1);
        expect(d.boxShadow, isNull);
        expect(d.borderRadius, BorderRadius.circular(NamoRadius.card));
      });
    }

    testWidgets('framed uses the frame colour for the border', (t) async {
      await pumpThemed(t, const SurfaceCard(framed: true, child: Text('Body')));
      expect(_decoration(t).border!.top.color, NamoPalette.dark.frame);
    });

    testWidgets('a leading line is 2 px wide in the given colour', (t) async {
      await pumpThemed(
        t,
        SurfaceCard(leadingLine: NamoPalette.dark.gold, child: const Text('Body')),
      );
      final line = find.byKey(const ValueKey('surface-card-leading-line'));
      expect(t.getSize(line).width, 2);
      expect(t.widget<ColoredBox>(line).color, NamoPalette.dark.gold);
      expect(t.getTopLeft(line).dx, t.getTopLeft(find.byType(SurfaceCard)).dx);
    });

    testWidgets('onTap fires; the label is announced as a button', (t) async {
      final handle = t.ensureSemantics();
      var taps = 0;
      await pumpThemed(
        t,
        SurfaceCard(
          semanticLabel: 'Open card',
          onTap: () => taps++,
          child: const Text('Body'),
        ),
        size: const Size(390, 844),
      );
      await t.tap(find.text('Body'));
      expect(taps, 1);
      final data = t.getSemantics(find.bySemanticsLabel('Open card')).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('a tappable card keeps the width it is given', (t) async {
      await pumpThemed(
        t,
        SizedBox(
          width: 300,
          child: SurfaceCard(onTap: () {}, child: const Text('Body')),
        ),
      );
      expect(t.getSize(find.byType(SurfaceCard)).width, 300);
    });

    testWidgets('without onTap there is no button', (t) async {
      await pumpThemed(t, const SurfaceCard(child: Text('Body')));
      expect(find.byType(GestureDetector), findsNothing);
    });
  });
}
