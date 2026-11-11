import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import 'flow_test_support.dart';

final _editor = Routes.flowEditor('flow-1');

Finder _tick(String readingId, String sectionId) =>
    find.byKey(ValueKey('add-tick-$readingId~$sectionId'));

Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(BottomSheet), matching: f);

Future<void> _openSheet(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('flow-add')));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('is titled "Add sections" and lists the categories in library '
      'order, each with its sections', (t) async {
    await openFlows(t, _editor, {'flow-1': []});
    await _openSheet(t);
    expect(_inSheet(find.text('Add sections')), findsOneWidget);
    final first = t.getTopLeft(_inSheet(find.text('category 1'))).dy;
    final second = t.getTopLeft(_inSheet(find.text('category 2'))).dy;
    expect(first, lessThan(second));
    final rows = [
      _tick('r1', 's01'),
      _tick('r1', 's02'),
      _tick('r1', 's03'),
      _tick('r2', 's01'),
      _tick('r2', 's02'),
      _tick('r3', 'p'),
    ];
    final tops = [for (final r in rows) t.getTopLeft(r).dy];
    expect(tops, [...tops]..sort());
    expect(t.getTopLeft(rows[2]).dy, lessThan(second));
    expect(t.getTopLeft(rows[3]).dy, greaterThan(second));
  });

  testWidgets('a reading with several sections is named over them only when '
      'its category has other readings; a reading with one section is one '
      'row under its own title', (t) async {
    await openFlows(t, _editor, {'flow-1': []});
    await _openSheet(t);
    // Category 1 has one reading: no label over its sections.
    expect(_inSheet(find.text('reading 1')), findsNothing);
    // Category 2 has two: reading 2's title is over its sections.
    expect(_inSheet(find.text('reading 2')), findsOneWidget);
    expect(
      t.getTopLeft(_inSheet(find.text('reading 2'))).dy,
      lessThan(t.getTopLeft(_tick('r2', 's01')).dy),
    );
    // Reading 3 has one section: one row, titled by the reading, with its
    // Roman title, and no label of its own.
    expect(_inSheet(find.text('reading 3')), findsOneWidget);
    expect(
      find.descendant(of: _tick('r3', 'p'), matching: find.text('reading 3')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _tick('r3', 'p'), matching: find.text('roman 3')),
      findsOneWidget,
    );
    expect(_inSheet(find.text('heading 3')), findsOneWidget); // r1's s03 only
  });

  testWidgets('the sections already in the flow are not offered; a reading '
      'with nothing left is left out', (t) async {
    await openFlows(t, _editor, {
      'flow-1': [ref('r1', 's02'), ref('r3', 'p')],
    });
    await _openSheet(t);
    expect(_tick('r1', 's02'), findsNothing);
    expect(_tick('r3', 'p'), findsNothing);
    expect(_tick('r1', 's01'), findsOneWidget);
    expect(_tick('r2', 's02'), findsOneWidget);
    // Reading 3 was one row; taken, its title is gone from the sheet too.
    expect(_inSheet(find.text('reading 3')), findsNothing);
    expect(_inSheet(find.text('category 2')), findsOneWidget);
  });

  testWidgets('a category whose sections are all in the flow is left out', (
    t,
  ) async {
    await openFlows(t, _editor, {
      'flow-1': [ref('r1', 's01'), ref('r1', 's02'), ref('r1', 's03')],
    });
    await _openSheet(t);
    expect(_inSheet(find.text('category 1')), findsNothing);
    expect(_inSheet(find.text('category 2')), findsOneWidget);
    expect(_tick('r2', 's01'), findsOneWidget);
  });

  testWidgets('tapping a section adds it at the end and takes it off the '
      'list; the editor behind keeps count', (t) async {
    final c = await openFlows(t, _editor, {
      'flow-1': [ref('r1', 's02'), ref('r1', 's01')],
    });
    await _openSheet(t);
    expect(find.text('2 sections'), findsOneWidget);

    await t.tap(_tick('r2', 's01'));
    await t.pumpAndSettle();
    final made = [ref('r1', 's02'), ref('r1', 's01'), ref('r2', 's01')];
    expect(savedFlow(c, 'flow-1')!.sections, made);
    expect(heldFlow(c, 'flow-1')!.sections, made);
    expect(_tick('r2', 's01'), findsNothing);
    expect(_tick('r2', 's02'), findsOneWidget);
    expect(find.text('3 sections'), findsOneWidget);

    // Closed, the editor shows the section at the end.
    await t.tapAt(const Offset(195, 20));
    await t.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      t.getTopLeft(find.byKey(const ValueKey('flow-row-r1~s01'))).dy,
      lessThan(t.getTopLeft(find.byKey(const ValueKey('flow-row-r2~s01'))).dy),
    );
  });

  testWidgets('a section removed in the editor is offered again', (t) async {
    await openFlows(t, _editor, {
      'flow-1': [ref('r1', 's02'), ref('r1', 's01')],
    });
    await t.tap(find.byKey(const ValueKey('flow-remove-r1~s02')));
    await t.pumpAndSettle();
    await _openSheet(t);
    expect(_tick('r1', 's02'), findsOneWidget);
    expect(_tick('r1', 's01'), findsNothing);
  });

  testWidgets('with every section in the flow the sheet says so', (t) async {
    await openFlows(t, _editor, {
      'flow-1': [
        ref('r1', 's01'),
        ref('r1', 's02'),
        ref('r1', 's03'),
        ref('r2', 's01'),
        ref('r2', 's02'),
        ref('r3', 'p'),
      ],
    });
    await _openSheet(t);
    expect(
      _inSheet(find.text('Every section is already in this flow.')),
      findsOneWidget,
    );
    expect(_inSheet(find.text('category 1')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('an empty flow gets its first section from the sheet, and can '
      'then be chanted', (t) async {
    final c = await openFlows(t, _editor, {'flow-1': []});
    await _openSheet(t);
    await t.tap(_tick('r3', 'p'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(195, 20));
    await t.pumpAndSettle();
    expect(find.text('This flow has no sections yet.'), findsNothing);
    expect(find.text('1 section'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('flow-start')));
    await t.pumpAndSettle();
    expect(location(c), '/read/flow-1?from=editor');
  });

  testWidgets('with the bundled content the rows are built only as they '
      'scroll into view', (t) async {
    final lib = await realLibrary(t);
    await openFlows(t, _editor, {'flow-1': []}, library: lib);
    await _openSheet(t);
    final last = lib.categories.last.readings.last;
    final lastRow = _tick(last.id, last.sections.last.id);
    final count = lib.categories
        .expand((c) => c.readings)
        .expand((r) => r.sections)
        .length;
    expect(count, greaterThan(50));
    expect(lastRow, findsNothing);
    expect(
      _inSheet(find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('add-tick-'),
      )).evaluate().length,
      lessThan(count),
    );
    await t.scrollUntilVisible(
      lastRow,
      300,
      scrollable: _inSheet(find.byType(Scrollable)).first,
    );
    expect(lastRow, findsOneWidget);
  });
}
