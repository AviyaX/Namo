import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/progress_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_support.dart';

Future<void> _pump(WidgetTester t, double v, {double? height}) => pumpThemed(
      t,
      SizedBox(
        width: 200,
        child: height == null
            ? ProgressLine(value: v)
            : ProgressLine(value: v, height: height),
      ),
    );

double _fillWidth(WidgetTester t) =>
    t.getSize(find.descendant(
      of: find.byType(ProgressLine),
      matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == NamoPalette.dark.sage),
    )).width;

void main() {
  group('ProgressLine', () {
    testWidgets('announces the label and the percentage', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, 0.42);
      final data = t.getSemantics(find.byType(ProgressLine)).getSemanticsData();
      expect(data.label, 'Reading progress');
      expect(data.value, '42%');
      handle.dispose();
    });

    testWidgets('takes a custom label', (t) async {
      final handle = t.ensureSemantics();
      await pumpThemed(
        t,
        const SizedBox(width: 200, child: ProgressLine(value: 0.5, semanticsLabel: 'Chapter')),
      );
      expect(t.getSemantics(find.byType(ProgressLine)).label, 'Chapter');
      handle.dispose();
    });

    testWidgets('draws sage on a border track, 2 px high by default', (t) async {
      await _pump(t, 0.5);
      expect(t.getSize(find.byType(ProgressLine)).height, 2);
      expect(_fillWidth(t), 100);
      expect(
        find.descendant(
          of: find.byType(ProgressLine),
          matching: find.byWidgetPredicate(
              (w) => w is Container && w.color == NamoPalette.dark.border),
        ),
        findsOneWidget,
      );
    });

    testWidgets('values are clamped to 0..1', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, -1);
      expect(t.getSemantics(find.byType(ProgressLine)).getSemanticsData().value, '0%');
      expect(_fillWidth(t), 0);
      await _pump(t, 2);
      expect(t.getSemantics(find.byType(ProgressLine)).getSemanticsData().value, '100%');
      expect(_fillWidth(t), 200);
      handle.dispose();
    });

    testWidgets('height can be changed', (t) async {
      await _pump(t, 0.5, height: 4);
      expect(t.getSize(find.byType(ProgressLine)).height, 4);
    });

    testWidgets('rounded: the track and the fill have round ends, the fill '
        'still the fraction of the width', (t) async {
      await pumpThemed(
        t,
        const SizedBox(
          width: 200,
          child: ProgressLine(value: 0.25, height: 4, rounded: true),
        ),
      );
      expect(t.getSize(find.byType(ProgressLine)).height, 4);
      BoxDecoration decorationOf(Color c) => t
          .widgetList<Widget>(
            find.descendant(of: find.byType(ProgressLine), matching: find.byWidgetPredicate(
              (w) =>
                  (w is Container && (w.decoration as BoxDecoration?)?.color == c) ||
                  (w is DecoratedBox && (w.decoration as BoxDecoration).color == c),
            )),
          )
          .map((w) => w is Container ? w.decoration! : (w as DecoratedBox).decoration)
          .whereType<BoxDecoration>()
          .first;
      expect(decorationOf(NamoPalette.dark.border).borderRadius, BorderRadius.circular(2));
      expect(decorationOf(NamoPalette.dark.sage).borderRadius, BorderRadius.circular(2));
      final fill = find.descendant(
        of: find.byType(ProgressLine),
        matching: find.byWidgetPredicate(
          (w) => w is DecoratedBox && (w.decoration as BoxDecoration).color == NamoPalette.dark.sage,
        ),
      );
      expect(t.getSize(fill).width, 50);
      expect(const ProgressLine(value: 0).rounded, isFalse);
    });
  });
}
