import 'dart:convert';

import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/flows/flows.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import 'flow_test_support.dart';

const _part = ValueKey('my-flows');

Finder _open(String id) => find.byKey(ValueKey('flow-open-$id'));

double _top(WidgetTester t, Finder f) => t.getTopLeft(f).dy;

void main() {
  setUpAll(loadBundledFonts);

  final a = ref('r1', 's01'), b = ref('r1', 's02'), c = ref('r1', 's03');

  group('no flows', () {
    testWidgets('the label, the card and "New flow" show on Home, in order',
        (t) async {
      await openFlows(t, Routes.home, {}, size: const Size(390, 3000));
      expect(find.byKey(_part), findsOneWidget);
      var previous = double.negativeInfinity;
      for (final text in [
        'My flows',
        'Make your own flow',
        'Choose the sections you chant, in your order.',
        'New flow',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
        expect(_top(t, find.text(text)), greaterThan(previous), reason: text);
        previous = _top(t, find.text(text));
      }
      expect(find.byKey(const ValueKey('new-flow')), findsOneWidget);
    });
  });

  group('with flows', () {
    testWidgets('one row per flow in creation order, counting only the '
        'sections the content has; no card', (t) async {
      await openFlows(t, Routes.home, {
        'flow-1': [],
        'flow-2': [a],
        'flow-3': [a, b, ref('r1', 'gone'), c],
      });
      expect(find.text('Make your own flow'), findsNothing);
      expect(
        find.text('Choose the sections you chant, in your order.'),
        findsNothing,
      );
      expect(_top(t, _open('flow-1')), lessThan(_top(t, _open('flow-2'))));
      expect(_top(t, _open('flow-2')), lessThan(_top(t, _open('flow-3'))));
      for (final (id, count) in [
        ('flow-1', '0 sections'),
        ('flow-2', '1 section'),
        ('flow-3', '3 sections'),
      ]) {
        expect(
          find.descendant(of: _open(id), matching: find.text(count)),
          findsOneWidget,
          reason: id,
        );
        expect(
          find.descendant(
            of: _open(id),
            matching: find.text('Flow ${id.substring(5)}'),
          ),
          findsOneWidget,
        );
      }
      // "New flow" comes after the rows.
      final add = find.byKey(const ValueKey('new-flow'));
      expect(_top(t, add), greaterThan(_top(t, _open('flow-3'))));
    });

    testWidgets('a row is announced as its name and its count; a topic row '
        'as before', (t) async {
      await openFlows(t, Routes.home, {
        'flow-1': [],
        'flow-2': [a],
        'flow-3': [a, b],
      });
      final h = t.ensureSemantics();
      expect(find.bySemanticsLabel('Flow 1, 0 sections'), findsOneWidget);
      expect(find.bySemanticsLabel('Flow 2, 1 section'), findsOneWidget);
      expect(find.bySemanticsLabel('Flow 3, 2 sections'), findsOneWidget);
      h.dispose();
    });

    testWidgets('tapping a row opens the flow in the reader', (t) async {
      final container = await openFlows(t, Routes.home, {
        'flow-1': [a, b],
      });
      await t.tap(_open('flow-1'));
      await t.pumpAndSettle();
      expect(location(container), '/read/flow-1');
      expect(find.text('heading 1'), findsWidgets);
    });

    testWidgets('an empty flow opens in the reader and says it has no '
        'sections', (t) async {
      final container = await openFlows(t, Routes.home, {'flow-1': []});
      await t.tap(_open('flow-1'));
      await t.pumpAndSettle();
      expect(location(container), '/read/flow-1');
      expect(find.text('This flow has no sections yet.'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Back from a flow opened here comes back to Home',
        (t) async {
      final container = await openFlows(t, Routes.home, {
        'flow-1': [a],
      });
      await t.tap(_open('flow-1'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(location(container), Routes.home);
      expect(find.byKey(_part), findsOneWidget);
    });

    testWidgets('the edit button opens the editor', (t) async {
      final container = await openFlows(t, Routes.home, {
        'flow-1': [a],
      });
      await t.tap(find.byTooltip('Edit flow'));
      await t.pumpAndSettle();
      expect(location(container), '/flow/flow-1');
      expect(find.byKey(const ValueKey('screen-flow-editor')), findsOneWidget);
    });

    testWidgets('a flow made in the editor shows here when Back is pressed',
        (t) async {
      final container = await openFlows(t, Routes.home, {
        'flow-1': [a],
      });
      await t.tap(find.byKey(const ValueKey('flow-edit-flow-1')));
      await t.pumpAndSettle();
      container.read(flowsProvider.notifier).add('flow-1', b);
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(
        find.descendant(of: _open('flow-1'), matching: find.text('2 sections')),
        findsOneWidget,
      );
    });

    testWidgets('a row and its edit button are each at least 48 x 48',
        (t) async {
      await openFlows(t, Routes.home, {
        'flow-1': [a],
      });
      for (final key in ['flow-open-flow-1', 'flow-edit-flow-1', 'new-flow']) {
        final size = t.getSize(find.byKey(ValueKey(key)));
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
      }
    });
  });

  group('layout', () {
    /// Twelve flows over the bundled content, the fifth with a 40-character
    /// name.
    Future<String> twelveFlows(WidgetTester t) async {
      final lib = await realLibrary(t);
      final reading = lib.category(realCategoryId)!.readings.first;
      final pirith = lib.category(pirithCategoryId)!.readings.first;
      return jsonEncode(
        FlowsState(
          flows: [
            for (var i = 1; i <= 12; i++)
              Flow(
                id: 'flow-$i',
                name: i == 5 ? 'W' * 40 : 'Flow $i',
                sections: [
                  for (final s in reading.sections.take(i % 4))
                    ref(reading.id, s.id),
                  if (i.isEven) ref(pirith.id, pirith.sections.single.id),
                ],
              ),
          ],
          nextNumber: 13,
        ).toJson(),
      );
    }

    const sizes = [
      Size(320, 568),
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 800),
    ];
    for (final size in sizes) {
      for (final scale in [1.0, 2.0]) {
        for (final dark in [false, true]) {
          final name =
              '${size.width.round()}x${size.height.round()}, text ${scale}x, '
              '${dark ? 'dark' : 'light'}';
          Future<void> open(WidgetTester t, Map<String, String> extras) async {
            final Library lib = await realLibrary(t);
            await openFlows(
              t,
              Routes.home,
              {},
              library: lib,
              size: size,
              deviceTextScale: scale,
              dark: dark,
              extras: extras,
            );
          }

          testWidgets('Home with no flows does not overflow: $name',
              (t) async {
            await open(t, {});
            expect(find.text('Make your own flow'), findsOneWidget);
            await scrollThrough(t);
          });

          testWidgets('Home with 12 flows does not overflow: $name',
              (t) async {
            await open(t, {flowsKey: await twelveFlows(t)});
            expect(_open('flow-12'), findsOneWidget);
            expect(find.text('W' * 40), findsOneWidget);
            await scrollThrough(t);
            for (final key in ['flow-open-flow-5', 'flow-edit-flow-5']) {
              final box = t.getSize(find.byKey(ValueKey(key)));
              expect(box.width, greaterThanOrEqualTo(48), reason: key);
              expect(box.height, greaterThanOrEqualTo(48), reason: key);
            }
          });
        }
      }
    }
  });
}
