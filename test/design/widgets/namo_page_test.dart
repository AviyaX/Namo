import 'package:buddhist_gatha/design/widgets/namo_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_support.dart';

const _column = ValueKey('column');

Widget _page({double? maxWidth, ScrollController? controller, List<Widget>? children}) =>
    maxWidth == null
        ? NamoPage(
            columnKey: _column,
            controller: controller,
            children: children ?? const [SizedBox(height: 10)],
          )
        : NamoPage(
            columnKey: _column,
            maxWidth: maxWidth,
            controller: controller,
            children: children ?? const [SizedBox(height: 10)],
          );

void main() {
  group('NamoPage', () {
    testWidgets('at 390 wide the column is 350 wide', (t) async {
      await pumpThemed(t, SizedBox(width: 390, height: 844, child: _page()));
      expect(t.getSize(find.byKey(_column)).width, 350);
      expect(t.getTopLeft(find.byKey(_column)).dx, 20);
    });

    testWidgets('at 1280 wide the column is maxWidth', (t) async {
      await pumpThemed(t, SizedBox(width: 1280, height: 800, child: _page()), size: const Size(1280, 800));
      expect(t.getSize(find.byKey(_column)).width, 680);
      expect(t.getCenter(find.byKey(_column)).dx, 640);
      await pumpThemed(
        t,
        SizedBox(width: 1280, height: 800, child: _page(maxWidth: 1040)),
        size: const Size(1280, 800),
      );
      expect(t.getSize(find.byKey(_column)).width, 1040);
    });

    testWidgets('top padding is the safe area plus 24', (t) async {
      await pumpThemed(
        t,
        SizedBox(width: 390, height: 844, child: _page()),
        padding: const EdgeInsets.only(top: 40),
      );
      expect(t.getTopLeft(find.byKey(_column)).dy, 64);
    });

    testWidgets('the last child scrolls clear of the bottom inset by 100', (t) async {
      const last = ValueKey('last');
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpThemed(
        t,
        SizedBox(
          width: 390,
          height: 844,
          child: _page(controller: controller, children: [
            const SizedBox(height: 2000),
            const SizedBox(key: last, height: 20),
          ]),
        ),
        padding: const EdgeInsets.only(bottom: 100),
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await t.pump();
      expect(t.getBottomLeft(find.byKey(last)).dy, lessThanOrEqualTo(844 - 100));
    });

    testWidgets('has no app bar and uses the controller', (t) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpThemed(t, SizedBox(width: 390, height: 844, child: _page(controller: controller)));
      expect(find.byType(AppBar), findsNothing);
      expect(controller.hasClients, isTrue);
    });
  });
}
