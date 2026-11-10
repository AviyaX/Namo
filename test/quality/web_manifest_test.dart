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
}
