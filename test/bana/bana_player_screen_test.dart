import 'package:buddhist_gatha/bana/bana_progress.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/powered_by.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../quality/quality_support.dart';
import 'bana_support.dart';

Finder _k(String k) => find.byKey(ValueKey(k));

String _location(WidgetTester t) =>
    GoRouter.of(t.element(find.byType(Scaffold).first))
        .routerDelegate
        .currentConfiguration
        .last
        .matchedLocation;

const _offline = 'Bana play from YouTube and need an internet connection.';

Future<FakePlayers> _open(
  WidgetTester t,
  String id, {
  List<Uri>? opened,
  bool ready = true,
}) async {
  final fake = FakePlayers();
  await openReal(
    t,
    Routes.banaPlay(id),
    players: fake,
    overrides: [
      ...banaOverrides(),
      if (opened != null)
        linkOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
    ],
  );
  if (ready) {
    fake.ready();
    await t.pump();
  }
  return fake;
}

void main() {
  testWidgets('shows the player, part line and neighbours', (t) async {
    final fake = await _open(t, 'v2');
    expect(fake.lastVideoId, 'v2');
    expect(_k('fake-player'), findsOneWidget);
    expect(find.text('PART 2 OF 3'), findsOneWidget);
    expect(find.text('Calm part 2'), findsOneWidget);
    expect(find.text('Ven. Alpha'), findsOneWidget);
    expect(find.text('10:00 · From YouTube · Chan'), findsOneWidget);
    expect(find.text('Part 1'), findsOneWidget);
    expect(find.text('Part 3'), findsOneWidget);
    expect(find.text('NEXT IN THIS SERIES'), findsOneWidget);
    expect(find.text('Calm part 3'), findsOneWidget);
    expect(find.text('All 3 parts ›'), findsOneWidget);
    final size = t.getSize(_k('fake-player'));
    expect(size.width, lessThanOrEqualTo(720));
    expect(size.width / size.height, closeTo(16 / 9, 0.01));
  });

  testWidgets('part 1 has no Previous; the last part has no Next', (t) async {
    await _open(t, 'v1');
    expect(_k('bana-previous'), findsNothing);
    expect(_k('bana-next'), findsOneWidget);
    expect(find.text('NEXT IN THIS SERIES'), findsOneWidget);
    await t.tap(_k('bana-next'));
    await t.pumpAndSettle();
    expect(_location(t), Routes.banaPlay('v2'));
  });

  testWidgets('the last part has no Next and no series list', (t) async {
    await _open(t, 'v3');
    expect(_k('bana-next'), findsNothing);
    expect(_k('bana-previous'), findsOneWidget);
    expect(find.text('NEXT IN THIS SERIES'), findsNothing);
    expect(find.text('All 3 parts ›'), findsOneWidget);
    await t.tap(_k('bana-previous'));
    await t.pumpAndSettle();
    expect(_location(t), Routes.banaPlay('v2'));
  });

  testWidgets('All parts opens the series page', (t) async {
    await _open(t, 'v1');
    await t.ensureVisible(find.text('All 3 parts ›'));
    await t.tap(find.text('All 3 parts ›'));
    await t.pumpAndSettle();
    expect(_location(t), Routes.banaSeries('s1'));
  });

  testWidgets('opening a part records progress', (t) async {
    await _open(t, 'v2');
    final container = ProviderScope.containerOf(
      t.element(find.byType(Scaffold).first),
    );
    expect(container.read(banaProgressProvider), {'s1': 'v2'});
  });

  testWidgets('an error shows the offline panel; Try again rebuilds the player',
      (t) async {
    final fake = await _open(t, 'v1');
    expect(fake.created, 1);
    fake.fail();
    await t.pump();
    expect(find.text(_offline), findsOneWidget);
    expect(_k('fake-player'), findsNothing);
    expect(find.text('Open in YouTube'), findsWidgets);
    await t.tap(find.text('Try again'));
    await t.pump();
    expect(fake.created, 2);
    expect(find.text(_offline), findsNothing);
    expect(_k('fake-player'), findsOneWidget);
    fake.ready();
    await t.pump();
  });

  testWidgets('no ready within 15 s shows the offline panel', (t) async {
    await _open(t, 'v1', ready: false);
    await t.pump(const Duration(seconds: 14));
    expect(find.text(_offline), findsNothing);
    await t.pump(const Duration(seconds: 1));
    expect(find.text(_offline), findsOneWidget);
  });

  testWidgets('ready in time keeps the player and cancels the timeout',
      (t) async {
    await _open(t, 'v1');
    await t.pump(const Duration(seconds: 30));
    expect(find.text(_offline), findsNothing);
    expect(_k('fake-player'), findsOneWidget);
  });

  testWidgets('a not-embeddable bana shows only Open in YouTube', (t) async {
    final opened = <Uri>[];
    final fake = FakePlayers();
    await openReal(
      t,
      Routes.banaPlay('v1'),
      players: fake,
      overrides: [
        banaNotEmbeddableOverride('v1'),
        linkOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    expect(fake.created, 0);
    expect(_k('fake-player'), findsNothing);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Open in YouTube'), findsOneWidget);
    await t.tap(find.text('Open in YouTube'));
    await t.pump();
    expect(opened, [Uri.parse('https://www.youtube.com/watch?v=v1')]);
  });

  testWidgets('Open in YouTube opens the watch URL', (t) async {
    final opened = <Uri>[];
    await _open(t, 'v2', opened: opened);
    await t.ensureVisible(_k('bana-open-youtube'));
    await t.tap(_k('bana-open-youtube'));
    await t.pump();
    expect(opened, [Uri.parse('https://www.youtube.com/watch?v=v2')]);
  });

  testWidgets('a single bana has no part line or series list', (t) async {
    await _open(t, 'x1');
    expect(find.text('Alpha single'), findsOneWidget);
    expect(find.text('1:02:05 · From YouTube · Chan'), findsOneWidget);
    expect(find.textContaining('PART'), findsNothing);
    expect(find.text('NEXT IN THIS SERIES'), findsNothing);
    expect(find.textContaining('parts ›'), findsNothing);
    expect(_k('bana-previous'), findsNothing);
    expect(_k('bana-next'), findsNothing);
  });

  testWidgets('leaving the page disposes the player', (t) async {
    final fake = await _open(t, 'v1');
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(fake.disposed, 1);
  });

  testWidgets('unknown id shows not found', (t) async {
    await _open(t, 'nope', ready: false);
    expect(find.text('This page could not be found.'), findsOneWidget);
  });
}
