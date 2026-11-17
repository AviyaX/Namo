import 'dart:convert';

import 'package:buddhist_gatha/flows/flows.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

const _pirithSection = 'pirith-08-mahamangala~p';

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('a flow row says how many sections have recordings', (t) async {
    final lib = await realLibrary(t);
    final buddha = lib.reading(realReadingId)!;
    final stored = await realFlowsStore(t);
    final state = FlowsState.fromJson(jsonDecode(stored[flowsKey]!));
    final withBuddhaOnly = FlowsState(
      flows: [
        ...state.flows,
        Flow(
          id: 'flow-4',
          name: 'Plain',
          sections: [
            for (final s in buddha.sections.take(3))
              FlowRef(readingId: buddha.id, sectionId: s.id),
          ],
        ),
      ],
      nextNumber: 5,
    );
    await openReal(
      t,
      Routes.library,
      size: const Size(390, 1400),
      storeExtras: {flowsKey: jsonEncode(withBuddhaOnly.toJson())},
    );
    for (final (id, caption) in [
      ('flow-1', '4 sections · 1 with a recording'),
      ('flow-2', '1 section · 1 with a recording'),
      ('flow-4', '3 sections'),
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('flow-open-$id')),
          matching: find.text(caption),
        ),
        findsOneWidget,
        reason: id,
      );
    }
  });

  testWidgets('the editor shows the mark on recorded sections', (t) async {
    await openReal(
      t,
      Routes.flowEditor('flow-1'),
      size: const Size(390, 1400),
      storeExtras: await realFlowsStore(t),
    );
    expect(find.text('4 sections · 1 with a recording'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('flow-recorded-$_pirithSection')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Has a recording'), findsNothing);
    final buddha = (await realLibrary(t)).reading(realReadingId)!;
    expect(
      find.byKey(
        ValueKey('flow-recorded-$realReadingId~${buddha.sections.first.id}'),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('flow-row-$_pirithSection')), findsOneWidget);
  });

  testWidgets('the Add sections sheet marks recorded readings', (t) async {
    await openReal(
      t,
      Routes.flowEditor('flow-3'),
      size: const Size(390, 844),
      storeExtras: await realFlowsStore(t),
    );
    await t.tap(find.byKey(const ValueKey('flow-add')));
    await t.pumpAndSettle();
    final row = find.byKey(const ValueKey('add-tick-$_pirithSection'));
    final list = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    ).first;
    await t.scrollUntilVisible(row, 300, scrollable: list);
    expect(
      find.descendant(
        of: row,
        matching: find.byKey(const ValueKey('flow-recorded-$_pirithSection')),
      ),
      findsOneWidget,
    );
    final buddha = (await realLibrary(t)).reading(realReadingId)!;
    expect(
      find.byKey(
        ValueKey('flow-recorded-$realReadingId~${buddha.sections.first.id}'),
      ),
      findsNothing,
    );
  });
}
