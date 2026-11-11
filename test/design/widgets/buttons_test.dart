import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'widget_support.dart';

void main() {
  group('NamoIconButton', () {
    testWidgets('tapping its tooltip target calls onPressed', (t) async {
      var taps = 0;
      await pumpThemed(
        t,
        NamoIconButton(icon: Symbols.arrow_back_rounded, tooltip: 'Back', onPressed: () => taps++),
      );
      await t.tap(find.byTooltip('Back'));
      expect(taps, 1);
      expect(t.getSize(find.byTooltip('Back')), const Size(48, 48));
    });

    testWidgets('outline by default, filled when asked, weight 300', (t) async {
      await pumpThemed(
        t,
        const NamoIconButton(icon: Symbols.bookmark_rounded, tooltip: 'Save', onPressed: null),
      );
      var icon = t.widget<Icon>(find.byType(Icon));
      expect(icon.fill, 0);
      expect(icon.weight, 300);
      expect(icon.size, NamoSizes.icon);
      await pumpThemed(
        t,
        NamoIconButton(icon: Symbols.bookmark_rounded, tooltip: 'Save', filled: true, onPressed: () {}),
      );
      icon = t.widget<Icon>(find.byType(Icon));
      expect(icon.fill, 1);
      expect(icon.color, NamoPalette.dark.text);
    });

    testWidgets('disabled uses textMuted and does not fire', (t) async {
      await pumpThemed(
        t,
        const NamoIconButton(icon: Symbols.bookmark_rounded, tooltip: 'Save', onPressed: null),
      );
      expect(t.widget<Icon>(find.byType(Icon)).color, NamoPalette.dark.textMuted);
      await t.tap(find.byTooltip('Save'));
    });

    testWidgets('an explicit colour wins', (t) async {
      await pumpThemed(
        t,
        NamoIconButton(
          icon: Symbols.bookmark_rounded,
          tooltip: 'Save',
          color: NamoPalette.dark.gold,
          onPressed: () {},
        ),
      );
      expect(t.widget<Icon>(find.byType(Icon)).color, NamoPalette.dark.gold);
    });
  });

  group('text buttons', () {
    for (final b in Brightness.values) {
      final p = paletteOf(b);
      testWidgets('PrimaryButton is 48 high, sage with onSage label ($b)', (t) async {
        var taps = 0;
        await pumpThemed(
          t,
          PrimaryButton(label: 'Go', onPressed: () => taps++),
          brightness: b,
        );
        expect(t.getSize(find.byType(PrimaryButton)).height, 48);
        final fill = t.widget<DecoratedBox>(find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.byWidgetPredicate(
              (w) => w is DecoratedBox && (w.decoration as BoxDecoration).color == p.sage),
        ));
        expect((fill.decoration as BoxDecoration).borderRadius, BorderRadius.circular(12));
        expect(t.widget<Text>(find.text('Go')).style!.color, p.onSage);
        await t.tap(find.byType(PrimaryButton));
        expect(taps, 1);
      });
    }

    testWidgets('QuietButton: no fill, 1 px textMuted outline, text label', (t) async {
      final p = NamoPalette.dark;
      await pumpThemed(t, QuietButton(label: 'Later', onPressed: () {}));
      final box = t.widget<Container>(find
          .descendant(of: find.byType(QuietButton), matching: find.byType(Container))
          .first);
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, isNull);
      expect(deco.border!.top.color, p.textMuted);
      expect(deco.border!.top.width, 1);
      expect(t.widget<Text>(find.text('Later')).style!.color, p.text);
      expect(t.getSize(find.byType(QuietButton)).height, 48);
    });

    testWidgets('TextAction: sage label, trailing icon 20, at least 48 high', (t) async {
      await pumpThemed(
        t,
        TextAction(label: 'More', icon: Symbols.arrow_forward_rounded, onPressed: () {}),
      );
      expect(t.widget<Text>(find.text('More')).style!.color, NamoPalette.dark.sage);
      expect(t.widget<Icon>(find.byType(Icon)).size, 20);
      expect(t.getSize(find.byType(TextAction)).height, greaterThanOrEqualTo(48));
      expect(t.getCenter(find.byType(Icon)).dx, greaterThan(t.getCenter(find.text('More')).dx));
    });

    testWidgets('PrimaryButton shows a leading icon', (t) async {
      await pumpThemed(
        t,
        PrimaryButton(label: 'Go', icon: Symbols.play_arrow_rounded, onPressed: () {}),
      );
      expect(t.getCenter(find.byType(Icon)).dx, lessThan(t.getCenter(find.text('Go')).dx));
    });

    testWidgets('disabled buttons do not fire and use muted labels', (t) async {
      final p = NamoPalette.dark;
      await pumpThemed(
        t,
        const Column(children: [
          PrimaryButton(label: 'A', onPressed: null),
          QuietButton(label: 'B', onPressed: null),
          TextAction(label: 'C', onPressed: null),
        ]),
      );
      for (final l in ['A', 'B', 'C']) {
        await t.tap(find.text(l));
        expect(t.widget<Text>(find.text(l)).style!.color, p.textMuted);
      }
    });

    testWidgets('QuietButton and TextAction fire', (t) async {
      var taps = 0;
      await pumpThemed(
        t,
        Column(children: [
          QuietButton(label: 'B', onPressed: () => taps++),
          TextAction(label: 'C', onPressed: () => taps++),
        ]),
      );
      await t.tap(find.text('B'));
      await t.tap(find.text('C'));
      expect(taps, 2);
    });

    testWidgets('a button is announced once, with its label', (t) async {
      final handle = t.ensureSemantics();
      await pumpThemed(t, PrimaryButton(label: 'Go', onPressed: () {}));
      expect(find.bySemanticsLabel('Go'), findsOneWidget);
      handle.dispose();
    });
  });
}
