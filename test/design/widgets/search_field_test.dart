import 'package:buddhist_gatha/design/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_support.dart';

void main() {
  testWidgets('is not focused on first build', (t) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await pumpThemed(t, SearchField(controller: c, label: 'Search'));
    final field = t.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isFalse);
  });

  testWidgets('typing shows the clear button; it empties the field', (t) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    final seen = <String>[];
    await pumpThemed(
      t,
      SearchField(controller: c, label: 'Search', onChanged: seen.add),
    );
    expect(find.byTooltip('Clear search'), findsNothing);
    await t.enterText(find.byType(TextField), 'ab');
    await t.pump();
    expect(seen, ['ab']);
    expect(find.byTooltip('Clear search'), findsOneWidget);
    await t.tap(find.byTooltip('Clear search'));
    await t.pump();
    expect(c.text, '');
    expect(seen.last, '');
    expect(find.byTooltip('Clear search'), findsNothing);
  });

  testWidgets('the semantics label is the given label', (t) async {
    final handle = t.ensureSemantics();
    final c = TextEditingController();
    addTearDown(c.dispose);
    await pumpThemed(
      t,
      SearchField(controller: c, label: 'Search the library'),
    );
    expect(find.bySemanticsLabel('Search the library'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('is at least 48 high and shows a ring while focused', (t) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await pumpThemed(t, SearchField(controller: c, label: 'Search'));
    expect(
      t.getSize(find.byType(SearchField)).height,
      greaterThanOrEqualTo(48),
    );
    expect(find.byKey(const ValueKey('search-focus-ring')), findsNothing);
    await t.tap(find.byType(TextField));
    await t.pump();
    expect(find.byKey(const ValueKey('search-focus-ring')), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320 wide at 2x text with text and clear button ($b)', (
      t,
    ) async {
      final c = TextEditingController(text: 'a long query that goes on');
      addTearDown(c.dispose);
      await pumpThemed(
        t,
        SizedBox(
          width: 320,
          child: SearchField(controller: c, label: 'Search the library'),
        ),
        brightness: b,
        size: const Size(320, 800),
        textScale: 2,
      );
      expect(t.takeException(), isNull);
    });
  }
}
