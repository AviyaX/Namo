import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/design/widgets/surface_card.dart';
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
    size: const Size(390, 8000),
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
        text('Namo is not made by, or connected with, namo.lk or pitaka.lk.'),
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
      expect(find.byType(SelectableText), findsNWidgets(4));

      final icon = t.getSize(find.byKey(const ValueKey('sources-icon')));
      expect(icon, const Size(96, 96));
    },
  );

  testWidgets('Sources credits pitaka.lk/pirith and never says permission', (
    t,
  ) async {
    await openSources(t);
    expect(text('pitaka.lk/pirith (pathnirvana)'), findsOneWidget);
    expect(
      text(
        'Pirith: Pali text and Sinhala meaning from the Piruwana Poth '
        'Wahanse, as published at pitaka.lk/pirith; English meaning as '
        'given there (its origin is not stated). Chanted by Ven. Nauyane '
        'Ariyadhamma Thero. Licence named by the source: Creative Commons '
        'Attribution-NoDerivatives 4.0 International.',
      ),
      findsOneWidget,
    );
    expect(text('https://pitaka.lk/pirith/'), findsOneWidget);
    expect(text('Pirith card picture'), findsOneWidget);
    expect(
      find.textContaining('used with permission', findRichText: true),
      findsNothing,
    );
  });

  testWidgets(
    'Sources shows the Pictures heading with the "Home card picture" credit and no address under it',
    (t) async {
      final handle = t.ensureSemantics();
      await openSources(t);
      const detail =
          'Made for this app by its owner with an AI image tool. It is a '
          'generated picture, not a photograph of a real statue or place.';
      expect(find.text('Pictures'), findsOneWidget);
      expect(text('Home card picture'), findsOneWidget);
      expect(text(detail), findsOneWidget);
      // Only the four text sources have an address.
      expect(find.byType(SelectableText), findsNWidgets(4));
      // After the text sources, before Corrections.
      final y = t.getTopLeft(find.text('Pictures')).dy;
      expect(y, greaterThan(t.getTopLeft(text('The rest of the English.')).dy));
      final name = t.getTopLeft(text('Home card picture')).dy;
      final note = t.getRect(text(detail));
      final corrections = t.getTopLeft(find.text('Corrections')).dy;
      expect(name, greaterThan(y));
      expect(note.top, greaterThan(name));
      expect(note.bottom, lessThan(corrections));
      // Nothing between the picture credits and the next heading but their
      // padding: the Pirith picture credit is the last one.
      final last = t.getRect(
        find.textContaining('Shown on the Pirith card', findRichText: true),
      );
      expect(last.top, greaterThan(note.bottom));
      expect(corrections - last.bottom, lessThan(48));
      handle.dispose();
    },
  );

  testWidgets('Sources credits the Home banner picture under Pictures', (t) async {
    await openSources(t);
    final name = text('Home banner picture');
    expect(name, findsOneWidget);
    expect(
      find.textContaining('the top of Home on wide screens', findRichText: true),
      findsOneWidget,
    );
    final y = t.getTopLeft(find.text('Pictures')).dy;
    expect(t.getTopLeft(name).dy, greaterThan(t.getTopLeft(text('Home card picture')).dy));
    expect(t.getTopLeft(name).dy, greaterThan(y));
    expect(t.getTopLeft(name).dy, lessThan(t.getTopLeft(find.text('Corrections')).dy));
  });

  testWidgets('Sources no longer mentions Wikimedia or Price Zero', (t) async {
    await openSources(t);
    expect(find.textContaining('Wikimedia', findRichText: true), findsNothing);
    expect(find.textContaining('Price Zero', findRichText: true), findsNothing);
    expect(find.textContaining('Samadhi', findRichText: true), findsNothing);
  });

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

  testWidgets('Sources has a Back button above the title that returns to Settings',
      (t) async {
    await openSources(t);
    final back = find.byTooltip('Back');
    expect(back, findsOneWidget);
    expect(
      t.getTopLeft(back).dy,
      lessThan(t.getTopLeft(find.text('Sources')).dy),
    );
    expect(t.getSize(back).width, greaterThanOrEqualTo(48));
    expect(find.byType(AppBar), findsNothing);
    await t.tap(back);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-settings')), findsOneWidget);
  });

  testWidgets('each credit, correction and check is a surface card', (t) async {
    await openSources(t);
    // 5 text sources + 3 pictures + 16 corrections + 4 checks.
    expect(find.byType(SurfaceCard), findsNWidgets(28));
  });

  for (final dark in [false, true]) {
    for (final w in [320.0, 360.0, 390.0, 840.0]) {
      testWidgets('Sources does not overflow at $w, ${dark ? 'dark' : 'light'}',
          (t) async {
        t.platformDispatcher.textScaleFactorTestValue = w == 320 ? 2.0 : 1.0;
        t.platformDispatcher.platformBrightnessTestValue =
            dark ? Brightness.dark : Brightness.light;
        addTearDown(() {
          t.platformDispatcher.clearTextScaleFactorTestValue();
          t.platformDispatcher.clearPlatformBrightnessTestValue();
        });
        await openSources(t);
        t.view.physicalSize = Size(w, 800);
        await t.pumpAndSettle();
        for (var i = 0; i < 10; i++) {
          await t.drag(find.byType(Scrollable).first, const Offset(0, -600));
          await t.pump();
        }
        expect(t.takeException(), isNull);
      });
    }
  }
}
