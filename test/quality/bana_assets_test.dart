// The shipped bana list (assets/bana/bana.json) read from disk, checked
// against the YouTube titles the tool built it from.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final file = jsonDecode(File('assets/bana/bana.json').readAsStringSync())
      as Map<String, Object?>;
  final draft = (jsonDecode(File('tool/bana/draft-list.json').readAsStringSync())
          as List)
      .cast<Map<String, Object?>>();
  final youtubeTitle = {for (final d in draft) d['id'] as String: d['title']};
  List<Map<String, Object?>> list(String key) =>
      (file[key] as List).cast<Map<String, Object?>>();

  test('every id is 11 characters and unique', () {
    final ids = [for (final b in list('bana')) b['id'] as String];
    expect(ids.every((i) => i.length == 11), isTrue);
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('every series part exists in bana, in its series', () {
    final byId = {for (final b in list('bana')) b['id']: b};
    for (final s in list('series')) {
      final parts = (s['parts'] as List).cast<String>();
      for (var i = 0; i < parts.length; i++) {
        final b = byId[parts[i]];
        expect(b, isNotNull, reason: parts[i]);
        expect(b!['series'], s['id']);
        expect(b['part'], i + 1);
        expect(b['topics'], isEmpty);
      }
    }
  });

  test('every topic, speaker and channel id resolves', () {
    Set<Object?> ids(String key) => {for (final m in list(key)) m['id']};
    final topics = ids('topics'), speakers = ids('speakers');
    final channels = ids('channels');
    for (final m in [...list('bana'), ...list('series')]) {
      expect(speakers, contains(m['speaker']));
      expect(channels, contains(m['channel']));
      expect(topics.containsAll(m['topics'] as List), isTrue, reason: '${m['id']}');
    }
  });

  test('every title is non-empty and made of pieces of the YouTube title', () {
    for (final b in list('bana')) {
      final title = b['title'] as String;
      expect(title.trim(), isNotEmpty);
      final source = youtubeTitle[b['id']];
      expect(source, isNotNull, reason: '${b['id']} is in the draft');
      for (final piece in title.split(' · ')) {
        expect((source as String).contains(piece), isTrue,
            reason: '"$piece" not in "$source"');
      }
    }
  });
}
