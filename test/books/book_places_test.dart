import 'dart:convert';

import 'package:buddhist_gatha/books/book_places.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _on(KeyValueStore store) {
  final c = ProviderContainer(
    overrides: [keyValueStoreProvider.overrideWithValue(store)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('remember saves and reads back', () {
    final store = InMemoryKeyValueStore();
    final c = _on(store);
    final places = c.read(bookPlacesProvider.notifier);
    places.remember('a', n: 3, offset: 120.5);
    places.remember('b', n: 1, offset: 0);
    places.remember('a', n: 4, offset: 10);
    expect(c.read(bookPlacesProvider).of('a')!.n, 4);

    final again = _on(store).read(bookPlacesProvider);
    expect(again.of('a')!.n, 4);
    expect(again.of('a')!.offset, 10.0);
    expect(again.of('b')!.n, 1);
    expect(again.of('zz'), isNull);
    expect(jsonDecode(store.read(bookPlacesKey)!), {
      'a': {'n': 4, 'offset': 10.0},
      'b': {'n': 1, 'offset': 0.0},
    });

    // Nothing happens once the provider is gone (a reader saving its place
    // as the whole app closes).
    final gone = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    final notifier = gone.read(bookPlacesProvider.notifier);
    gone.dispose();
    notifier.remember('c', n: 2, offset: 1);
    expect(_on(store).read(bookPlacesProvider).of('c'), isNull);
  });

  test('damaged entries are dropped alone', () {
    final store = InMemoryKeyValueStore();
    store.write(
      bookPlacesKey,
      jsonEncode({
        'good': {'n': 2, 'offset': 33.5},
        'whole': {'n': 5, 'offset': 7},
        'bad-n': {'n': 'x', 'offset': 1},
        'zero-n': {'n': 0, 'offset': 1},
        'half-n': {'n': 1.5, 'offset': 1},
        'bad-offset': {'n': 2, 'offset': 'far'},
        'missing': {'n': 2},
        'not-a-map': 4,
      }),
    );
    final places = _on(store).read(bookPlacesProvider);
    expect(places.byBook.keys.toSet(), {'good', 'whole'});
    expect(places.of('good')!.offset, 33.5);
    expect(places.of('whole')!.offset, 7.0);
  });

  test('garbage gives the empty state', () {
    for (final garbage in ['{not json', '[1,2]', '"text"', 'null']) {
      final store = InMemoryKeyValueStore()..write(bookPlacesKey, garbage);
      expect(
        _on(store).read(bookPlacesProvider).byBook,
        isEmpty,
        reason: garbage,
      );
    }
    expect(
      _on(InMemoryKeyValueStore()).read(bookPlacesProvider).byBook,
      isEmpty,
    );
    expect(BookPlaces.fromJson(null).byBook, isEmpty);
  });
}
