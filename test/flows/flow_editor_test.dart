import 'dart:convert';

import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/design/widgets/not_found.dart';
import 'package:buddhist_gatha/flows/flows.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import 'flow_test_support.dart';

const _moveUp = CustomSemanticsAction(label: 'Move up');
const _moveDown = CustomSemanticsAction(label: 'Move down');

final _a = ref('r1', 's01'), _b = ref('r1', 's02'), _c = ref('r1', 's03');

String _id(FlowRef r) => '${r.readingId}~${r.sectionId}';

Finder _row(FlowRef r) => find.byKey(ValueKey('flow-row-${_id(r)}'));

/// The row's own node: its number and title, with the move actions.
SemanticsNode _node(WidgetTester t, FlowRef r) => t.getSemantics(
  find.descendant(of: _row(r), matching: find.byType(Semantics)).first,
);

Set<String> _actions(WidgetTester t, FlowRef r) => {
  for (final id
      in _node(t, r).getSemanticsData().customSemanticsActionIds ?? <int>[])
    CustomSemanticsAction.getAction(id)!.label!,
};

/// The rows' titles from top to bottom.
List<String> _titles(WidgetTester t, List<FlowRef> refs) {
  final shown = [
    for (final r in refs)
      if (_row(r).evaluate().isNotEmpty) r,
  ]..sort((x, y) => t.getTopLeft(_row(x)).dy.compareTo(t.getTopLeft(_row(y)).dy));
  return [for (final r in shown) _id(r)];
}

Future<void> _openMoveMenu(WidgetTester t, FlowRef r) async {
  await t.tap(find.byKey(ValueKey('flow-move-${_id(r)}')));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadBundledFonts);

  final editor = Routes.flowEditor('flow-1');

  testWidgets('shows the name, the count and the rows in flow order, '
      'numbered 1 to 3', (t) async {
    await openFlows(t, editor, {
      'flow-1': [_b, _a, _c],
    });
    expect(find.text('Flow 1'), findsOneWidget);
    expect(find.text('3 sections'), findsOneWidget);
    expect(_titles(t, [_a, _b, _c]), [_id(_b), _id(_a), _id(_c)]);
    for (final (i, r) in [_b, _a, _c].indexed) {
      expect(
        find.descendant(of: _row(r), matching: find.text('${i + 1}')),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: _row(_b), matching: find.text('heading 2')),
      findsOneWidget,
    );
  });

  testWidgets('a reading with one section is named by the reading\'s title',
      (t) async {
    await openFlows(t, editor, {
      'flow-1': [ref('r3', 'p'), ref('r2', 's02')],
    });
    expect(
      find.descendant(of: _row(ref('r3', 'p')), matching: find.text('reading 3')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _row(ref('r2', 's02')),
        matching: find.text('heading 2.2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a section the content no longer has is not listed or counted, '
      'and stays stored through other edits', (t) async {
    final gone = ref('r1', 's99');
    final c = await openFlows(t, editor, {
      'flow-1': [_a, gone, _b, _c],
    });
    expect(find.text('3 sections'), findsOneWidget);
    expect(_row(gone), findsNothing);
    expect(_titles(t, [_a, _b, _c]), [_id(_a), _id(_b), _id(_c)]);

    final h = t.ensureSemantics();
    t.semantics.customAction(
      find.semantics.byPredicate((n) => n.id == _node(t, _a).id),
      _moveDown,
    );
    await t.pumpAndSettle();
    h.dispose();
    expect(_titles(t, [_a, _b, _c]), [_id(_b), _id(_a), _id(_c)]);
    expect(savedFlow(c, 'flow-1')!.sections, contains(gone));
    expect(savedFlow(c, 'flow-1')!.sections.length, 4);

    await t.tap(find.byKey(ValueKey('flow-remove-${_id(_c)}')));
    await t.pumpAndSettle();
    expect(find.text('2 sections'), findsOneWidget);
    expect(savedFlow(c, 'flow-1')!.sections, [gone, _b, _a]);
  });

  group('moving', () {
    testWidgets('"Move down" on row 1 through the screen reader gives b, a, c, '
        'held and stored', (t) async {
      final c = await openFlows(t, editor, {
        'flow-1': [_a, _b, _c],
      });
      final h = t.ensureSemantics();
      expect(_actions(t, _a), {'Move down'});
      expect(_actions(t, _b), {'Move up', 'Move down'});
      expect(_actions(t, _c), {'Move up'});
      t.semantics.customAction(
        find.semantics.byPredicate((n) => n.id == _node(t, _a).id),
        _moveDown,
      );
      await t.pumpAndSettle();
      expect(heldFlow(c, 'flow-1')!.sections, [_b, _a, _c]);
      expect(savedFlow(c, 'flow-1')!.sections, [_b, _a, _c]);
      expect(_titles(t, [_a, _b, _c]), [_id(_b), _id(_a), _id(_c)]);
      // The moved row now offers both moves, the new first row only down.
      expect(_actions(t, _a), {'Move up', 'Move down'});
      expect(_actions(t, _b), {'Move down'});
      t.semantics.customAction(
        find.semantics.byPredicate((n) => n.id == _node(t, _c).id),
        _moveUp,
      );
      await t.pumpAndSettle();
      expect(savedFlow(c, 'flow-1')!.sections, [_b, _c, _a]);
      h.dispose();
    });

    testWidgets('"Move down" on row 1 from its menu gives b, a, c, held and '
        'stored; the ends offer only the move they can make', (t) async {
      final c = await openFlows(t, editor, {
        'flow-1': [_a, _b, _c],
      });
      await _openMoveMenu(t, _a);
      expect(find.text('Move up'), findsNothing);
      expect(find.text('Move down'), findsOneWidget);
      await t.tap(find.text('Move down'));
      await t.pumpAndSettle();
      expect(heldFlow(c, 'flow-1')!.sections, [_b, _a, _c]);
      expect(savedFlow(c, 'flow-1')!.sections, [_b, _a, _c]);

      await _openMoveMenu(t, _c);
      expect(find.text('Move up'), findsOneWidget);
      expect(find.text('Move down'), findsNothing);
      await t.tap(find.text('Move up'));
      await t.pumpAndSettle();
      expect(savedFlow(c, 'flow-1')!.sections, [_b, _c, _a]);
    });

    testWidgets('the menu opens and moves from the keyboard', (t) async {
      final c = await openFlows(t, editor, {
        'flow-1': [_a, _b, _c],
      });
      final menu = find.byKey(ValueKey('flow-move-${_id(_b)}'));
      bool menuFocused() {
        final focus = FocusManager.instance.primaryFocus?.context;
        return focus != null &&
            find
                .descendant(
                  of: menu,
                  matching: find.byElementPredicate((e) => e == focus),
                )
                .evaluate()
                .isNotEmpty;
      }

      // Tab until the menu button of row 2 has focus.
      for (var i = 0; i < 30 && !menuFocused(); i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
      }
      expect(menuFocused(), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.text('Move up'), findsOneWidget);
      expect(find.text('Move down'), findsOneWidget);
      // The first move has focus; the arrow key goes on to the second.
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(savedFlow(c, 'flow-1')!.sections, [_a, _c, _b]);
    });

    testWidgets('dragging row 1 by its handle below row 2 gives b, a, c',
        (t) async {
      final c = await openFlows(t, editor, {
        'flow-1': [_a, _b, _c],
      });
      final handle = find.byKey(ValueKey('flow-handle-${_id(_a)}'));
      final rowHeight = t.getSize(_row(_a)).height;
      final gesture = await t.startGesture(t.getCenter(handle));
      await t.pump();
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset(0, rowHeight * 1.5 / 10));
        await t.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await t.pumpAndSettle();
      expect(savedFlow(c, 'flow-1')!.sections, [_b, _a, _c]);
    });

    testWidgets('a single row has no move menu', (t) async {
      await openFlows(t, editor, {
        'flow-1': [_a],
      });
      expect(find.byKey(ValueKey('flow-move-${_id(_a)}')), findsNothing);
      expect(find.byKey(ValueKey('flow-remove-${_id(_a)}')), findsOneWidget);
    });
  });

  group('removing', () {
    testWidgets('remove row 2 shows "Removed" with "Undo"; Undo puts it back '
        'in the same place', (t) async {
      final c = await openFlows(t, editor, {
        'flow-1': [_a, _b, _c],
      });
      await t.tap(find.byKey(ValueKey('flow-remove-${_id(_b)}')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(savedFlow(c, 'flow-1')!.sections, [_a, _c]);
      expect(find.text('2 sections'), findsOneWidget);
      expect(find.text('Removed'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(savedFlow(c, 'flow-1')!.sections, [_a, _b, _c]);
      expect(_titles(t, [_a, _b, _c]), [_id(_a), _id(_b), _id(_c)]);
    });

    testWidgets('Undo still works after leaving the page', (t) async {
      final c = await openFlows(t, editor, {
        'flow-1': [_a, _b, _c],
      });
      await t.tap(find.byKey(ValueKey('flow-remove-${_id(_b)}')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.byTooltip('Back'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(location(c), Routes.library);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(savedFlow(c, 'flow-1')!.sections, [_a, _b, _c]);
    });

    testWidgets('after the message times out the removal stays', (t) async {
      final c = await openFlows(t, editor, {
        'flow-1': [_a, _b, _c],
      });
      await t.tap(find.byKey(ValueKey('flow-remove-${_id(_b)}')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Removed'), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
      expect(find.text('Removed'), findsNothing);
      expect(savedFlow(c, 'flow-1')!.sections, [_a, _c]);
    });
  });

  group('Start chanting', () {
    testWidgets('opens the flow in the reader, with Back to the editor',
        (t) async {
      final c = await openFlows(t, editor, {
        'flow-1': [_a, _b],
      });
      await t.tap(find.byKey(const ValueKey('flow-start')));
      await t.pumpAndSettle();
      expect(location(c), '/read/flow-1?from=editor');
    });

    testWidgets('an empty flow says so and cannot be chanted', (t) async {
      await openFlows(t, editor, {'flow-1': []});
      expect(find.text('This flow has no sections yet.'), findsOneWidget);
      expect(find.text('0 sections'), findsOneWidget);
      expect(
        t.widget<PrimaryButton>(find.byKey(const ValueKey('flow-start'))).onPressed,
        isNull,
      );
      expect(find.byKey(const ValueKey('flow-add')), findsOneWidget);
    });

    testWidgets('a flow whose every section is gone counts as empty',
        (t) async {
      await openFlows(t, editor, {
        'flow-1': [ref('r1', 's98'), ref('r9', 's01')],
      });
      expect(find.text('This flow has no sections yet.'), findsOneWidget);
      expect(
        t.widget<PrimaryButton>(find.byKey(const ValueKey('flow-start'))).onPressed,
        isNull,
      );
    });
  });

  group('renaming', () {
    Future<void> rename(WidgetTester t, String text) async {
      await t.tap(find.byKey(const ValueKey('flow-rename')));
      await t.pumpAndSettle();
      expect(find.text('Rename flow'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('flow-name-field')), text);
      await t.pump();
      await t.tap(find.byKey(const ValueKey('flow-name-confirm')));
      await t.pumpAndSettle();
    }

    testWidgets('the name is trimmed', (t) async {
      final c = await openFlows(t, editor, {'flow-1': [_a]});
      await rename(t, '  Evening  ');
      expect(savedFlow(c, 'flow-1')!.name, 'Evening');
      expect(find.text('Evening'), findsOneWidget);
    });

    testWidgets('an empty name becomes "My flow"', (t) async {
      final c = await openFlows(t, editor, {'flow-1': [_a]});
      await rename(t, '');
      expect(savedFlow(c, 'flow-1')!.name, 'My flow');
    });

    testWidgets('a 500-character paste keeps at most 40 characters, in the '
        'field and in storage', (t) async {
      final c = await openFlows(t, editor, {'flow-1': [_a]});
      await t.tap(find.byKey(const ValueKey('flow-rename')));
      await t.pumpAndSettle();
      final long = List.filled(50, 'abcdefghi\n').join();
      expect(long.length, 500);
      await t.enterText(find.byKey(const ValueKey('flow-name-field')), long);
      await t.pump();
      final field = t.widget<TextField>(
        find.byKey(const ValueKey('flow-name-field')),
      );
      expect(field.controller!.text.length, lessThanOrEqualTo(40));
      expect(field.controller!.text, isNot(contains('\n')));
      await t.tap(find.byKey(const ValueKey('flow-name-confirm')));
      await t.pumpAndSettle();
      final name = savedFlow(c, 'flow-1')!.name;
      expect(name.length, lessThanOrEqualTo(40));
      expect(name, isNot(contains('\n')));
      expect(name, startsWith('abcdefghi'));
    });

    testWidgets('dismissing the sheet changes nothing', (t) async {
      final c = await openFlows(t, editor, {'flow-1': [_a]});
      await t.tap(find.byKey(const ValueKey('flow-rename')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('flow-name-field')), 'Other');
      await t.tapAt(const Offset(195, 20));
      await t.pumpAndSettle();
      expect(find.text('Rename flow'), findsNothing);
      expect(savedFlow(c, 'flow-1')!.name, 'Flow 1');
    });
  });

  group('deleting', () {
    String place(WidgetTester t) => jsonEncode(
      PositionState(
        byReading: {
          'flow-1': ReadingProgress(
            position: ReadingPosition(
              readingId: 'flow-1',
              sectionId: _id(_b),
              fraction: 0.4,
            ),
            progress: 0.4,
          ),
        },
        lastReadingId: 'flow-1',
      ).toJson(),
    );

    testWidgets('"Keep" changes nothing', (t) async {
      final c = await openFlows(
        t,
        editor,
        {'flow-1': [_a, _b]},
        extras: {positionKey: place(t)},
      );
      await t.tap(find.byKey(const ValueKey('flow-delete')));
      await t.pumpAndSettle();
      expect(
        find.text('Delete "Flow 1"? This cannot be undone.'),
        findsOneWidget,
      );
      await t.tap(find.text('Keep'));
      await t.pumpAndSettle();
      expect(savedFlow(c, 'flow-1'), isNotNull);
      expect(c.read(positionProvider).byReading, contains('flow-1'));
      expect(location(c), editor);
    });

    testWidgets('"Delete" removes the flow and its place, and goes to the '
        'Library', (t) async {
      final c = await openFlows(
        t,
        editor,
        {'flow-1': [_a, _b], 'flow-2': [_c]},
        extras: {positionKey: place(t)},
      );
      await t.tap(find.byKey(const ValueKey('flow-delete')));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pump();
      // While the page leaves it still shows the flow, not "not found".
      expect(find.byType(NotFoundScreen), findsNothing);
      await t.pumpAndSettle();
      expect(savedFlow(c, 'flow-1'), isNull);
      expect(savedFlow(c, 'flow-2'), isNotNull);
      expect(c.read(positionProvider).byReading, isNot(contains('flow-1')));
      expect(location(c), Routes.library);
      expect(find.byType(NotFoundScreen), findsNothing);
    });
  });

  testWidgets('an unknown flow shows the not-found page', (t) async {
    await openFlows(t, Routes.flowEditor('flow-99'), {'flow-1': [_a]});
    expect(find.byType(NotFoundScreen), findsOneWidget);
  });

  testWidgets('Back goes to the Library', (t) async {
    final c = await openFlows(t, editor, {'flow-1': [_a]});
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(location(c), Routes.library);
  });

  testWidgets('every control of a row is at least 48 x 48', (t) async {
    await openFlows(t, editor, {
      'flow-1': [_a, _b, _c],
    });
    for (final key in ['flow-move', 'flow-remove', 'flow-handle']) {
      final size = t.getSize(find.byKey(ValueKey('$key-${_id(_b)}')));
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }
    for (final key in ['flow-rename', 'flow-add', 'flow-start', 'flow-delete']) {
      final size = t.getSize(find.byKey(ValueKey(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
    }
  });

  group('layout', () {
    /// The first three sections of the bundled Buddha Wandanawa, the pirith
    /// with the longest name, and a section the content does not have.
    Future<Map<String, List<FlowRef>>> realFlow(WidgetTester t) async {
      final lib = await realLibrary(t);
      final reading = lib.category(realCategoryId)!.readings.first;
      final pirith = [...lib.category(pirithCategoryId)!.readings]
        ..sort((x, y) => y.title.length - x.title.length);
      return {
        'flow-1': [
          for (final s in reading.sections.take(3)) ref(reading.id, s.id),
          ref(pirith.first.id, pirith.first.sections.single.id),
          ref(reading.id, 'no-such-section'),
        ],
      };
    }

    Future<void> openSheetAndScroll(WidgetTester t, String key) async {
      await t.tap(find.byKey(ValueKey(key)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final scrollable = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      );
      final position = t.state<ScrollableState>(scrollable.first).position;
      while (position.pixels < position.maxScrollExtent) {
        position.jumpTo(
          (position.pixels + position.viewportDimension).clamp(
            0.0,
            position.maxScrollExtent,
          ),
        );
        await t.pump();
        expect(t.takeException(), isNull);
      }
    }

    // A name of the longest length, as one unbroken word and as words, in
    // the header and in the delete dialog on the narrowest phone.
    for (final long in ['W' * 40, 'Evening chant for the long quiet weekend']) {
      for (final dark in [false, true]) {
        testWidgets('a 40-character name does not overflow the '
            'header or the delete dialog: 320x568, text 2.0x, '
            '${dark ? 'dark' : 'light'} (${long.contains(' ') ? 'words' : 'one word'})',
            (t) async {
          expect(long.length, flowNameMax);
          await openReal(
            t,
            editor,
            library: flowTestLibrary(),
            size: const Size(320, 568),
            deviceTextScale: 2.0,
            dark: dark,
            storeExtras: {
              flowsKey: jsonEncode(
                FlowsState(
                  flows: [
                    Flow(id: 'flow-1', name: long, sections: [_a, _b]),
                  ],
                  nextNumber: 2,
                ).toJson(),
              ),
            },
          );
          expect(t.takeException(), isNull);
          expect(find.text(long), findsOneWidget);
          final rename = t.getSize(find.byKey(const ValueKey('flow-rename')));
          expect(rename.width, greaterThanOrEqualTo(48));
          expect(rename.height, greaterThanOrEqualTo(48));
          await scrollThrough(t);

          final delete = find.byKey(const ValueKey('flow-delete'));
          await t.scrollUntilVisible(
            delete,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await t.pumpAndSettle();
          await t.tap(delete);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          expect(
            find.text('Delete "$long"? This cannot be undone.'),
            findsOneWidget,
          );
          for (final key in ['flow-delete-keep', 'flow-delete-confirm']) {
            final size = t.getSize(find.byKey(ValueKey(key)));
            expect(size.width, greaterThanOrEqualTo(48), reason: key);
            expect(size.height, greaterThanOrEqualTo(48), reason: key);
          }
          await t.tap(find.byKey(const ValueKey('flow-delete-keep')));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        });
      }
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
          Future<void> open(WidgetTester t) async => openFlows(
            t,
            editor,
            await realFlow(t),
            library: await realLibrary(t),
            size: size,
            deviceTextScale: scale,
            dark: dark,
          );

          testWidgets('the editor does not overflow: $name', (t) async {
            await open(t);
            expect(find.text('4 sections'), findsOneWidget);
            await scrollThrough(t);
          });

          testWidgets('the name sheet does not overflow: $name', (t) async {
            await open(t);
            await openSheetAndScroll(t, 'flow-rename');
            await t.enterText(
              find.byKey(const ValueKey('flow-name-field')),
              'W' * 40,
            );
            await t.pump();
            expect(t.takeException(), isNull);
          });

          testWidgets('the add sheet does not overflow: $name', (t) async {
            await open(t);
            final add = find.byKey(const ValueKey('flow-add'));
            await t.scrollUntilVisible(
              add,
              200,
              scrollable: find.byType(Scrollable).first,
            );
            await t.pumpAndSettle();
            await openSheetAndScroll(t, 'flow-add');
          });
        }
      }
    }
  });
}
