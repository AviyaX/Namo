import 'package:buddhist_gatha/settings/powered_by.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'settings_screen_test.dart' show openSettings;

void main() {
  testWidgets('Settings ends with a Powered by IntendAble link', (t) async {
    final opened = <Uri>[];
    await openSettings(t, extra: [
      linkOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
    ]);
    final link = find.byKey(const ValueKey('powered-by'));
    expect(link, findsOneWidget);
    expect(find.text('Powered by IntendAble'), findsOneWidget);
    await t.ensureVisible(link);
    await t.tap(link);
    await t.pump();
    expect(opened, [Uri.parse('https://www.intendable.us/')]);
  });

  testWidgets('the link is announced as a link', (t) async {
    final h = t.ensureSemantics();
    await openSettings(t);
    expect(
      t.getSemantics(find.bySemanticsLabel('Powered by IntendAble')),
      isSemantics(
        label: 'Powered by IntendAble',
        isLink: true,
        hasTapAction: true,
      ),
    );
    h.dispose();
  });

  testWidgets('a link that cannot open says so', (t) async {
    await openSettings(t, extra: [
      linkOpenerProvider.overrideWithValue((uri) async => false),
    ]);
    final link = find.byKey(const ValueKey('powered-by'));
    await t.ensureVisible(link);
    await t.tap(link);
    await t.pump();
    expect(find.text('Could not open www.intendable.us.'), findsOneWidget);
  });
}
