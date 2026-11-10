import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';

Future<void> openSources(WidgetTester t) async {
  // The bundled file is read by real I/O, which fake-async time cannot
  // advance; read it first and hand the app the finished library.
  final library = await t.runAsync(
    () => AssetContentRepository(rootBundle).load(),
  );
  await pumpApp(
    t,
    overrides: [
      contentRepositoryProvider.overrideWithValue(
        FakeContentRepository(library: library),
      ),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
    ],
    location: Routes.sources,
    size: const Size(390, 6000),
  );
}

Finder text(String s) => find.text(s, findRichText: true);

int keyed(String prefix) => find
    .byWidgetPredicate(
      (w) => w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(prefix),
    )
    .evaluate()
    .length;

void main() {
  testWidgets(
    'Sources names all four sources and says the app is not connected with namo.lk',
    (t) async {
      await openSources(t);
      expect(find.byKey(const ValueKey('screen-sources')), findsOneWidget);
      expect(
        text('Namo is free. It has no ads and nothing to buy.'),
        findsOneWidget,
      );
      expect(
        text('Namo is not made by, or connected with, namo.lk.'),
        findsOneWidget,
      );
      expect(find.textContaining('namo.lk', findRichText: true), findsWidgets);
      expect(find.textContaining('paritha.org'), findsWidgets);
      expect(find.textContaining('Mahamevnawa'), findsWidgets);
      expect(find.textContaining('Cynthia Gunawardana'), findsWidgets);

      expect(text('https://namo.lk/buddha-puja/'), findsOneWidget);
      expect(
        text('https://www.paritha.org/wp-content/uploads/2019/11/Booklet-1.pdf'),
        findsOneWidget,
      );
      expect(
        text(
          'https://www.mahamevnawa.ca/uploads/1/0/7/1/107195823/vandana_v1.pdf',
        ),
        findsOneWidget,
      );
      // Addresses are selectable text, not links.
      expect(find.byType(SelectableText), findsNWidgets(3));

      final icon = t.getSize(find.byKey(const ValueKey('sources-icon')));
      expect(icon, const Size(96, 96));
    },
  );

  testWidgets('Sources lists the corrections and the open checks from the content',
      (t) async {
    await openSources(t);
    expect(find.text('Corrections'), findsOneWidget);
    expect(find.text('Still to be checked'), findsOneWidget);
    // The bundled file: 15 distinct verse corrections and 1 heading.
    expect(keyed('correction-'), 16);
    expect(keyed('check-'), 4);
    expect(find.textContaining('ගච්චාමි'), findsOneWidget);
    expect(find.textContaining('ගච්ඡාමි'), findsOneWidget);
  });

  testWidgets('Font licences opens the licence page', (t) async {
    await openSources(t);
    await t.tap(find.text('Font licences'));
    await t.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets(
    'Sources prints no arrow character; corrections show both forms and say the relation in words',
    (t) async {
      final handle = t.ensureSemantics();
      await openSources(t);
      final arrows = RegExp('[←-⇿]');
      for (final w in t.widgetList<Text>(find.byType(Text))) {
        expect(w.data ?? w.textSpan?.toPlainText() ?? '', isNot(contains(arrows)));
      }
      for (final w in t.widgetList<SelectableText>(find.byType(SelectableText))) {
        expect(w.data ?? '', isNot(contains(arrows)));
      }
      // Both printed forms are on the first row, apart from each other.
      final row = find.byKey(const ValueKey('correction-0'));
      expect(
        find.descendant(of: row, matching: find.text('ගච්චාමි')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('ගච්ඡාමි')),
        findsOneWidget,
      );
      expect(
        t.getSemantics(row).label,
        startsWith('ගච්චාමි, corrected to ගච්ඡාමි'),
      );
      handle.dispose();
    },
  );

  testWidgets('a correction row with long forms wraps without overflow', (t) async {
    await openSources(t);
    expect(t.takeException(), isNull);
    for (var i = 0; i < 16; i++) {
      final box = t.getRect(find.byKey(ValueKey('correction-$i')));
      expect(box.right, lessThanOrEqualTo(390));
    }
  });
}
