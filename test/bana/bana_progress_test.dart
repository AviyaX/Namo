import 'package:buddhist_gatha/bana/bana_catalogue.dart';
import 'package:buddhist_gatha/bana/bana_progress.dart';
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

Bana _bana(String id, {String? series, int? part}) => Bana(
  id: id,
  title: id,
  speaker: 's',
  channel: 'c',
  topics: const [],
  seconds: 60,
  embeddable: true,
  series: series,
  part: part,
);

void main() {
  test('progress remembers the last opened part per series across a restart', () {
    final store = InMemoryKeyValueStore();
    final c = _on(store);
    final p = c.read(banaProgressProvider.notifier);
    p.opened(_bana('a1', series: 'A', part: 1));
    p.opened(_bana('a2', series: 'A', part: 2));
    p.opened(_bana('b1', series: 'B', part: 1));
    p.opened(_bana('single'));
    expect(p.lastPart('A'), 'a2');

    final again = _on(store).read(banaProgressProvider.notifier);
    expect(again.lastPart('A'), 'a2');
    expect(again.lastPart('B'), 'b1');
    expect(again.lastPart('C'), isNull);
    expect(_on(store).read(banaProgressProvider).length, 2);
  });

  test('damaged stored progress is ignored', () {
    final store = InMemoryKeyValueStore();
    store.write(banaLastPartKey, '{oops');
    expect(_on(store).read(banaProgressProvider), isEmpty);
  });
}
