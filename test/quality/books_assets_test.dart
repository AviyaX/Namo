// The shipped Rerukane books (assets/books/): the index, the 23 gzipped book
// files, the covers and any pictures, read from disk as the app will ship
// them. tools/sync_books.py --check makes the same checks from the Python side.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _slugs = [
  'bauddhayage-athpotha',
  'dharma-winishchaya',
  'paramitha-prakaranaya',
  'suvisi-gunaya',
  'abhidharmaye-mulika-karunu',
  'abhidharma-margaya',
  'chathurarya-sathya',
  'punyopadeshaya',
  'shasanavatharanaya',
  'bodhi-pakshika-dharma',
  'patichcha-samuppada-vivaranaya',
  'upasampada-sheelaya',
  'ubhaya-prathimokshaya',
  'wanchaka-dharma',
  'vidarshana-bhavana-kramaya',
  'keles-1500',
  'pohoya-dinaya',
  'bodhi-poojawa',
  'chaththalisakara-vipassana',
  'vinaya-karma',
  'sathipttana-bhavana-kramaya',
  'nirvana-vinishchaya',
  'pattana-pakarana-sannaya',
];

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
// No-break spaces (U+00A0) do occur in the source's own text and are kept as
// text, so they are not checked for here.
final _leadingNumber = RegExp(r'^\(?\d+[.)]');

Map<String, Object?> _index() =>
    jsonDecode(File('assets/books/index.json').readAsStringSync())
        as Map<String, Object?>;

Map<String, Object?> _book(String slug) {
  final bytes = Uint8List.fromList(
    File('assets/books/$slug.json.gz').readAsBytesSync(),
  );
  return jsonDecode(utf8.decode(gunzipIfNeeded(bytes))) as Map<String, Object?>;
}

/// Every string a reader would draw in [block].
Iterable<String> _texts(Map<String, Object?> block) sync* {
  for (final key in ['text', 'alt']) {
    final v = block[key];
    if (v is String) yield v;
  }
  for (final key in ['lines', 'items']) {
    final v = block[key];
    if (v is List) yield* v.cast<String>();
  }
  final rows = block['rows'];
  if (rows is List) {
    for (final row in rows) {
      yield* (row as List).cast<String>();
    }
  }
}

void main() {
  test('the index lists the 23 books in order with matching files', () {
    final index = _index();
    expect(index['schema'], 1);
    final books = (index['books'] as List).cast<Map<String, Object?>>();
    expect([for (final b in books) b['id']], _slugs);
    for (final b in books) {
      final id = b['id'];
      final file = File(b['file'] as String);
      expect(file.existsSync(), isTrue, reason: '$id file');
      final bytes = file.readAsBytesSync();
      expect(bytes.length, b['bytes'], reason: '$id bytes');
      expect(sha256.convert(bytes).toString(), b['sha256'], reason: '$id sha256');
      final cover = File(b['cover'] as String);
      expect(cover.existsSync(), isTrue, reason: '$id cover');
      expect(
        cover.readAsBytesSync().take(8).toList(),
        _pngSignature,
        reason: '$id cover is a PNG',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('every page has a title and text or children, levels never jump', () {
    for (final slug in _slugs) {
      final book = _book(slug);
      final pages = (book['pages'] as List).cast<Map<String, Object?>>();
      expect(pages, isNotEmpty, reason: slug);
      var previous = 0;
      for (var i = 0; i < pages.length; i++) {
        final page = pages[i];
        final where = '$slug page ${i + 1}';
        expect(page['n'], i + 1, reason: where);
        if (page['key'] == 'front') expect(i, 0, reason: '$where front first');
        expect((page['title'] as String).trim(), isNotEmpty, reason: where);
        final level = page['level'] as int;
        expect(level, inInclusiveRange(1, previous + 1), reason: '$where level');
        previous = level;
        final blocks = (page['blocks'] as List).cast<Map<String, Object?>>();
        final next = i + 1 < pages.length ? pages[i + 1]['level'] as int : 0;
        if (blocks.isEmpty) {
          expect(next, greaterThan(level), reason: '$where has no text and no children');
        }
        for (final block in blocks) {
          for (final text in _texts(block)) {
            expect(text.contains('<'), isFalse, reason: '$where: $text');
            expect(text.contains('&nbsp;'), isFalse, reason: '$where: $text');
          }
          // A list the reader numbers itself must not carry its own numbers.
          final marker = block['marker'];
          if (block['kind'] == 'list' && marker != 'none') {
            for (final item in (block['items'] as List).cast<String>()) {
              expect(_leadingNumber.hasMatch(item), isFalse, reason: '$where: $item');
            }
          }
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('nothing else is bundled under assets/books/', (t) async {
    final pictures = <String>{
      for (final slug in _slugs)
        for (final page in (_book(slug)['pages'] as List).cast<Map<String, Object?>>())
          for (final block in (page['blocks'] as List).cast<Map<String, Object?>>())
            if (block['kind'] == 'image' && block['asset'] != null)
              block['asset'] as String,
    };
    final names = (await t.runAsync(
      () async => (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets(),
    ))!;
    expect(
      names.where((a) => a.startsWith('assets/books/')).toSet(),
      {
        'assets/books/index.json',
        for (final s in _slugs) 'assets/books/$s.json.gz',
        for (final s in _slugs) 'assets/books/covers/$s.png',
        ...pictures,
      },
    );
  });
}
