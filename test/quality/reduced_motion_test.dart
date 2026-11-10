import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/choosers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quality_support.dart';

/// With animations off, one pump after each action is enough to reach the end
/// state.
void main() {
  Future<void> open(WidgetTester t, String location, {Library? library}) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await openReal(t, location, size: const Size(390, 2400), library: library);
  }

  testWidgets('switching tab', (t) async {
    await open(t, Routes.home);
    await t.tap(find.byKey(const ValueKey('nav-library')));
    await t.pump();
    expect(find.byKey(const ValueKey('screen-library')), findsOneWidget);
    expect(find.byKey(const ValueKey('screen-home')), findsNothing);
  });

  testWidgets('opening a Library topic', (t) async {
    final lib = await buddhaOnlyLibrary(t);
    await open(t, Routes.library, library: lib);
    await t.tap(find.text(lib.category(realCategoryId)!.title));
    await t.pump();
    final column = find.byKey(const ValueKey('open-$realCategoryId'));
    expect(column, findsOneWidget);
    final full = t.getSize(column).height;
    await t.pumpAndSettle();
    expect(t.getSize(column).height, full);
  });

  testWidgets('opening the reader', (t) async {
    final lib = await buddhaOnlyLibrary(t);
    await open(t, Routes.library, library: lib);
    await t.tap(find.text(lib.category(realCategoryId)!.title));
    await t.pump();
    final heading = lib.reading(realReadingId)!.sections.first.heading;
    await t.tap(find.text(heading).first);
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('reader-top-bar')), findsOneWidget);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('opening the settings sheet and moving a selector', (t) async {
    await open(t, Routes.reader(realReadingId));
    await t.tap(find.byKey(const ValueKey('reader-settings')));
    await t.pump();
    await t.pump();
    final chooser = find.byType(LayoutChooser);
    expect(chooser, findsOneWidget);
    final sheetTop = t.getTopLeft(chooser).dy;
    await t.pumpAndSettle();
    expect(t.getTopLeft(chooser).dy, sheetTop);

    final thumb = find.descendant(
        of: chooser, matching: find.byKey(const ValueKey('selector-thumb')));
    final seg1 = find.descendant(
        of: chooser, matching: find.byKey(const ValueKey('segment-1')));
    await t.tap(seg1);
    await t.pump();
    expect(t.getRect(thumb), t.getRect(seg1));
  });
}
