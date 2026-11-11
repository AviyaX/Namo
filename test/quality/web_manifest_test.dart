import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the installed web app is not locked to one orientation', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync()) as Map;
    expect(manifest['name'], 'Namo');
    expect(manifest.containsKey('orientation'), isFalse);
  });

  test('the splash, theme and background colour is the dark #151714', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync()) as Map;
    expect(manifest['background_color'], '#151714');
    expect(manifest['theme_color'], '#151714');
    expect(File('web/index.html').readAsStringSync(), isNot(contains('2B3837')));
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(r'flutter_native_splash:\s+color:\s*"#151714"').hasMatch(pubspec),
      isTrue,
    );
    expect(pubspec, isNot(contains('2B3837')));
  });
}
