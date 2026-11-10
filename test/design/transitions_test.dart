import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/design/transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _pageKey = ValueKey('the-page');

Future<GoRouter> _pump(WidgetTester t, {bool disableAnimations = false}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('home')),
        routes: [
          GoRoute(
            path: 'page',
            pageBuilder: (context, state) => namoPage(
              key: state.pageKey,
              context: context,
              child: const Align(
                alignment: Alignment.topLeft,
                child: SizedBox(key: _pageKey, width: 50, height: 50),
              ),
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    MaterialApp.router(
      theme: namoTheme(Brightness.dark),
      routerConfig: router,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
        ),
        child: c!,
      ),
    ),
  );
  return router;
}

double _opacity(WidgetTester t) {
  final o = find
      .ancestor(of: find.byKey(_pageKey), matching: find.byType(Opacity))
      .first;
  return t.widget<Opacity>(o).opacity;
}

void main() {
  testWidgets('a pushed page fades in and rises over 300 ms', (t) async {
    final router = await _pump(t);
    router.push('/page');
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));
    final o = _opacity(t);
    expect(o, greaterThan(0));
    expect(o, lessThan(1));
    final dy = t.getTopLeft(find.byKey(_pageKey)).dy;
    expect(dy, greaterThan(0));
    expect(dy, lessThan(12));
    await t.pump(const Duration(milliseconds: 150));
    expect(_opacity(t), 1);
    expect(t.getTopLeft(find.byKey(_pageKey)).dy, 0);
  });

  testWidgets('a popped page fades out within 200 ms', (t) async {
    final router = await _pump(t);
    router.push('/page');
    await t.pumpAndSettle();
    router.pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(_opacity(t), lessThan(1));
    expect(_opacity(t), greaterThan(0));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 1));
    expect(find.byKey(_pageKey), findsNothing);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('with animations off, push and pop are done after one pump',
      (t) async {
    final router = await _pump(t, disableAnimations: true);
    router.push('/page');
    await t.pump();
    await t.pump();
    expect(_opacity(t), 1);
    expect(t.getTopLeft(find.byKey(_pageKey)).dy, 0);
    router.pop();
    await t.pump();
    await t.pump();
    expect(find.byKey(_pageKey), findsNothing);
  });
}
