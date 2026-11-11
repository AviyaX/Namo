import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quality_support.dart';

/// The keys the content file may hold at each level; anything else (a
/// caption's words or times riding along from the tool) is not wanted.
const _known = <String, Set<String>>{
  'root': {'schema', 'categories'},
  'category': {'id', 'title', 'subtitle', 'short_title', 'readings'},
  'reading': {'id', 'title', 'title_roman', 'audio', 'sections'},
  'audio': {
    'asset',
    'label',
    'duration_ms',
    'bytes',
    'sha256',
    'block_times',
    'line_times',
  },
  'section': {
    'id',
    'number',
    'heading',
    'source',
    'check',
    'corrections',
    'verses',
  },
  'source': {'name', 'locator', 'collected', 'translator'},
  'correction': {'field', 'from', 'to', 'reason'},
  'verse': {'id', 'check', 'keep_lines', 'always_shown', 'phrases', 'sinhala'},
  'phrase': {'pali', 'sinhala', 'english'},
};

void main() {
  // Only the names in the bundle's manifest are read here, never the bytes of
  // the recording.
  Future<List<String>> manifest() async =>
      (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();

  testWidgets('the bundle has exactly one file under '
      'assets/audio/samantha_patthana/, the one the Vandana names', (t) async {
    final names = (await t.runAsync(manifest))!;
    final audio = names
        .where((a) => a.startsWith('assets/audio/samantha_patthana/'))
        .toList();
    final lib = await realLibrary(t);
    final vandana = lib.reading(spVandanaId)!;
    expect(vandana.audio, isNotNull);
    expect(audio, [vandana.audio!.asset]);
    expect(lib.reading(spIntroductionId)!.audio, isNull);
    // No caption file is bundled anywhere.
    expect(names.where((a) => a.contains('caption')), isEmpty);
    expect(names.where((a) => a.endsWith('.json3')), isEmpty);
  });

  testWidgets('the card picture is in the bundle', (t) async {
    final names = (await t.runAsync(manifest))!;
    expect(names, contains('assets/pictures/samantha_patthana.jpg'));
  });

  testWidgets('the content file holds only the known keys', (t) async {
    final text = (await t.runAsync(
      () => rootBundle.loadString('assets/content/samantha_patthana.json'),
    ))!;
    final json = jsonDecode(text) as Map<String, dynamic>;
    final seen = <String>{};

    void keys(String level, Object? o) {
      final map = o! as Map<String, dynamic>;
      seen.add(level);
      expect(
        _known[level]!.containsAll(map.keys),
        isTrue,
        reason: '$level has ${map.keys.toSet().difference(_known[level]!)}',
      );
    }

    keys('root', json);
    for (final c in json['categories'] as List) {
      keys('category', c);
      for (final r in (c as Map)['readings'] as List) {
        keys('reading', r);
        final audio = (r as Map)['audio'];
        if (audio != null) {
          keys('audio', audio);
          // Times only: pairs of seconds, and a second (or nothing) a line.
          for (final b in (audio as Map)['block_times'] as List) {
            expect(b == null || (b as List).every((x) => x is num), isTrue);
          }
          for (final l in audio['line_times'] as List) {
            expect((l as List).every((x) => x == null || x is num), isTrue);
          }
        }
        for (final s in r['sections'] as List) {
          keys('section', s);
          keys('source', (s as Map)['source']);
          for (final x in s['corrections'] as List) {
            keys('correction', x);
          }
          for (final v in s['verses'] as List) {
            keys('verse', v);
            for (final p in (v as Map)['phrases'] as List? ?? const []) {
              keys('phrase', p);
            }
          }
        }
      }
    }
    expect(seen, containsAll(['audio', 'verse', 'phrase']));
  });
}
