import 'dart:convert';

import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';

Future<void> _open(WidgetTester t, AppSettings settings) async {
  final store = InMemoryKeyValueStore();
  await store.write(settingsKey, jsonEncode(settings.toJson()));
  await pumpApp(
    t,
    overrides: [
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      keyValueStoreProvider.overrideWithValue(store),
    ],
    location: Routes.reader('r1'),
  );
}

void main() {
  testWidgets(
    'Pali and Sinhala sit side by side, Pali left, top-aligned, Sinhala quiet',
    (t) async {
      await _open(t, const AppSettings(layout: TwoLanguageLayout.sideBySide));
      final pi = t.getRect(find.byKey(const ValueKey('pair-s01-v1-pi')));
      final si = t.getRect(find.byKey(const ValueKey('pair-s01-v1-si')));
      expect(si.top, closeTo(pi.top, 0.5));
      expect(pi.right, lessThanOrEqualTo(si.left));
      final context = t.element(find.byKey(const ValueKey('pair-s01-v1-si')));
      expect(
        t
            .widget<Text>(find.byKey(const ValueKey('pair-s01-v1-si')))
            .style!
            .color,
        NamoPalette.of(context).textSecondary,
      );
      expect(
        t
            .widget<Text>(find.byKey(const ValueKey('pair-s01-v1-pi')))
            .style!
            .color,
        NamoPalette.of(context).text,
      );
    },
  );

  testWidgets('Sinhala chosen first still puts Pali on the left', (t) async {
    await _open(
      t,
      const AppSettings(
        layout: TwoLanguageLayout.sideBySide,
        languages: LanguageSelection([
          ReadingLanguage.sinhala,
          ReadingLanguage.pali,
        ]),
      ),
    );
    expect(
      t.getRect(find.byKey(const ValueKey('pair-s01-v1-pi'))).left,
      lessThan(t.getRect(find.byKey(const ValueKey('pair-s01-v1-si'))).left),
    );
  });

  testWidgets('with Pali and English the saved side by side draws verse by '
      'verse', (t) async {
    await _open(
      t,
      const AppSettings(
        layout: TwoLanguageLayout.sideBySide,
        languages: LanguageSelection([
          ReadingLanguage.pali,
          ReadingLanguage.english,
        ]),
      ),
    );
    expect(find.byKey(const ValueKey('pair-s01-v1-pi')), findsNothing);
    expect(find.byKey(const ValueKey('verse-s01-v1-pi')), findsOneWidget);
    expect(find.byKey(const ValueKey('verse-s01-v1-en')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
