import 'package:buddhist_gatha/design/marks.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widgets/widget_support.dart';

/// The painters of the [CustomPaint]s drawn by the marks on screen, in order.
List<CustomPainter> _painters(WidgetTester t, Type of) => [
      for (final e in find
          .descendant(of: find.byType(of), matching: find.byType(CustomPaint))
          .evaluate())
        if ((e.widget as CustomPaint).painter != null)
          (e.widget as CustomPaint).painter!,
    ];

void main() {
  group('NamoMarkIcon', () {
    for (final mark in NamoMark.values) {
      for (final size in [16.0, 28.0, 64.0]) {
        testWidgets('${mark.name} builds and paints at $size', (t) async {
          await pumpThemed(t, NamoMarkIcon(mark, size: size));
          expect(t.takeException(), isNull);
          expect(t.getSize(find.byType(NamoMarkIcon)), Size(size, size));
          expect(_painters(t, NamoMarkIcon), hasLength(1));
        });
      }
    }

    testWidgets('defaults to 28 px in the palette gold', (t) async {
      for (final b in Brightness.values) {
        await pumpThemed(t, const NamoMarkIcon(NamoMark.lotus), brightness: b);
        await t.pumpAndSettle(); // the theme eases from the previous one
        expect(t.getSize(find.byType(NamoMarkIcon)), const Size(28, 28));
        // Same mark, same size, same stroke, palette gold: nothing to repaint.
        final painter = _painters(t, NamoMarkIcon).single;
        await pumpThemed(
          t,
          NamoMarkIcon(NamoMark.lotus, color: paletteOf(b).gold),
          brightness: b,
        );
        expect(painter.shouldRepaint(_painters(t, NamoMarkIcon).single), isFalse);
      }
    });

    testWidgets('shouldRepaint is false for equal inputs, true otherwise',
        (t) async {
      await pumpThemed(
        t,
        const Row(mainAxisSize: MainAxisSize.min, children: [
          NamoMarkIcon(NamoMark.wheel),
          NamoMarkIcon(NamoMark.wheel),
          NamoMarkIcon(NamoMark.palms),
          NamoMarkIcon(NamoMark.wheel, strokeWidth: 2),
          NamoMarkIcon(NamoMark.wheel, color: NamoPalette.onPicture),
        ]),
      );
      final p = _painters(t, NamoMarkIcon);
      expect(p, hasLength(5));
      expect(p[0].shouldRepaint(p[1]), isFalse);
      expect(p[0].shouldRepaint(p[2]), isTrue, reason: 'different mark');
      expect(p[0].shouldRepaint(p[3]), isTrue, reason: 'different stroke');
      expect(p[0].shouldRepaint(p[4]), isTrue, reason: 'different colour');
    });

    testWidgets('with a semanticLabel the label is announced', (t) async {
      final handle = t.ensureSemantics();
      await pumpThemed(
        t,
        const NamoMarkIcon(NamoMark.palms, semanticLabel: 'Namaskara'),
      );
      expect(find.bySemanticsLabel('Namaskara'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('without a semanticLabel nothing is in the semantics tree',
        (t) async {
      final handle = t.ensureSemantics();
      await pumpThemed(
        t,
        const Row(mainAxisSize: MainAxisSize.min, children: [
          NamoMarkIcon(NamoMark.lotus),
          NamoMarkIcon(NamoMark.seated),
        ]),
      );
      for (final e in find.byType(NamoMarkIcon).evaluate()) {
        final node = t.getSemantics(find.byWidget(e.widget));
        expect(node.label, isEmpty);
      }
      expect(
        find.descendant(
          of: find.byType(NamoMarkIcon).first,
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('LeafWatermark', () {
    testWidgets('fills its box and paints a leaf', (t) async {
      await pumpThemed(
        t,
        const SizedBox(width: 120, height: 160, child: LeafWatermark()),
      );
      expect(t.takeException(), isNull);
      expect(t.getSize(find.byType(LeafWatermark)), const Size(120, 160));
      expect(_painters(t, LeafWatermark), hasLength(1));
    });

    testWidgets('shouldRepaint is false for equal inputs', (t) async {
      await pumpThemed(
        t,
        const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 60, height: 80, child: LeafWatermark()),
          SizedBox(width: 60, height: 80, child: LeafWatermark()),
          SizedBox(width: 60, height: 80, child: LeafWatermark(opacity: 0.2)),
        ]),
      );
      final p = _painters(t, LeafWatermark);
      expect(p[0].shouldRepaint(p[1]), isFalse);
      expect(p[0].shouldRepaint(p[2]), isTrue);
    });

    testWidgets('is always excluded from semantics', (t) async {
      final handle = t.ensureSemantics();
      await pumpThemed(
        t,
        const SizedBox(width: 120, height: 160, child: LeafWatermark()),
      );
      expect(
        find.descendant(
          of: find.byType(LeafWatermark),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(t.getSemantics(find.byType(LeafWatermark)).label, isEmpty);
      handle.dispose();
    });
  });
}
