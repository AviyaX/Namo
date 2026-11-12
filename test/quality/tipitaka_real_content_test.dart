// The whole shipped Tripitaka, every book: what the reader does with each
// text must work on all of it. (test/tipitaka/tipitaka_repository_test.dart
// already counts nodes and readings and checks that the readings' lengths add
// up; this adds the markup, the Pali display rule, the files and that each
// entry is shown exactly once.)
import 'dart:convert';
import 'dart:io';

import 'package:buddhist_gatha/tipitaka/pali_display.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_book.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_markup.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_tree.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tipitaka/tipitaka_support.dart';

const _zwj = '‍';

String _withoutJoiners(String s) => s.replaceAll(_zwj, '');

/// Checks the display rule adds joiners and nothing else.
void _expectOnlyJoinersAdded(String text, String where) {
  final shown = paliForDisplay(text);
  if (identical(shown, text) || shown == text) return;
  expect(_withoutJoiners(shown), _withoutJoiners(text), reason: where);
}

/// Parses [text]; a throw fails the test with where it came from.
void _expectParses(String text, String where) {
  try {
    parseMarkup(text);
  } catch (e) {
    fail('parseMarkup threw on $where: $e');
  }
}

void main() {
  final repo = TipitakaRepository(load: diskAssets(), inBackground: false);
  late TipitakaTree tree;
  late Map<String, Object?> manifestJson;

  setUpAll(() async {
    tree = await repo.tree();
    manifestJson = jsonDecode(
      await File(tipitakaManifestAsset).readAsString(),
    ) as Map<String, Object?>;
  });

  test('tree readings match the manifest', () async {
    expect(tree.readings.length, (await repo.manifest()).readings);
  });

  test("every node's file is shipped and listed in the manifest", () {
    final shipped = {
      for (final f in Directory('assets/tipitaka/text').listSync())
        if (f is File && f.path.endsWith('.json.gz'))
          f.uri.pathSegments.last.replaceFirst(RegExp(r'\.json\.gz$'), ''),
    };
    expect(shipped, hasLength(190));
    final listed = (manifestJson['files']! as Map).keys.toSet();
    final files = <String>{};
    void walk(String key) {
      final node = tree.node(key)!;
      files.add(node.file);
      for (final c in tree.children(key)) {
        walk(c.key);
      }
    }

    for (final root in TipitakaTree.roots) {
      walk(root);
    }
    for (final file in files) {
      expect(shipped, contains(file), reason: 'node file $file');
      expect(listed, contains('text/$file'), reason: 'manifest lists $file');
    }
    // Every shipped book is some node's file.
    expect(files, containsAll(shipped));
  });

  test('every book: readings, ranges, markup and the Pali display rule',
      () async {
    final files = {for (final k in tree.readings) tree.node(k)!.file};
    expect(files, hasLength(190));
    var readings = 0;
    var entries = 0;
    var notes = 0;
    for (final file in files.toList()..sort()) {
      // Decoded here (not through the repository) to know the page count,
      // so every page's footnotes are reached.
      final json = jsonDecode(utf8.decode(gunzipIfNeeded(
        await File(tipitakaBookAsset(file)).readAsBytes(),
      )));
      final book = TipitakaBook.parse(file, json);
      final pages = ((json as Map)['pages'] as List).length;

      // Each entry is in exactly one reading's display range.
      final indexOf = Map<TipitakaEntry, int>.identity();
      for (var i = 0; i < book.pali.length; i++) {
        indexOf[book.pali[i]] = i;
      }
      final shown = List<int>.filled(book.pali.length, 0);
      for (final n in tree.nodesInFile(file)) {
        if (!tree.isReading(n.key)) continue;
        final r = readingOf(tree, book, n.key);
        expect(r, isNotNull, reason: n.key);
        expect(r!.pali, isNotEmpty, reason: n.key);
        expect(r.sinhala.length, r.pali.length, reason: n.key);
        final start = indexOf[r.pali.first]!;
        for (var i = 0; i < r.pali.length; i++) {
          expect(identical(book.pali[start + i], r.pali[i]), isTrue,
              reason: '${n.key} is one run of the book');
          shown[start + i]++;
        }
        readings++;
      }
      final wrong = [
        for (var i = 0; i < shown.length; i++)
          if (shown[i] != 1) '$i: ${shown[i]}',
      ];
      expect(wrong, isEmpty, reason: '$file entries not shown exactly once');

      for (var i = 0; i < book.pali.length; i++) {
        final pali = book.pali[i].text;
        _expectParses(pali, '$file pali entry $i');
        _expectOnlyJoinersAdded(pali, '$file pali entry $i');
        entries++;
      }
      // Every Sinhala entry, also those of a page whose two lists differ in
      // length (the reader leaves them out, but they are parsed all the same).
      for (var p = 0; p < pages; p++) {
        final side = (json['pages'] as List)[p]['sinh'];
        final list = side is Map ? side['entries'] : null;
        if (list is! List) continue;
        for (var j = 0; j < list.length; j++) {
          final text = (list[j] as Map)['text'];
          if (text is String) _expectParses(text, '$file page $p sinhala $j');
          entries++;
        }
      }
      for (var p = 0; p < pages; p++) {
        final paliNotes = book.footnotes(p, pali: true);
        for (var j = 0; j < paliNotes.length; j++) {
          _expectParses(paliNotes[j], '$file page $p pali note $j');
          _expectOnlyJoinersAdded(paliNotes[j], '$file page $p pali note $j');
          notes++;
        }
        final sinhalaNotes = book.footnotes(p, pali: false);
        for (var j = 0; j < sinhalaNotes.length; j++) {
          _expectParses(sinhalaNotes[j], '$file page $p sinhala note $j');
          notes++;
        }
      }
    }
    expect(readings, tree.readings.length);
    expect(entries, greaterThan(0));
    expect(notes, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('the Pali display rule adds only joiners to every Pali name', () {
    void walk(String key) {
      final node = tree.node(key)!;
      _expectOnlyJoinersAdded(node.pali, 'name of $key');
      for (final c in tree.children(key)) {
        walk(c.key);
      }
    }

    for (final root in TipitakaTree.roots) {
      walk(root);
    }
  });
}
