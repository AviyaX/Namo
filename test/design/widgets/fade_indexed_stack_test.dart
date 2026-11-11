import 'package:buddhist_gatha/design/widgets/fade_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_support.dart';

/// A child with state of its own: a count that goes up on each tap, and a
/// focus node so the test can see whether it may take focus.
class _Counter extends StatefulWidget {
  const _Counter(this.name, {super.key, this.focusNode});

  final String name;
  final FocusNode? focusNode;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: widget.focusNode,
        child: GestureDetector(
          onTap: () => setState(() => count++),
          child: Text('${widget.name}: $count'),
        ),
      );
}

Future<void> _pump(
  WidgetTester t,
  int index, {
  bool disableAnimations = false,
  FocusNode? aFocus,
  FocusNode? bFocus,
}) =>
    pumpThemed(
      t,
      SizedBox(
        width: 300,
        height: 300,
        child: FadeIndexedStack(
          index: index,
          children: [
            _Counter('a', key: const ValueKey('a'), focusNode: aFocus),
            _Counter('b', key: const ValueKey('b'), focusNode: bFocus),
          ],
        ),
      ),
      disableAnimations: disableAnimations,
    );

/// The opacity [finder] is painted with: every fade above it multiplied.
double _opacity(WidgetTester t, Finder finder) {
  var o = 1.0;
  for (final e in find
      .ancestor(of: finder, matching: find.byType(FadeTransition))
      .evaluate()) {
    o *= (e.widget as FadeTransition).opacity.value;
  }
  for (final e
      in find.ancestor(of: finder, matching: find.byType(Opacity)).evaluate()) {
    o *= (e.widget as Opacity).opacity;
  }
  return o;
}

Finder _text(String s) => find.text(s, skipOffstage: false);

void main() {
  group('FadeIndexedStack', () {
    testWidgets('a child keeps its state when another is shown and it comes back',
        (t) async {
      await _pump(t, 0);
      for (var i = 0; i < 3; i++) {
        await t.tap(find.text('a: $i'));
        await t.pump();
      }
      expect(find.text('a: 3'), findsOneWidget);
      await _pump(t, 1);
      await t.pumpAndSettle();
      expect(find.text('b: 0'), findsOneWidget);
      await _pump(t, 0);
      await t.pumpAndSettle();
      expect(find.text('a: 3'), findsOneWidget);
    });

    testWidgets('the hidden child stays mounted but is not hit-testable, '
        'not in semantics and cannot take focus', (t) async {
      final h = t.ensureSemantics();
      final aFocus = FocusNode();
      final bFocus = FocusNode();
      addTearDown(aFocus.dispose);
      addTearDown(bFocus.dispose);
      await _pump(t, 0, aFocus: aFocus, bFocus: bFocus);
      expect(_text('b: 0'), findsOneWidget, reason: 'still mounted');
      expect(_text('b: 0').hitTestable(), findsNothing);
      expect(find.text('a: 0').hitTestable(), findsOneWidget);
      expect(find.bySemanticsLabel('b: 0'), findsNothing);
      expect(find.bySemanticsLabel('a: 0'), findsOneWidget);
      expect(bFocus.canRequestFocus, isFalse);
      expect(aFocus.canRequestFocus, isTrue);

      await _pump(t, 1, aFocus: aFocus, bFocus: bFocus);
      await t.pumpAndSettle();
      expect(_text('a: 0').hitTestable(), findsNothing);
      expect(find.bySemanticsLabel('a: 0'), findsNothing);
      expect(aFocus.canRequestFocus, isFalse);
      expect(bFocus.canRequestFocus, isTrue);
      h.dispose();
    });

    testWidgets('mid-switch both children are partly visible', (t) async {
      await _pump(t, 0);
      await _pump(t, 1);
      await t.pump(const Duration(milliseconds: 100));
      final a = _opacity(t, _text('a: 0'));
      final b = _opacity(t, _text('b: 0'));
      expect(a, inExclusiveRange(0, 1));
      expect(b, inExclusiveRange(0, 1));
      // The switch takes NamoMotion.quick (200 ms) from its first frame.
      await t.pump(const Duration(milliseconds: 200));
      expect(_opacity(t, _text('b: 0')), 1);
      expect(find.text('a: 0'), findsNothing, reason: 'offstage once done');
    });

    testWidgets('with animations off the switch is done after one frame',
        (t) async {
      await _pump(t, 0, disableAnimations: true);
      await _pump(t, 1, disableAnimations: true);
      await t.pump();
      expect(find.text('a: 0'), findsNothing);
      expect(find.text('b: 0'), findsOneWidget);
      expect(_opacity(t, find.text('b: 0')), 1);
    });
  });
}
