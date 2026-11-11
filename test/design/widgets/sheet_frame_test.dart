import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/sheet_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_support.dart';

Widget _frame({String last = 'Last row', VoidCallback? onLast}) => SheetFrame(
  title: 'Sheet title',
  children: [
    for (var i = 0; i < 12; i++)
      const SizedBox(height: 48, child: Text('A row of content')),
    TextButton(onPressed: onLast, child: Text(last)),
  ],
);

Widget _single() => const SheetFrame(
  title: 'T',
  children: [SizedBox(height: 48, key: Key('row'))],
);

void main() {
  group('SheetFrame', () {
    for (final b in Brightness.values) {
      testWidgets('surface, top corners 24, float shadow, handle ($b)', (
        t,
      ) async {
        final p = paletteOf(b);
        await pumpThemed(t, _frame(), brightness: b);
        final frame = t.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(SheetFrame),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final d = frame.decoration as BoxDecoration;
        expect(d.color, p.surface);
        expect(
          d.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(24)),
        );
        expect(d.boxShadow, p.floatShadow);

        final handle = find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 32 && w.height == 4,
        );
        expect(handle, findsOneWidget);
        final hd =
            t
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: handle,
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as ShapeDecoration;
        expect(hd.color, p.border);
      });
    }

    testWidgets('shows the title as a header', (t) async {
      await pumpThemed(t, _frame());
      expect(find.text('Sheet title'), findsOneWidget);
      expect(
        t.getSemantics(find.text('Sheet title')),
        matchesSemantics(label: 'Sheet title', isHeader: true),
      );
    });

    testWidgets('is never taller than 90 % of the screen', (t) async {
      await pumpThemed(t, _frame(), size: const Size(390, 500));
      expect(t.getSize(find.byType(SheetFrame)).height, lessThanOrEqualTo(450));
    });

    testWidgets('content is at most 680 wide with 20 at the sides', (t) async {
      await pumpThemed(t, _single(), size: const Size(1000, 800));
      expect(t.getSize(find.byKey(const Key('row'))).width, 680);
      await pumpThemed(t, _single(), size: const Size(390, 800));
      expect(t.getSize(find.byKey(const Key('row'))).width, 350);
      expect(t.getTopLeft(find.byKey(const Key('row'))).dx, 20);
    });

    testWidgets('bottom padding is the safe area plus 24', (t) async {
      await pumpThemed(
        t,
        _single(),
        size: const Size(390, 800),
        padding: const EdgeInsets.only(bottom: 34),
      );
      final frame = t.getRect(find.byType(SheetFrame));
      final row = t.getRect(find.byKey(const Key('row')));
      expect(frame.bottom - row.bottom, 34 + NamoSpace.xl);
    });

    testWidgets('scrolls when taller than the screen; the last row is '
        'reachable', (t) async {
      var tapped = 0;
      await pumpThemed(
        t,
        _frame(last: 'Back to the end', onLast: () => tapped++),
        size: const Size(390, 500),
        textScale: 1.5,
      );
      await t.scrollUntilVisible(
        find.text('Back to the end'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await t.tap(find.text('Back to the end'));
      expect(tapped, 1);
      expect(t.takeException(), isNull);
    });

    testWidgets('the builder form builds rows only as they come into view, '
        'at the same width as the list form', (t) async {
      await pumpThemed(
        t,
        SheetFrame.builder(
          title: 'Sheet title',
          itemCount: 200,
          itemBuilder: (context, i) =>
              SizedBox(height: 48, key: Key('row-$i'), child: Text('row $i')),
        ),
        size: const Size(1000, 800),
      );
      expect(find.text('Sheet title'), findsOneWidget);
      expect(find.byKey(const Key('row-0')), findsOneWidget);
      expect(find.byKey(const Key('row-199')), findsNothing);
      expect(t.getSize(find.byKey(const Key('row-0'))).width, 680);
      await t.scrollUntilVisible(
        find.byKey(const Key('row-199')),
        400,
        scrollable: find.byType(Scrollable),
      );
      expect(find.byKey(const Key('row-199')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    for (final b in Brightness.values) {
      testWidgets('does not overflow at 320 wide, text 2.0 ($b)', (t) async {
        await pumpThemed(
          t,
          _frame(),
          brightness: b,
          size: const Size(320, 568),
          textScale: 2.0,
        );
        expect(t.takeException(), isNull);
      });
    }
  });
}
