import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:buddhist_gatha/tips/tips.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer containerOn(
  KeyValueStore store, {
  bool web = false,
}) {
  final c = ProviderContainer(overrides: [
    keyValueStoreProvider.overrideWithValue(store),
    tipsProvider.overrideWith(() => TipsController(web: web)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('every tip is due at first; recordings is not due on the web', () {
    final app = containerOn(InMemoryKeyValueStore());
    for (final t in Tip.values) {
      expect(app.read(tipsProvider.notifier).isDue(t), isTrue);
    }
    final web = containerOn(InMemoryKeyValueStore(), web: true);
    final c = web.read(tipsProvider.notifier);
    expect(c.isDue(Tip.recordings), isFalse);
    expect(c.isDue(Tip.myFlows), isTrue);
  });

  test('request makes a due tip active and refuses a second one', () {
    final c = containerOn(InMemoryKeyValueStore());
    final n = c.read(tipsProvider.notifier);
    expect(n.request(Tip.myFlows), isTrue);
    expect(c.read(tipsProvider).active, Tip.myFlows);
    expect(n.request(Tip.scrollChant), isFalse);
    expect(c.read(tipsProvider).active, Tip.myFlows);
  });

  test('request refuses a tip that is not due', () {
    final c = containerOn(InMemoryKeyValueStore(), web: true);
    expect(c.read(tipsProvider.notifier).request(Tip.recordings), isFalse);
    expect(c.read(tipsProvider).active, isNull);
  });

  test('dismiss marks the active tip seen and saves it', () {
    final store = InMemoryKeyValueStore();
    final c = containerOn(store);
    final n = c.read(tipsProvider.notifier);
    n.request(Tip.myFlows);
    n.dismiss();
    expect(c.read(tipsProvider).active, isNull);
    expect(store.read(tipsKey), '{"seen":["myFlows"]}');
    final again = containerOn(store);
    expect(again.read(tipsProvider).seen, {Tip.myFlows});
    expect(again.read(tipsProvider.notifier).isDue(Tip.myFlows), isFalse);
  });

  test('withdraw clears the active tip without marking it seen', () {
    final store = InMemoryKeyValueStore();
    final c = containerOn(store);
    final n = c.read(tipsProvider.notifier);
    n.request(Tip.myFlows);
    n.withdraw(Tip.scrollChant);
    expect(c.read(tipsProvider).active, Tip.myFlows);
    n.withdraw(Tip.myFlows);
    expect(c.read(tipsProvider).active, isNull);
    expect(n.isDue(Tip.myFlows), isTrue);
    expect(store.read(tipsKey), isNull);
  });

  test('resetAll forgets everything and saves', () {
    final store = InMemoryKeyValueStore();
    final c = containerOn(store);
    final n = c.read(tipsProvider.notifier);
    n.request(Tip.myFlows);
    n.dismiss();
    n.request(Tip.readerSettings);
    n.resetAll();
    expect(c.read(tipsProvider).seen, isEmpty);
    expect(c.read(tipsProvider).active, isNull);
    expect(store.read(tipsKey), '{"seen":[]}');
    expect(containerOn(store).read(tipsProvider).seen, isEmpty);
  });

  test('garbage in the store gives an empty state', () {
    for (final junk in [
      'not json',
      '[1,2]',
      '{"seen": 3}',
      '{"seen": [1, null, "nope"]}',
    ]) {
      final store = InMemoryKeyValueStore()..save(tipsKey, junk);
      final s = containerOn(store).read(tipsProvider);
      expect(s.seen, isEmpty, reason: junk);
      expect(s.active, isNull);
    }
  });

  test('unknown names are ignored, known ones kept', () {
    final store = InMemoryKeyValueStore()
      ..save(tipsKey, '{"seen":["myFlows","gone"]}');
    expect(containerOn(store).read(tipsProvider).seen, {Tip.myFlows});
  });
}
