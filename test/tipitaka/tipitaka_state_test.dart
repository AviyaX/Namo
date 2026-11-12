import 'dart:convert';

import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_state.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_tree.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tipitaka_support.dart';

ProviderContainer _on(KeyValueStore store) {
  final c = ProviderContainer(
    overrides: [keyValueStoreProvider.overrideWithValue(store)],
  );
  addTearDown(c.dispose);
  return c;
}

class _ThrowingStore extends InMemoryKeyValueStore {
  @override
  Future<void> write(String key, String value) =>
      throw StateError('disk full');
}

void main() {
  group('places', () {
    test('remember then read back after a new container on the same store',
        () {
      final store = InMemoryKeyValueStore();
      _on(store)
          .read(tipitakaPlacesProvider.notifier)
          .remember('vp-1-1', entry: 4, fraction: 0.25);
      final p = _on(store).read(tipitakaPlacesProvider).of('vp-1-1')!;
      expect(p.entry, 4);
      expect(p.fraction, 0.25);
      expect(_on(store).read(tipitakaPlacesProvider).of('zz'), isNull);
    });

    test('recent is newest first', () {
      final c = _on(InMemoryKeyValueStore());
      final n = c.read(tipitakaPlacesProvider.notifier);
      n.remember('a', entry: 0, fraction: 0);
      n.remember('b', entry: 0, fraction: 0);
      n.remember('c', entry: 0, fraction: 0);
      expect(
        c.read(tipitakaPlacesProvider).recent.map((p) => p.key),
        ['c', 'b', 'a'],
      );
    });

    test('remember after the container is gone does nothing', () {
      final store = InMemoryKeyValueStore();
      final c = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      final n = c.read(tipitakaPlacesProvider.notifier);
      c.dispose();
      n.remember('a', entry: 1, fraction: 0.5);
      expect(store.read(tipitakaPlacesKey), isNull);
    });

    test('the 201st place drops the oldest', () {
      final store = InMemoryKeyValueStore();
      final c = _on(store);
      final n = c.read(tipitakaPlacesProvider.notifier);
      for (var i = 0; i < 201; i++) {
        n.remember('k$i', entry: i, fraction: 0);
      }
      final places = c.read(tipitakaPlacesProvider);
      expect(places.recent.length, TipitakaPlaces.keep);
      expect(places.of('k0'), isNull);
      expect(places.of('k1'), isNotNull);
      expect(places.recent.first.key, 'k200');
      expect(_on(store).read(tipitakaPlacesProvider).recent.length, 200);
    });

    test('remembering a key again moves it to the front and keeps one copy',
        () {
      final c = _on(InMemoryKeyValueStore());
      final n = c.read(tipitakaPlacesProvider.notifier);
      n.remember('a', entry: 1, fraction: 0.1);
      n.remember('b', entry: 0, fraction: 0);
      n.remember('a', entry: 7, fraction: 0.9);
      final recent = c.read(tipitakaPlacesProvider).recent;
      expect(recent.map((p) => p.key), ['a', 'b']);
      expect(recent.first.entry, 7);
    });

    test('fraction and entry are clamped', () {
      final c = _on(InMemoryKeyValueStore());
      final n = c.read(tipitakaPlacesProvider.notifier);
      n.remember('a', entry: -5, fraction: 3);
      n.remember('b', entry: 2, fraction: -1);
      n.remember('c', entry: 2, fraction: double.nan);
      final p = c.read(tipitakaPlacesProvider);
      expect(p.of('a')!.entry, 0);
      expect(p.of('a')!.fraction, 1.0);
      expect(p.of('b')!.fraction, 0.0);
      expect(p.of('c')!.fraction, 0.0);
    });

    test('drop removes the given keys', () {
      final store = InMemoryKeyValueStore();
      final c = _on(store);
      final n = c.read(tipitakaPlacesProvider.notifier);
      n.remember('a', entry: 0, fraction: 0);
      n.remember('b', entry: 0, fraction: 0);
      n.drop(['a', 'nope']);
      expect(c.read(tipitakaPlacesProvider).recent.map((p) => p.key), ['b']);
      expect(_on(store).read(tipitakaPlacesProvider).of('a'), isNull);
    });

    test('a store whose write throws does not break remember', () {
      final c = _on(_ThrowingStore());
      c
          .read(tipitakaPlacesProvider.notifier)
          .remember('a', entry: 1, fraction: 0.5);
      expect(c.read(tipitakaPlacesProvider).of('a')!.entry, 1);
    });

    const damaged = {
      'not JSON': '{oops',
      'JSON of the wrong shape': '{"a":1}',
      'items with wrong types': '[1,"x",{"key":3,"entry":"a"},null]',
    };
    for (final e in damaged.entries) {
      test('${e.key} gives empty places and the next write works', () async {
        final store = InMemoryKeyValueStore();
        await store.write(tipitakaPlacesKey, e.value);
        final c = _on(store);
        expect(c.read(tipitakaPlacesProvider).recent, isEmpty);
        c
            .read(tipitakaPlacesProvider.notifier)
            .remember('a', entry: 1, fraction: 0.5);
        expect(_on(store).read(tipitakaPlacesProvider).of('a'), isNotNull);
      });
    }

    test('a non-finite number drops that item and nothing throws', () async {
      final store = InMemoryKeyValueStore();
      await store.write(
        tipitakaPlacesKey,
        '[{"key":"x","entry":1e999,"fraction":0.5,"order":2},'
        '{"key":"a","entry":1,"fraction":0.5,"order":1}]',
      );
      expect(
        _on(store).read(tipitakaPlacesProvider).recent.map((p) => p.key),
        ['a'],
      );
    });

    test('one bad item is dropped alone', () async {
      final store = InMemoryKeyValueStore();
      await store.write(
        tipitakaPlacesKey,
        jsonEncode([
          {'key': 'a', 'entry': 1, 'fraction': 0.5, 'order': 1},
          {'key': 7},
        ]),
      );
      expect(
        _on(store).read(tipitakaPlacesProvider).recent.map((p) => p.key),
        ['a'],
      );
    });
  });

  group('bookmarks', () {
    test('toggle adds at the front, toggle again removes', () {
      final store = InMemoryKeyValueStore();
      final c = _on(store);
      final n = c.read(tipitakaSavedProvider.notifier);
      n.toggle('a');
      n.toggle('b');
      expect(c.read(tipitakaSavedProvider), ['b', 'a']);
      expect(_on(store).read(tipitakaSavedProvider), ['b', 'a']);
      n.toggle('b');
      expect(c.read(tipitakaSavedProvider), ['a']);
    });

    test('drop removes the given keys', () {
      final c = _on(InMemoryKeyValueStore());
      final n = c.read(tipitakaSavedProvider.notifier);
      n.toggle('a');
      n.toggle('b');
      n.drop(['a']);
      expect(c.read(tipitakaSavedProvider), ['b']);
    });

    test('a store whose write throws does not break toggle', () {
      final c = _on(_ThrowingStore());
      c.read(tipitakaSavedProvider.notifier).toggle('a');
      expect(c.read(tipitakaSavedProvider), ['a']);
    });

    const damaged = {
      'not JSON': 'nope[',
      'JSON of the wrong shape': '{"a":1}',
      'items with wrong types': '[1,null,{"x":1}]',
    };
    for (final e in damaged.entries) {
      test('${e.key} gives empty bookmarks and the next write works',
          () async {
        final store = InMemoryKeyValueStore();
        await store.write(tipitakaSavedKey, e.value);
        final c = _on(store);
        expect(c.read(tipitakaSavedProvider), isEmpty);
        c.read(tipitakaSavedProvider.notifier).toggle('a');
        expect(_on(store).read(tipitakaSavedProvider), ['a']);
      });
    }
  });

  group('view', () {
    test('view is null at first, chosen value survives a restart', () {
      final store = InMemoryKeyValueStore();
      final c = _on(store);
      expect(c.read(tipitakaViewProvider), isNull);
      c.read(tipitakaViewProvider.notifier).choose(TipitakaView.both);
      expect(c.read(tipitakaViewProvider), TipitakaView.both);
      expect(_on(store).read(tipitakaViewProvider), TipitakaView.both);
    });

    const damaged = {
      'not JSON': '{{',
      'JSON of the wrong shape': '[1,2]',
      'an unknown view name': '"unknown-view"',
      'a number': '5',
    };
    for (final e in damaged.entries) {
      test('${e.key} gives null and the next write works', () async {
        final store = InMemoryKeyValueStore();
        await store.write(tipitakaViewKey, e.value);
        final c = _on(store);
        expect(c.read(tipitakaViewProvider), isNull);
        c.read(tipitakaViewProvider.notifier).choose(TipitakaView.pali);
        expect(_on(store).read(tipitakaViewProvider), TipitakaView.pali);
      });
    }

    test('a store whose write throws does not break choose', () {
      final c = _on(_ThrowingStore());
      c.read(tipitakaViewProvider.notifier).choose(TipitakaView.sinhala);
      expect(c.read(tipitakaViewProvider), TipitakaView.sinhala);
    });

    test('default view depends on width', () {
      expect(defaultTipitakaView(wide: true), TipitakaView.both);
      expect(defaultTipitakaView(wide: false), TipitakaView.sinhala);
    });
  });

  test('prune drops places and bookmarks not in the tree and keeps the rest',
      () {
    final tree =
        TipitakaTree.parse(tinyTree(), parentsWithText: tinyParentsWithText);
    final store = InMemoryKeyValueStore();
    final c = _on(store);
    final places = c.read(tipitakaPlacesProvider.notifier);
    places.remember('vp-1-1', entry: 0, fraction: 0);
    places.remember('gone', entry: 0, fraction: 0);
    places.remember('vp-1', entry: 0, fraction: 0); // a parent with no text
    final saved = c.read(tipitakaSavedProvider.notifier);
    saved.toggle('sp-1');
    saved.toggle('gone');
    pruneTipitakaStateIn(c, tree);
    expect(
      c.read(tipitakaPlacesProvider).recent.map((p) => p.key),
      ['vp-1-1'],
    );
    expect(c.read(tipitakaSavedProvider), ['sp-1']);
    expect(_on(store).read(tipitakaSavedProvider), ['sp-1']);
  });
}
