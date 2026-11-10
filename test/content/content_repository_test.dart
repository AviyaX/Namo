import 'dart:convert';

import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _StringBundle extends CachingAssetBundle {
  _StringBundle(this.text);
  final String text;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled content loads: 1 category, 1 reading, 19 sections', () async {
    final lib = await AssetContentRepository(rootBundle).load();
    final r = lib.categories.single.readings.single;
    expect(lib.categories.single.title, 'Buddha Wandanawa');
    expect(lib.categories.single.subtitle, 'බුද්ධ වන්දනාව');
    expect(r.sections.length, 19);
    expect(r.sections.map((s) => s.number), List.generate(19, (i) => i + 1));
    expect(lib.reading('namaskaraya'), same(r));
    expect(lib.reading('nope'), isNull);
    expect(lib.categoryOf('namaskaraya'), same(lib.categories.single));
    expect(lib.category(lib.categories.single.id), same(lib.categories.single));
  });

  test('a file with another schema number is refused', () {
    final repo = AssetContentRepository(
        _StringBundle('{"schema": 2, "categories": []}'));
    expect(repo.load(), throwsFormatException);
  });
}
