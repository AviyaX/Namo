import 'dart:convert';

import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/flows/flows.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
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

FlowRef ref(String s) => FlowRef(readingId: 'r', sectionId: s);

List<String> secs(ProviderContainer c, String id) => [
  for (final r in c.read(flowsProvider).flow(id)!.sections) r.sectionId,
];

Reading reading() => Reading(
  id: 'rd',
  title: 'T',
  sections: [
    for (final s in ['a', 'b', 'c']) Section(id: s, number: 1, heading: s),
  ],
);

Map<String, Object?> flowJson(String id, [List<Object?>? sections]) => {
  'id': id,
  'name': 'N $id',
  'sections': sections ?? [],
};

ProviderContainer loaded(Object? data) {
  final store = InMemoryKeyValueStore();
  store.save(flowsKey, data is String ? data : jsonEncode(data));
  return containerOn(store);
}

void main() {
  test('flowName', () {
    expect(flowName('  Morning  ', []), 'Morning');
    expect(flowName('', []), 'My flow');
    expect(flowName('   ', []), 'My flow');
    expect(flowName('', ['My flow']), 'My flow 2');
    expect(flowName('', ['My flow', 'My flow 2']), 'My flow 3');
    expect(flowName('x' * 500, []).length, 40);
    expect(flowName('a\nb', []), 'a b');
    expect(flowName('${'x' * 39} yyy', []), 'x' * 39);
  });

  test('sectionCount', () {
    expect(sectionCount(0), '0 sections');
    expect(sectionCount(1), '1 section');
    expect(sectionCount(7), '7 sections');
  });

  test('isFlowId', () {
    expect(isFlowId('flow-1'), isTrue);
    expect(isFlowId('pirith'), isFalse);
  });

  test('create numbers ids and copies a reading in order', () {
    final c = containerOn(InMemoryKeyValueStore());
    final n = c.read(flowsProvider.notifier);
    final one = n.create('One');
    final two = n.create('Two', from: reading());
    expect(one.id, 'flow-1');
    expect(two.id, 'flow-2');
    expect(c.read(flowsProvider).flows, [one, two]);
    expect(c.read(flowsProvider).flow('flow-2'), same(two));
    expect(two.sections, [
      for (final s in ['a', 'b', 'c']) FlowRef(readingId: 'rd', sectionId: s),
    ]);
  });

  test('ids are never reused', () {
    final store = InMemoryKeyValueStore();
    var c = containerOn(store);
    final n = c.read(flowsProvider.notifier);
    n.create('a');
    n.create('b');
    n.delete('flow-2');
    expect(n.create('c').id, 'flow-3');
    n.delete('flow-3');
    c = containerOn(store);
    expect(c.read(flowsProvider.notifier).create('d').id, 'flow-4');
  });

  test('rename applies the name rule', () {
    final c = containerOn(InMemoryKeyValueStore());
    final n = c.read(flowsProvider.notifier);
    n.create('');
    n.create('Two');
    n.rename('flow-2', '');
    expect(c.read(flowsProvider).flow('flow-2')!.name, 'My flow 2');
    n.rename('flow-1', '');
    expect(c.read(flowsProvider).flow('flow-1')!.name, 'My flow');
    n.rename('flow-1', '  New  ');
    expect(c.read(flowsProvider).flow('flow-1')!.name, 'New');
  });

  test('add, remove, insert', () {
    final c = containerOn(InMemoryKeyValueStore());
    final n = c.read(flowsProvider.notifier);
    n.create('f');
    n.add('flow-1', ref('a'));
    n.add('flow-1', ref('b'));
    n.add('flow-1', ref('a'));
    expect(secs(c, 'flow-1'), ['a', 'b']);
    n.remove('flow-1', ref('a'));
    expect(secs(c, 'flow-1'), ['b']);
    n.insert('flow-1', 0, ref('a'));
    expect(secs(c, 'flow-1'), ['a', 'b']);
    n.insert('flow-1', 1, ref('m'));
    expect(secs(c, 'flow-1'), ['a', 'm', 'b']);
    n.insert('flow-1', 99, ref('z'));
    expect(secs(c, 'flow-1'), ['a', 'm', 'b', 'z']);
    n.insert('flow-1', 0, ref('b'));
    expect(secs(c, 'flow-1'), ['a', 'm', 'b', 'z']);
    expect(
      () => c.read(flowsProvider).flow('flow-1')!.sections.add(ref('q')),
      throwsUnsupportedError,
    );
  });

  test('move', () {
    final c = containerOn(InMemoryKeyValueStore());
    final n = c.read(flowsProvider.notifier);
    n.create('f', from: reading());
    final ref0 = FlowRef(readingId: 'rd', sectionId: 'a');
    n.move('flow-1', 0, 2);
    expect(c.read(flowsProvider).flow('flow-1')!.sections.last, ref0);
    n.move('flow-1', 2, 0);
    n.move('flow-1', 1, 1);
    n.move('flow-1', -1, 1);
    n.move('flow-1', 0, 3);
    n.move('flow-1', 3, 0);
    expect(c.read(flowsProvider).flow('flow-1')!.sections.first, ref0);
    final order = [
      for (final r in c.read(flowsProvider).flow('flow-1')!.sections)
        r.sectionId,
    ];
    expect(order, ['a', 'b', 'c']);
    n.move('flow-1', 2, 0);
    expect(
      [
        for (final r in c.read(flowsProvider).flow('flow-1')!.sections)
          r.sectionId,
      ],
      ['c', 'a', 'b'],
    );
  });

  test('unknown flow ids change nothing', () {
    final store = InMemoryKeyValueStore();
    final c = containerOn(store);
    final n = c.read(flowsProvider.notifier);
    n.create('f', from: reading());
    final before = c.read(flowsProvider);
    final saved = store.read(flowsKey);
    n.rename('nope', 'x');
    n.delete('nope');
    n.add('nope', ref('a'));
    n.remove('nope', ref('a'));
    n.insert('nope', 0, ref('a'));
    n.move('nope', 0, 1);
    expect(c.read(flowsProvider), same(before));
    expect(store.read(flowsKey), saved);
  });

  test('round trip', () {
    final store = InMemoryKeyValueStore();
    final c = containerOn(store);
    final n = c.read(flowsProvider.notifier);
    n.create('One', from: reading());
    n.create('Two');
    n.add('flow-2', ref('x'));
    n.move('flow-1', 0, 2);
    n.rename('flow-2', 'Evening');
    n.delete('flow-1');
    n.create('Three');
    final c2 = containerOn(store);
    final a = c.read(flowsProvider), b = c2.read(flowsProvider);
    expect(b.flows, a.flows);
    expect(b.nextNumber, a.nextNumber);
    expect(b.nextNumber, 4);
  });

  group('damaged data', () {
    for (final bad in ['not json', '[]', '{"flows": 5}']) {
      test(bad, () {
        final s = loaded(bad).read(flowsProvider);
        expect(s.flows, isEmpty);
        expect(s.nextNumber, 1);
      });
    }

    test('an unreadable flow is dropped alone', () {
      final s = loaded({
        'nextNumber': 5,
        'flows': [
          flowJson('flow-1'),
          7,
          {'id': 'flow-2'},
          flowJson('flow-3'),
        ],
      }).read(flowsProvider);
      expect([for (final f in s.flows) f.id], ['flow-1', 'flow-3']);
    });

    test('repeated ref keeps the first; bad ref dropped alone', () {
      final s = loaded({
        'nextNumber': 2,
        'flows': [
          flowJson('flow-1', [
            ref('a').toJson(),
            ref('b').toJson(),
            ref('a').toJson(),
            {'readingId': 'r'},
          ]),
        ],
      }).read(flowsProvider);
      expect(s.flows.single.sections, [ref('a'), ref('b')]);
    });

    test('nextNumber is raised above the highest id', () {
      final s = loaded({
        'nextNumber': 2,
        'flows': [flowJson('flow-1'), flowJson('flow-9')],
      }).read(flowsProvider);
      expect(s.nextNumber, 10);
    });

    test('odd ids drop the flow; duplicate ids keep the first', () {
      final s = loaded({
        'nextNumber': 1,
        'flows': [
          flowJson('flow-0'),
          flowJson('flow-x'),
          flowJson('flow-'),
          flowJson('other'),
          flowJson('flow-2'),
          {...flowJson('flow-2'), 'name': 'Second'},
        ],
      }).read(flowsProvider);
      expect(s.flows.length, 1);
      expect(s.flows.single.name, 'N flow-2');
    });
  });

  test('delete clears the remembered place', () {
    final c = containerOn(InMemoryKeyValueStore());
    c.read(flowsProvider.notifier).create('f');
    c
        .read(positionProvider.notifier)
        .save(
          const ReadingPosition(
            readingId: 'flow-1',
            sectionId: 'a',
            fraction: 0.5,
          ),
          0.5,
        );
    expect(c.read(positionProvider).lastReadingId, 'flow-1');
    c.read(flowsProvider.notifier).delete('flow-1');
    expect(c.read(positionProvider).byReading.containsKey('flow-1'), isFalse);
    expect(c.read(positionProvider).lastReadingId, isNull);
  });
}
