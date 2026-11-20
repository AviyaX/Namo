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

    testWidgets('side safe-area insets push the column in', (t) async {
      await pumpThemed(
        t,
        SizedBox(width: 390, height: 844, child: _page()),
        padding: const EdgeInsets.only(left: 47),
      );
      expect(t.getTopLeft(find.byKey(_column)).dx, 67);
      await pumpThemed(
        t,
        SizedBox(width: 390, height: 844, child: _page()),
        padding: const EdgeInsets.only(right: 47),
      );
      expect(t.getTopLeft(find.byKey(_column)).dx, 20);
      expect(t.getSize(find.byKey(_column)).width, 350 - 47);
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

    group('backdrop', () {
      const backdrop = ValueKey('backdrop');
      Widget page({double maxWidth = 680, ScrollController? controller}) =>
          NamoPage(
            columnKey: _column,
            maxWidth: maxWidth,
            controller: controller,
            backdrop: Container(key: backdrop, height: 150, color: Colors.red),
            children: [
              const SizedBox(height: 2000, child: Text('content')),
            ],
          );

      testWidgets('on a phone: from the top of the screen, edge to edge, '
          'behind the content', (t) async {
        await pumpThemed(
          t,
          SizedBox(width: 390, height: 844, child: page()),
          padding: const EdgeInsets.only(top: 40),
        );
        expect(t.getRect(find.byKey(backdrop)), const Rect.fromLTWH(0, 0, 390, 150));
        // The column still starts below the inset.
        expect(t.getTopLeft(find.byKey(_column)).dy, 64);
        // Painted first: the content is on top.
        final stack = t.widget<Stack>(
          find.ancestor(of: find.byKey(backdrop), matching: find.byType(Stack)).first,
        );
        expect(
          find.descendant(
            of: find.byWidget(stack.children.first),
            matching: find.byKey(backdrop),
          ),
          findsOneWidget,
        );
      });

      testWidgets("on a wide screen: the column's width", (t) async {
        await pumpThemed(
          t,
          SizedBox(width: 1280, height: 800, child: page(maxWidth: 1040)),
          size: const Size(1280, 800),
        );
        final column = t.getRect(find.byKey(_column));
        final box = t.getRect(find.byKey(backdrop));
        expect(box.left, column.left);
        expect(box.width, column.width);
        expect(box.top, 0);
      });

      testWidgets('scrolls away with the content', (t) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await pumpThemed(
          t,
          SizedBox(width: 390, height: 844, child: page(controller: controller)),
        );
        controller.jumpTo(120);
        await t.pump();
        expect(t.getRect(find.byKey(backdrop)).top, -120);
      });
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
