import 'dart:convert';

import 'package:buddhist_gatha/books/book_model.dart';
import 'package:buddhist_gatha/books/book_places.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'books_support.dart';

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

  test('the page key is saved beside n, and read with or without it', () {
    final store = InMemoryKeyValueStore();
    final c = _on(store);
    final places = c.read(bookPlacesProvider.notifier);
    places.remember('a', n: 3, key: '1-1', offset: 5);
    places.remember('b', n: 2, offset: 1);
    expect(jsonDecode(store.read(bookPlacesKey)!), {
      'a': {'n': 3, 'key': '1-1', 'offset': 5.0},
      'b': {'n': 2, 'offset': 1.0},
    });
    final again = _on(store).read(bookPlacesProvider);
    expect(again.of('a')!.key, '1-1');
    expect(again.of('b')!.key, isNull);

    // An entry saved before the key was kept, and a key that is not text.
    final old = BookPlaces.fromJson({
      'old': {'n': 4, 'offset': 2},
      'odd': {'n': 4, 'key': 7, 'offset': 2},
    });
    expect(old.of('old')!.n, 4);
    expect(old.of('old')!.key, isNull);
    expect(old.of('odd')!.key, isNull);
    expect(old.of('old')!.toJson(), {'n': 4, 'offset': 2.0});
  });

  test('a place is the page with its key, else its n', () {
    final book = Book.parse(tinyBookNested());
    // Key "1-2" is page 4; the saved n 3 is another page now.
    expect(const BookPlace(n: 3, key: '1-2', offset: 0).pageIn(book), 4);
    expect(const BookPlace(n: 3, offset: 0).pageIn(book), 3);
    expect(const BookPlace(n: 3, key: 'gone', offset: 0).pageIn(book), 3);
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

  test('a place with a spot round-trips', () {
    final p = BookPlaces.fromJson({
      'b': {
        'n': 3,
        'key': '1-2',
        'offset': 10.0,
        'spot': [2, 140],
      },
    });
    expect(p.of('b')!.spot, const BookSpot(2, 140));
    expect(
      BookPlaces.fromJson(p.toJson()).of('b')!.spot,
      const BookSpot(2, 140),
    );
  });

  test('an old place without a spot still reads', () {
    expect(
      BookPlaces.fromJson({
        'b': {'n': 3, 'offset': 10},
      }).of('b')!.spot,
      isNull,
    );
  });

  test('a damaged spot is dropped alone', () {
    for (final bad in <Object>[
      ['x', -1],
      [-2, 0],
      [0, -1],
      [1],
      'nope',
    ]) {
      final p = BookPlaces.fromJson({
        'b': {'n': 3, 'offset': 0, 'spot': bad},
      });
      expect(p.of('b')!.n, 3);
      expect(p.of('b')!.spot, isNull);
    }
  });

  test('the title spot is allowed and spots order by block then char', () {
    final p = BookPlaces.fromJson({
      'b': {
        'n': 1,
        'offset': 0,
        'spot': [-1, 0],
      },
    });
    expect(p.of('b')!.spot, BookSpot.title);
    expect(BookSpot.title.compareTo(BookSpot.start), lessThan(0));
    expect(const BookSpot(1, 5).compareTo(const BookSpot(1, 9)), lessThan(0));
    expect(
      const BookSpot(2, 0).compareTo(const BookSpot(1, 9)),
      greaterThan(0),
    );
    final char = int.parse('5');
    expect(const BookSpot(1, 5).hashCode, BookSpot(1, char).hashCode);
    expect(const BookSpot(1, 5), BookSpot(1, char));
  });

  test('remember keeps the spot', () {
    final c = _on(InMemoryKeyValueStore());
    c
        .read(bookPlacesProvider.notifier)
        .remember('b', n: 2, offset: 0, spot: const BookSpot(3, 7));
    expect(c.read(bookPlacesProvider).of('b')!.spot, const BookSpot(3, 7));
  });
}
