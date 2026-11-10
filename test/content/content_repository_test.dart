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

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(files[key]!)));
}

String _file(String id) =>
    '{"schema": 1, "categories": [{"id": "$id", "title": "T", "subtitle": "S", "readings": []}]}';

void main() {
  test('two files merge in order', () async {
    final repo = AssetContentRepository(
      _MapBundle({'a.json': _file('c-a'), 'b.json': _file('c-b')}),
      paths: const ['a.json', 'b.json'],
    );
    final lib = await repo.load();
    expect(lib.categories.map((c) => c.id), ['c-a', 'c-b']);
  });

  test('a second file with another schema number fails the load', () {
    final repo = AssetContentRepository(
      _MapBundle({
        'a.json': _file('c-a'),
        'b.json': '{"schema": 2, "categories": []}',
      }),
      paths: const ['a.json', 'b.json'],
    );
    expect(repo.load(), throwsFormatException);
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled content loads: Buddha Wandanawa (1 reading, 19 sections), then Pirith', () async {
    final lib = await AssetContentRepository(rootBundle).load();
    expect(lib.categories.map((c) => c.id), ['cat-namaskaraya', 'cat-pirith']);
    final first = lib.categories.first;
    final r = first.readings.single;
    expect(first.title, 'Buddha Wandanawa');
    expect(first.subtitle, 'බුද්ධ වන්දනාව');
    expect(r.sections.length, 19);
    expect(r.sections.map((s) => s.number), List.generate(19, (i) => i + 1));
    expect(lib.reading('namaskaraya'), same(r));
    expect(lib.reading('nope'), isNull);
    expect(lib.categoryOf('namaskaraya'), same(first));
    expect(lib.category(first.id), same(first));
  });

  test('a file with another schema number is refused', () {
    final repo = AssetContentRepository(
        _StringBundle('{"schema": 2, "categories": []}'));
    expect(repo.load(), throwsFormatException);
  });
}
