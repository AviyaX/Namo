import 'dart:ui' as ui;

import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/typography.dart';
import 'package:buddhist_gatha/design/widgets/list_row.dart';
import 'package:buddhist_gatha/design/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_support.dart';

void main() {
  group('ListRow', () {
    testWidgets('all old parameters render and the row taps', (t) async {
      var taps = 0;
      await pumpThemed(
        t,
        SizedBox(
          width: 390,
          child: ListRow(
            title: 'Title',
            subtitle: 'Sub',
            number: 7,
            trailing: const Icon(Icons.add, key: ValueKey('tr')),
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Sub'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.byKey(const ValueKey('tr')), findsOneWidget);
      await t.tap(find.text('Title'));
      expect(taps, 1);
    });

    testWidgets('detail shows under the title and joins the spoken label', (t) async {
      final handle = t.ensureSemantics();
      await pumpThemed(
        t,
        SizedBox(
          width: 390,
          child: ListRow(
            title: 'Title',
            number: 2,
            detail: const Text('Line', key: ValueKey('detail')),
            detailLabel: 'Line',
            onTap: () {},
          ),
        ),
      );
      expect(t.getTopLeft(find.byKey(const ValueKey('detail'))).dy,
          greaterThan(t.getTopLeft(find.text('Title')).dy));
      expect(find.bySemanticsLabel('2, Title, Line'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('subtitleFamily romanPali draws the subtitle in the serif', (t) async {
      await pumpThemed(
        t,
        SizedBox(
          width: 390,
          child: ListRow(
            title: 'Title',
            subtitle: 'Sub',
            subtitleFamily: NamoFonts.romanPali,
            onTap: () {},
          ),
        ),
      );
      expect(t.widget<Text>(find.text('Sub')).style!.fontFamily,
          contains('NotoSerif'));
    });

    testWidgets('leading and caption render', (t) async {
      await pumpThemed(
        t,
        SizedBox(
          width: 390,
          child: ListRow(
            title: 'Title',
            caption: 'Cap',
            leading: const Icon(Icons.add, key: ValueKey('lead')),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Cap'), findsOneWidget);
      expect(t.getCenter(find.byKey(const ValueKey('lead'))).dx,
          lessThan(t.getCenter(find.text('Title')).dx));
      expect(t.widget<Text>(find.text('Cap')).style!.color, NamoPalette.dark.textSecondary);
    });

    testWidgets('the whole row is one button, labelled number, title, subtitle', (t) async {
      final handle = t.ensureSemantics();
      await pumpThemed(
        t,
        SizedBox(
          width: 390,
          child: ListRow(title: 'Title', subtitle: 'Sub', number: 3, onTap: () {}),
        ),
      );
      final node = t.getSemantics(find.bySemanticsLabel('3, Title, Sub'));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(find.byType(Pressable), findsOneWidget);
      handle.dispose();
    });

    testWidgets('an expandable row announces whether it is open', (t) async {
      final handle = t.ensureSemantics();
      await pumpThemed(
        t,
        SizedBox(
          width: 390,
          child: ListRow(title: 'Title', expanded: true, onTap: () {}),
        ),
      );
      final data = t.getSemantics(find.bySemanticsLabel('Title')).getSemanticsData();
      expect(data.flagsCollection.isExpanded.name, 'isTrue');
      handle.dispose();
    });

    testWidgets('a row that can be ticked announces whether it is', (t) async {
      final handle = t.ensureSemantics();
      await pumpThemed(
        t,
        SizedBox(
          width: 390,
          child: Column(
            children: [
              ListRow(title: 'On', checked: true, onTap: () {}),
              ListRow(title: 'Off', checked: false, onTap: () {}),
              ListRow(title: 'Plain', onTap: () {}),
            ],
          ),
        ),
      );
      ui.CheckedState checked(String label) => t
          .getSemantics(find.bySemanticsLabel(label))
          .getSemanticsData()
          .flagsCollection
          .isChecked;
      expect(checked('On'), ui.CheckedState.isTrue);
      expect(checked('Off'), ui.CheckedState.isFalse);
      expect(checked('Plain'), ui.CheckedState.none);
      handle.dispose();
    });

    testWidgets('number is gold, title is cardTitle, no divider of its own', (t) async {
      await pumpThemed(
        t,
        SizedBox(width: 390, child: ListRow(title: 'Title', number: 1, onTap: () {})),
      );
      final p = NamoPalette.dark;
      expect(t.widget<Text>(find.text('1')).style!.color, p.gold);
      expect(t.widget<Text>(find.text('Title')).style!.fontFamily, NamoFonts.serif);
      expect(t.widget<Text>(find.text('Title')).style!.color, p.text);
      expect(
        find.descendant(
          of: find.byType(ListRow),
          matching: find.byWidgetPredicate((w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).border != null &&
              (w.decoration as BoxDecoration).color == null),
        ),
        findsNothing,
      );
      expect(t.getSize(find.byType(ListRow)).height, greaterThanOrEqualTo(48));
    });

    testWidgets('the Sinhala family uses the Sinhala title style at 18', (t) async {
      await pumpThemed(
        t,
        SizedBox(
          width: 390,
          child: ListRow(title: 'Title', titleFamily: NamoFonts.sinhala, onTap: () {}),
        ),
      );
      final style = t.widget<Text>(find.text('Title')).style!;
      expect(style.fontFamily, NamoFonts.sinhala);
      expect(style.fontSize, 18);
    });
  });
}
