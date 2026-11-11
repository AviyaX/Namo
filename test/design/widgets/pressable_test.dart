import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/pressable.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_support.dart';

Widget _box({VoidCallback? onTap}) => Pressable(
      onTap: onTap,
      semanticLabel: 'Open',
      child: const SizedBox(width: 20, height: 20),
    );

/// The colour being painted now, mid-animation included.
Color _tint(WidgetTester t) {
  final box = t.widget<DecoratedBox>(find.descendant(
    of: find.byKey(const ValueKey('pressable-tint')),
    matching: find.byType(DecoratedBox),
  ));
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  group('Pressable', () {
    testWidgets('a 20 x 20 child still has a 48 x 48 tap area', (t) async {
      var taps = 0;
      await pumpThemed(t, _box(onTap: () => taps++));
      expect(t.getSize(find.byType(Pressable)), const Size(48, 48));
      await t.tapAt(t.getTopLeft(find.byType(Pressable)) + const Offset(2, 2));
      expect(taps, 1);
    });

    testWidgets('Enter and Space activate when focused', (t) async {
      var taps = 0;
      await pumpThemed(t, _box(onTap: () => taps++));
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 1);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps, 2);
    });

    testWidgets('onTap null: nothing fires, disabled, not focusable', (t) async {
      final handle = t.ensureSemantics();
      await pumpThemed(t, _box());
      await t.tap(find.byType(Pressable));
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(find.byKey(const ValueKey('pressable-focus-ring')), findsNothing);
      final data = t.getSemantics(find.bySemanticsLabel('Open')).getSemanticsData();
      expect(data.flagsCollection.isEnabled.name, 'isFalse');
      expect(data.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('keyboard focus paints a sage ring', (t) async {
      await pumpThemed(t, _box(onTap: () {}));
      expect(find.byKey(const ValueKey('pressable-focus-ring')), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      final ring = t.widget<DecoratedBox>(find.byKey(const ValueKey('pressable-focus-ring')));
      final border = (ring.decoration as BoxDecoration).border! as Border;
      expect(border.top.color, NamoPalette.dark.sage);
      expect(border.top.width, 2);
    });

    testWidgets('announces label, button and selected', (t) async {
      final handle = t.ensureSemantics();
      await pumpThemed(
        t,
        Pressable(onTap: () {}, semanticLabel: 'Open', selected: true, child: const Text('x')),
      );
      final data = t.getSemantics(find.bySemanticsLabel('Open')).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isSelected.name, 'isTrue');
      expect(data.flagsCollection.isEnabled.name, 'isTrue');
      handle.dispose();
    });

    testWidgets('size never changes while pressed', (t) async {
      await pumpThemed(t, _box(onTap: () {}));
      final before = t.getRect(find.byType(Pressable));
      final g = await t.startGesture(t.getCenter(find.byType(Pressable)));
      await t.pump(const Duration(milliseconds: 60));
      expect(t.getRect(find.byType(Pressable)), before);
      await g.up();
      await t.pumpAndSettle();
      expect(t.getRect(find.byType(Pressable)), before);
    });

    testWidgets('press tint fades in; instant with animations disabled', (t) async {
      await pumpThemed(t, _box(onTap: () {}), disableAnimations: true);
      final g = await t.startGesture(t.getCenter(find.byType(Pressable)));
      await t.pump();
      expect(_tint(t), NamoPalette.dark.pressed);
      await g.up();
    });

    testWidgets('press tint takes the press duration otherwise', (t) async {
      await pumpThemed(t, _box(onTap: () {}));
      final g = await t.startGesture(t.getCenter(find.byType(Pressable)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(_tint(t), isNot(NamoPalette.dark.pressed));
      await t.pump(const Duration(milliseconds: 80));
      expect(_tint(t), NamoPalette.dark.pressed);
      await g.up();
    });

    testWidgets('hover tints and shows a click cursor', (t) async {
      await pumpThemed(t, _box(onTap: () {}));
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(t.getCenter(find.byType(Pressable)));
      await t.pumpAndSettle();
      expect(_tint(t), NamoPalette.dark.hovered);
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );
    });
  });
}
