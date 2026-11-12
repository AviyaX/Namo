import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_book.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_tree.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tipitaka_support.dart';

/// Wraps [inner], counting loads per path.
class _Counting {
  _Counting(this.inner);
  final AssetBytes inner;
  final counts = <String, int>{};
  Future<Uint8List> call(String path) {
    counts[path] = (counts[path] ?? 0) + 1;
    return inner(path);
  }
}

void main() {
  group('gunzipIfNeeded', () {
    test('gunzipIfNeeded unpacks gzip and passes plain bytes through', () {
      final plain = Uint8List.fromList(utf8.encode('{"a":1}'));
      final packed = Uint8List.fromList(GZipEncoder().encodeBytes(plain));
      expect(packed[0], 0x1f);
      expect(gunzipIfNeeded(packed), plain);
      expect(gunzipIfNeeded(plain), same(plain));
      expect(gunzipIfNeeded(Uint8List(0)), isEmpty);
    });
  });

  group('TipitakaRepository', () {
    test('loads manifest, tree and books from gzip assets', () async {
      final repo = TipitakaRepository(load: fakeAssets(tinyTipitaka()));
      final manifest = await repo.manifest();
      expect(manifest.commit, 'abc123');
      expect(manifest.commitDate, '2026-01-02');
      expect(manifest.readings, 7);
      expect(manifest.parentsWithText, {'vp-2'});
      final tree = await repo.tree();
      expect(tree.readings.length, 7);
      expect(tree.isReading('vp-2'), isTrue);
      final book = await repo.book('vp-a');
      expect(book.pali.first.text, 'Title A');
    });

    test('loads plain JSON served already unpacked', () async {
      final repo =
          TipitakaRepository(load: fakeAssets(tinyTipitaka(), gzip: false));
      expect((await repo.tree()).readings.length, 7);
      expect((await repo.book('ap-b')).pali.length, 6);
    });

    test('parses on the calling isolate when inBackground is false', () async {
      final repo = TipitakaRepository(
          load: fakeAssets(tinyTipitaka()), inBackground: false);
      expect((await repo.tree()).readings.length, 7);
      expect((await repo.book('vp-a')).pali.length, 14);
    });

    test('nothing is loaded until asked for', () async {
      final counting = _Counting(fakeAssets(tinyTipitaka()));
      TipitakaRepository(load: counting.call);
      await Future<void>.delayed(Duration.zero);
      expect(counting.counts, isEmpty);
    });

    test('tree is loaded once', () async {
      final counting = _Counting(fakeAssets(tinyTipitaka()));
      final repo = TipitakaRepository(load: counting.call);
      final results = await Future.wait([repo.tree(), repo.tree()]);
      expect(identical(results[0], results[1]), isTrue);
      expect(identical(await repo.tree(), results[0]), isTrue);
      expect(counting.counts[tinyTreePath], 1);
      expect(counting.counts[tinyManifestPath], 1);
    });

    test('keeps at most keepBooks books', () async {
      final assets = tinyTipitaka();
      for (var i = 1; i <= 5; i++) {
        assets[tinyBookPath('b$i')] = tinyBookB();
      }
      final counting = _Counting(fakeAssets(assets));
      final repo = TipitakaRepository(load: counting.call, keepBooks: 4);
      for (var i = 1; i <= 4; i++) {
        await repo.book('b$i');
      }
      await repo.book('b1'); // b1 becomes the most recent
      expect(counting.counts[tinyBookPath('b1')], 1);
      await repo.book('b5'); // drops b2, the least recent
      await repo.book('b1');
      expect(counting.counts[tinyBookPath('b1')], 1);
      await repo.book('b2');
      expect(counting.counts[tinyBookPath('b2')], 2);
      // b2 coming back dropped b3; b4, b5 and b1 are still kept.
      await repo.book('b4');
      await repo.book('b5');
      expect(counting.counts[tinyBookPath('b4')], 1);
      expect(counting.counts[tinyBookPath('b5')], 1);
      await repo.book('b3');
      expect(counting.counts[tinyBookPath('b3')], 2);
    });

    test('a failed load surfaces as an error and is not cached', () async {
      final assets = tinyTipitaka();
      var fail = true;
      final inner = fakeAssets(assets);
      final counting = _Counting((path) {
        if (fail) throw StateError('broken $path');
        return inner(path);
      });
      final repo = TipitakaRepository(load: counting.call);
      await expectLater(repo.tree(), throwsA(anything));
      await expectLater(repo.book('vp-a'), throwsA(anything));
      fail = false;
      expect((await repo.tree()).readings.length, 7);
      expect((await repo.book('vp-a')).pali.length, 14);
      expect(counting.counts[tinyBookPath('vp-a')], 2);
    });

    test('broken gzip, broken JSON and a non-book fail as errors', () async {
      final good = fakeAssets(tinyTipitaka());
      final repo = TipitakaRepository(load: (path) async {
        if (path.endsWith('/zip.json.gz')) {
          return Uint8List.fromList([0x1f, 0x8b, 1, 2, 3]);
        }
        if (path.endsWith('/json.json.gz')) {
          return Uint8List.fromList(utf8.encode('{not json'));
        }
        if (path.endsWith('/list.json.gz')) {
          return Uint8List.fromList(utf8.encode('[1,2]'));
        }
        return good(path);
      });
      await expectLater(repo.book('zip'), throwsA(anything));
      await expectLater(repo.book('json'), throwsA(anything));
      await expectLater(repo.book('list'), throwsA(isA<FormatException>()));
      await expectLater(repo.book('missing'), throwsA(anything));
    });
  });

  group('providers', () {
    ProviderContainer container() {
      final c = ProviderContainer(overrides: [
        tipitakaRepositoryProvider.overrideWithValue(
            TipitakaRepository(load: fakeAssets(tinyTipitaka()))),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('reading provider gives a reading, or null for unknown keys and lists',
        () async {
      final c = container();
      final r = await c.read(tipitakaReadingProvider('vp-2').future);
      expect(r!.pali.map((e) => e.text), ['Part two', 'Part two intro']);
      expect(await c.read(tipitakaReadingProvider('nope').future), isNull);
      expect(await c.read(tipitakaReadingProvider('vp-1').future), isNull);
      expect((await c.read(tipitakaManifestProvider.future)).readings, 7);
      expect((await c.read(tipitakaTreeProvider.future)).readings.length, 7);
    });
  });

  group('real data', () {
    final repo = TipitakaRepository(load: diskAssets());

    test('real tree has 9414 nodes and 8408 readings', () async {
      final tree = await repo.tree();
      var nodes = 0;
      void walk(String key) {
        nodes++;
        for (final c in tree.children(key)) {
          walk(c.key);
        }
      }

      for (final r in TipitakaTree.roots) {
        expect(tree.node(r)!.parent, isNull);
        walk(r);
      }
      expect(nodes, 9414);
      expect(tree.readings.length, 8408);
      expect(tree.readingCount('vp') + tree.readingCount('sp') +
          tree.readingCount('ap'), 8408);
    });

    test('manifest readings equals tree.readings.length', () async {
      final manifest = await repo.manifest();
      expect(manifest.readings, (await repo.tree()).readings.length);
      expect(manifest.parentsWithText.length, 53);
    });

    test('dn-1 parses and its first reading has entries and Sinhala', () async {
      final tree = await repo.tree();
      final book = await repo.book('dn-1');
      final first =
          tree.nodesInFile('dn-1').firstWhere((n) => tree.isReading(n.key));
      final reading = readingOf(tree, book, first.key)!;
      expect(reading.pali, isNotEmpty);
      expect(reading.sinhala.length, reading.pali.length);
      expect(reading.hasSinhala, isTrue);
      var shown = 0;
      for (final n in tree.nodesInFile('dn-1')) {
        shown += readingOf(tree, book, n.key)?.pali.length ?? 0;
      }
      expect(shown, book.pali.length);
    });

    test('every entry of every real book is in exactly one reading', () async {
      final all = TipitakaRepository(load: diskAssets(), keepBooks: 1);
      final tree = await all.tree();
      final files = {for (final k in tree.readings) tree.node(k)!.file};
      expect(files.length, 190);
      var readings = 0;
      for (final file in files) {
        final book = await all.book(file);
        var shown = 0;
        for (final n in tree.nodesInFile(file)) {
          final r = readingOf(tree, book, n.key);
          expect(r != null, tree.isReading(n.key), reason: n.key);
          if (r != null) {
            shown += r.pali.length;
            readings++;
          }
        }
        expect(shown, book.pali.length, reason: file);
      }
      expect(readings, 8408);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('ap-pat reading has no Sinhala', () async {
      final tree = await repo.tree();
      final key = tree.readings.firstWhere((k) => k.startsWith('ap-pat'));
      final node = tree.node(key)!;
      expect(node.file, startsWith('ap-pat'));
      final reading = readingOf(tree, await repo.book(node.file), key)!;
      expect(reading.pali, isNotEmpty);
      expect(reading.hasSinhala, isFalse);
    });
  });
}
