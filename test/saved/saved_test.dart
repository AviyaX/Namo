import 'dart:convert';

import 'package:buddhist_gatha/saved/saved.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer containerOn(KeyValueStore store) {
  final c = ProviderContainer(
    overrides: [keyValueStoreProvider.overrideWithValue(store)],
  );
  addTearDown(c.dispose);
  return c;
}

List<String> marks(SavedState s) => [
  for (final b in s.bookmarks) '${b.readingId}/${b.sectionId}',
];

void main() {
  test('bookmarks toggle per section and several can exist in one reading', () {
    final c = containerOn(InMemoryKeyValueStore());
    final n = c.read(savedProvider.notifier);
    expect(c.read(savedProvider).bookmarks, isEmpty);

    n.toggleBookmark('r1', 's02');
    n.toggleBookmark('r1', 's01');
    n.toggleBookmark('r2', 's01');
    var s = c.read(savedProvider);
    // Newest first.
    expect(marks(s), ['r2/s01', 'r1/s01', 'r1/s02']);
    expect(s.isBookmarked('r1', 's01'), isTrue);
    expect(s.isBookmarked('r1', 's02'), isTrue);
    expect(s.isBookmarked('r1', 's03'), isFalse);
    expect(s.isBookmarked('r3', 's01'), isFalse);

    n.toggleBookmark('r1', 's02');
    s = c.read(savedProvider);
    expect(marks(s), ['r2/s01', 'r1/s01']);
    expect(s.isBookmarked('r1', 's02'), isFalse);
    expect(s.isFavourite('r1'), isFalse);
  });

  test('favourites toggle per reading', () {
    final c = containerOn(InMemoryKeyValueStore());
    final n = c.read(savedProvider.notifier);
    n.toggleFavourite('r1');
    n.toggleFavourite('r2');
    expect(c.read(savedProvider).isFavourite('r1'), isTrue);
    expect(c.read(savedProvider).isFavourite('r2'), isTrue);
    n.toggleFavourite('r1');
    expect(c.read(savedProvider).isFavourite('r1'), isFalse);
    expect(c.read(savedProvider).favourites, {'r2'});
    expect(c.read(savedProvider).bookmarks, isEmpty);
  });

  test('saved items survive a new container on the same store', () {
    final store = InMemoryKeyValueStore();
    final n = containerOn(store).read(savedProvider.notifier);
    n.toggleBookmark('r1', 's02');
    n.toggleBookmark('r1', 's03');
    n.toggleFavourite('r1');

    final s = containerOn(store).read(savedProvider);
    expect(marks(s), ['r1/s03', 'r1/s02']);
    expect(s.favourites, {'r1'});
    expect(store.read('namo.saved.v1'), isNotNull);
  });

  test('damaged saved items give the empty state', () {
    for (final text in [
      'not json',
      '"text"',
      '{"bookmarks": 3, "favourites": {"a": 1}}',
    ]) {
      final store = InMemoryKeyValueStore()..write('namo.saved.v1', text);
      final s = containerOn(store).read(savedProvider);
      expect(s.bookmarks, isEmpty, reason: text);
      expect(s.favourites, isEmpty, reason: text);
    }
  });

  test('bad entries are dropped and good ones kept', () {
    final store = InMemoryKeyValueStore()
      ..write(
        'namo.saved.v1',
        jsonEncode({
          'bookmarks': [
            {'readingId': 'r1', 'sectionId': 's02'},
            'broken',
            {'readingId': 'r1'},
            {'readingId': 4, 'sectionId': 's01'},
            {'readingId': 'r1', 'sectionId': 's01'},
          ],
          'favourites': ['r1', 7, null, 'r2'],
        }),
      );
    final s = containerOn(store).read(savedProvider);
    expect(marks(s), ['r1/s02', 'r1/s01']);
    expect(s.favourites, {'r1', 'r2'});
  });
}
