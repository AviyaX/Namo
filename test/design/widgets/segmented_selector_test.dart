import 'dart:ui' as ui;

import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/segmented_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'widget_support.dart';

const _abc = [Segment('a', 'Lorem'), Segment('b', 'Ipsum'), Segment('c', 'Dolor')];

Widget _one(String selected, {ValueChanged<String>? onPressed, bool enabled = true}) =>
    SegmentedSelector<String>(
      segments: _abc,
      selected: {selected},
      onPressed: onPressed ?? (_) {},
      enabled: enabled,
      semanticLabel: 'Group',
    );

Finder _seg(int i) => find.byKey(ValueKey('segment-$i'));
Finder get _thumb => find.byKey(const ValueKey('selector-thumb'));

void main() {
  group('SegmentedSelector one-of-many', () {
    testWidgets('tapping calls onPressed, selected or not', (t) async {
      final taps = <String>[];
      await pumpThemed(t, _one('a', onPressed: taps.add));
      await t.tap(_seg(1));
      await t.tap(_seg(0));
      expect(taps, ['b', 'a']);
    });

    testWidgets('the thumb slides to the selected segment', (t) async {
      await pumpThemed(t, _one('a'));
      expect(t.getRect(_thumb), t.getRect(_seg(0)));
      await pumpThemed(t, _one('b'));
      await t.pump(const Duration(milliseconds: 100));
      final mid = t.getRect(_thumb);
      expect(mid.left, greaterThan(t.getRect(_seg(0)).left));
      expect(mid.left, lessThan(t.getRect(_seg(1)).left));
      await t.pumpAndSettle();
      expect(t.getRect(_thumb), t.getRect(_seg(1)));
    });

    testWidgets('with animations off the thumb is at the end at once', (t) async {
      await pumpThemed(t, _one('a'), disableAnimations: true);
      await pumpThemed(t, _one('c'), disableAnimations: true);
      await t.pump();
      expect(t.getRect(_thumb), t.getRect(_seg(2)));
    });

    testWidgets('thumb uses the surface with a border edge', (t) async {
      await pumpThemed(t, _one('a'));
      final box = t.widget<DecoratedBox>(
        find.descendant(of: _thumb, matching: find.byType(DecoratedBox)),
      );
      final d = box.decoration as BoxDecoration;
      expect(d.color, NamoPalette.dark.surface);
      expect((d.border as Border).top.color, NamoPalette.dark.border);
    });
  });

  group('SegmentedSelector multi', () {
    testWidgets('selected segments show a tick, others do not', (t) async {
      await pumpThemed(
        t,
        SegmentedSelector<String>(
          segments: _abc,
          selected: const {'a', 'c'},
          onPressed: (_) {},
          multi: true,
          semanticLabel: 'Group',
        ),
      );
      Finder tick(int i) =>
          find.descendant(of: _seg(i), matching: find.byIcon(Symbols.check_rounded));
      expect(tick(0), findsOneWidget);
      expect(tick(1), findsNothing);
      expect(tick(2), findsOneWidget);
      expect(_thumb, findsNothing);
    });
  });

  group('SegmentedSelector disabled', () {
    testWidgets('taps do nothing and segments are announced disabled', (t) async {
      final h = t.ensureSemantics();
      final taps = <String>[];
      await pumpThemed(t, _one('a', onPressed: taps.add, enabled: false));
      await t.tap(_seg(1), warnIfMissed: false);
      expect(taps, isEmpty);
      final data = t.getSemantics(find.bySemanticsLabel('Ipsum')).getSemanticsData();
      expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
      h.dispose();
    });
  });

  group('SegmentedSelector layout', () {
    testWidgets('segments are 48+ high and equal in width', (t) async {
      await pumpThemed(t, _one('a'), size: const Size(360, 800));
      final widths = {for (var i = 0; i < 3; i++) t.getSize(_seg(i)).width};
      expect(widths, hasLength(1));
      for (var i = 0; i < 3; i++) {
        expect(t.getSize(_seg(i)).height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('each segment is a button with label and checked state', (t) async {
      final h = t.ensureSemantics();
      await pumpThemed(t, _one('b'));
      ui.SemanticsFlags flags(String l) =>
          t.getSemantics(find.bySemanticsLabel(l)).getSemanticsData().flagsCollection;
      expect(flags('Ipsum').isButton, isTrue);
      expect(flags('Ipsum').isChecked, ui.CheckedState.isTrue);
      expect(flags('Lorem').isChecked, ui.CheckedState.isFalse);
      expect(flags('Lorem').isInMutuallyExclusiveGroup, isTrue);
      expect(find.bySemanticsLabel('Group'), findsOneWidget);
      h.dispose();
    });

    for (final labels in const [
      ['Pali', 'Sinhala', 'English'],
      ['Dark', 'Light', 'Same as device'],
      ['Section by section', 'Verse by verse'],
    ]) {
      for (final (w, scale) in const [(360.0, 1.0), (360.0, 1.5), (320.0, 2.0)]) {
        for (final b in Brightness.values) {
          testWidgets('$labels at $w x $scale ${b.name}: no overflow, no ellipsis',
              (t) async {
            await pumpThemed(
              t,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedSelector<int>(
                  segments: [for (var i = 0; i < labels.length; i++) Segment(i, labels[i])],
                  selected: const {0},
                  onPressed: (_) {},
                  semanticLabel: 'Group',
                ),
              ),
              size: Size(w, 800),
              textScale: scale,
              brightness: b,
            );
            expect(t.takeException(), isNull);
            for (final l in labels) {
              final text = t.widget<Text>(find.text(l));
              expect(text.overflow, isNot(TextOverflow.ellipsis));
              final seg = t.getRect(find.ancestor(
                of: find.text(l),
                matching: find.byWidgetPredicate((w) =>
                    w is SizedBox &&
                    w.key is ValueKey &&
                    (w.key! as ValueKey).value.toString().startsWith('segment-')),
              ));
              final label = t.getRect(find.text(l));
              expect(label.left, greaterThanOrEqualTo(seg.left), reason: l);
              expect(label.right, lessThanOrEqualTo(seg.right), reason: l);
              expect(label.height, lessThanOrEqualTo(seg.height), reason: l);
            }
          });
        }
      }
    }

    testWidgets('three long labels stack at 320 x 2.0', (t) async {
      await pumpThemed(
        t,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedSelector<int>(
            segments: [Segment(0, 'Dark'), Segment(1, 'Light'), Segment(2, 'Same as device')],
            selected: {0},
            onPressed: _noop,
            semanticLabel: 'Group',
          ),
        ),
        size: const Size(320, 800),
        textScale: 2,
      );
      expect(t.getTopLeft(_seg(0)).dx, t.getTopLeft(_seg(1)).dx);
      expect(t.getTopLeft(_seg(1)).dx, t.getTopLeft(_seg(2)).dx);
      expect(t.getTopLeft(_seg(1)).dy, greaterThan(t.getTopLeft(_seg(0)).dy));
    });
  });
}

void _noop(int _) {}
