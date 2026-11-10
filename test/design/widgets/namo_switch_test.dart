import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/namo_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpSwitch(WidgetTester t, bool value, Brightness b) async {
  await t.pumpWidget(
    MaterialApp(
      theme: namoTheme(b),
      home: Scaffold(
        body: Center(child: NamoSwitch(value: value, onChanged: (_) {})),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  for (final b in Brightness.values) {
    final p = b == Brightness.dark ? NamoPalette.dark : NamoPalette.light;
    testWidgets('NamoSwitch colours come from the palette (${b.name})', (t) async {
      await pumpSwitch(t, true, b);
      var s = t.widget<Switch>(find.byType(Switch));
      expect(s.trackColor!.resolve({}), p.sage);
      expect(s.thumbColor!.resolve({}), p.onSage);
      await pumpSwitch(t, false, b);
      s = t.widget<Switch>(find.byType(Switch));
      expect(s.trackColor!.resolve({}), p.border);
      expect(s.trackOutlineColor!.resolve({}), p.textMuted);
      expect(s.thumbColor!.resolve({}), p.textMuted);
    });
  }

  testWidgets('NamoSwitch thumb sits at the end when on, the start when off',
      (t) async {
    await pumpSwitch(t, false, Brightness.light);
    final off = _thumbPosition(t);
    await pumpSwitch(t, true, Brightness.light);
    final on = _thumbPosition(t);
    expect(off, 0.0);
    expect(on, 1.0);
  });
}

/// How far along the track the thumb is, 0 (start) to 1 (end).
double _thumbPosition(WidgetTester t) {
  final state = t.state(
    find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MaterialSwitch'),
  );
  return ((state as dynamic).positionController as AnimationController).value;
}
