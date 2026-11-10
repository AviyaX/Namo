import 'dart:convert';

import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reader_items.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

HeadingItem h(String sectionId) => HeadingItem(
  Section(id: sectionId, number: 1, heading: 'heading', verses: const []),
  const [],
);

VerseTextItem v(String verseId, ReadingLanguage language) => VerseTextItem(
  sectionId: verseId.split('-').first,
  verseId: verseId,
  language: language,
  text: 'text',
  secondary: language != ReadingLanguage.pali,
);

const pi = ReadingLanguage.pali, si = ReadingLanguage.sinhala;

({double top, double height}) e(double top, double height) =>
    (top: top, height: height);

ProviderContainer containerOn(KeyValueStore store) {
  final c = ProviderContainer(
    overrides: [keyValueStoreProvider.overrideWithValue(store)],
  );
  addTearDown(c.dispose);
  return c;
}

const _position = ReadingPosition(
  readingId: 'r1',
  sectionId: 's02',
  verseId: 's02-v1',
  fraction: 0.25,
);

void main() {
  group('capture and restore', () {
    final items = [h('s01'), v('s01-v1', pi), v('s01-v1', si)];

    test('captures the item at the top and the fraction into it', () {
      final p = capturePosition(
        readingId: 'r1',
        items: items,
        extents: [e(0, 40), e(40, 100), e(140, 60)],
        scrollOffset: 90,
      )!;
      expect(p.readingId, 'r1');
      expect(p.sectionId, 's01');
      expect(p.verseId, 's01-v1');
      expect(p.fraction, 0.5);

      final top = capturePosition(
        readingId: 'r1',
        items: items,
        extents: [e(0, 40), e(40, 100), e(140, 60)],
        scrollOffset: 0,
      )!;
      expect(top.sectionId, 's01');
      expect(top.verseId, isNull);
      expect(top.fraction, 0);
    });

    test('nothing is captured before the items are laid out', () {
      expect(
        capturePosition(
          readingId: 'r1',
          items: items,
          extents: const [],
          scrollOffset: 0,
        ),
        isNull,
      );
      expect(
        capturePosition(
          readingId: 'r1',
          items: items,
          extents: [e(0, 40)],
          scrollOffset: 0,
        ),
        isNull,
      );
    });

    test('restores to the same verse after its height changes', () {
      const p = ReadingPosition(
        readingId: 'r1',
        sectionId: 's01',
        verseId: 's01-v1',
        fraction: 0.5,
      );
      expect(
        offsetForPosition(
          position: p,
          items: items,
          extents: [e(0, 40), e(40, 200), e(240, 60)],
          maxScrollExtent: 1000,
        ),
        140,
      );
    });

    test('restores to the verse when the layout moved it', () {
      // Section layout: all Pali first, then all Sinhala.
      final sectionLayout = [
        h('s01'),
        v('s01-v1', pi),
        v('s01-v2', pi),
        v('s01-v1', si),
        v('s01-v2', si),
      ];
      final extents = [e(0, 40), e(40, 50), e(90, 50), e(140, 50), e(190, 50)];
      const p = ReadingPosition(
        readingId: 'r1',
        sectionId: 's01',
        verseId: 's01-v2',
        fraction: 0.2,
      );
      expect(
        offsetForPosition(
          position: p,
          items: sectionLayout,
          extents: extents,
          maxScrollExtent: 1000,
        ),
        100,
      );
    });

    test('a verse with nothing to show falls back to its section heading', () {
      final items = [h('s01'), v('s01-v1', pi), h('s02')];
      const p = ReadingPosition(
        readingId: 'r1',
        sectionId: 's02',
        verseId: 's02-v1',
        fraction: 0.7,
      );
      expect(
        offsetForPosition(
          position: p,
          items: items,
          extents: [e(0, 40), e(40, 100), e(140, 40)],
          maxScrollExtent: 1000,
        ),
        140,
      );
    });

    test(
      'an unknown section restores to 0; results are clamped to the page',
      () {
        final extents = [e(0, 40), e(40, 100), e(140, 60)];
        expect(
          offsetForPosition(
            position: const ReadingPosition(
              readingId: 'r1',
              sectionId: 'nope',
              verseId: 'nope-v1',
              fraction: 0.5,
            ),
            items: items,
            extents: extents,
            maxScrollExtent: 1000,
          ),
          0,
        );
        const p = ReadingPosition(
          readingId: 'r1',
          sectionId: 's01',
          verseId: 's01-v1',
          fraction: 1,
        );
        expect(
          offsetForPosition(
            position: p,
            items: items,
            extents: extents,
            maxScrollExtent: 100,
          ),
          100,
        );
        expect(
          offsetForPosition(
            position: p,
            items: items,
            extents: extents,
            maxScrollExtent: 0,
          ),
          0,
        );
      },
    );

    test('progress is 0 on a page that does not scroll', () {
      expect(progressOf(0, 0), 0);
      expect(progressOf(40, -1), 0);
      expect(progressOf(50, 100), 0.5);
      expect(progressOf(150, 100), 1);
      expect(progressOf(-5, 100), 0);
    });
  });

  group('ReadingPosition JSON', () {
    test('round trips', () {
      final back = ReadingPosition.fromJson(
        jsonDecode(jsonEncode(_position.toJson())),
      )!;
      expect(back.readingId, 'r1');
      expect(back.sectionId, 's02');
      expect(back.verseId, 's02-v1');
      expect(back.fraction, 0.25);

      const heading = ReadingPosition(
        readingId: 'r1',
        sectionId: 's02',
        fraction: 0,
      );
      expect(ReadingPosition.fromJson(heading.toJson())!.verseId, isNull);
    });

    test('damaged values give null or fall back', () {
      expect(ReadingPosition.fromJson(null), isNull);
      expect(ReadingPosition.fromJson('text'), isNull);
      expect(ReadingPosition.fromJson({'sectionId': 's01'}), isNull);
      expect(
        ReadingPosition.fromJson({'readingId': 'r1', 'sectionId': 3}),
        isNull,
      );
      final p = ReadingPosition.fromJson({
        'readingId': 'r1',
        'sectionId': 's01',
        'verseId': 7,
        'fraction': 'half',
      })!;
      expect(p.verseId, isNull);
      expect(p.fraction, 0);
      expect(
        ReadingPosition.fromJson({
          'readingId': 'r1',
          'sectionId': 's01',
          'fraction': 4,
        })!.fraction,
        1,
      );
    });
  });

  group('PositionController', () {
    test('saves per reading and remembers the last one', () {
      final store = InMemoryKeyValueStore();
      final c = containerOn(store);
      expect(c.read(positionProvider).byReading, isEmpty);
      expect(c.read(positionProvider).lastReadingId, isNull);

      c.read(positionProvider.notifier).save(_position, 0.4);
      const other = ReadingPosition(
        readingId: 'r2',
        sectionId: 's01',
        fraction: 0,
      );
      c.read(positionProvider.notifier).save(other, 0);
      final s = c.read(positionProvider);
      expect(s.byReading.keys, unorderedEquals(['r1', 'r2']));
      expect(s.byReading['r1']!.position.verseId, 's02-v1');
      expect(s.byReading['r1']!.progress, 0.4);
      expect(s.lastReadingId, 'r2');
      expect(store.read('namo.position.v1'), isNotNull);
    });

    test('positions survive a new container on the same store', () {
      final store = InMemoryKeyValueStore();
      containerOn(store).read(positionProvider.notifier).save(_position, 0.4);
      final s = containerOn(store).read(positionProvider);
      expect(s.lastReadingId, 'r1');
      final r1 = s.byReading['r1']!;
      expect(r1.position.sectionId, 's02');
      expect(r1.position.verseId, 's02-v1');
      expect(r1.position.fraction, 0.25);
      expect(r1.progress, 0.4);
    });

    test('clear forgets one reading', () {
      final store = InMemoryKeyValueStore();
      final c = containerOn(store);
      final n = c.read(positionProvider.notifier);
      n.save(
        const ReadingPosition(readingId: 'r2', sectionId: 's01', fraction: 0),
        0,
      );
      n.save(_position, 0.4);
      n.clear('r1');
      expect(c.read(positionProvider).byReading.keys, ['r2']);
      expect(c.read(positionProvider).lastReadingId, isNull);
      n.clear('r2');
      expect(containerOn(store).read(positionProvider).byReading, isEmpty);
    });

    test('damaged saved positions give the empty state', () {
      for (final text in [
        'not json',
        '[1, 2]',
        '{"byReading": 3, "lastReadingId": 4}',
      ]) {
        final store = InMemoryKeyValueStore()..write('namo.position.v1', text);
        final s = containerOn(store).read(positionProvider);
        expect(s.byReading, isEmpty, reason: text);
        expect(s.lastReadingId, isNull, reason: text);
      }
    });

    test('bad entries are dropped and good ones kept', () {
      final good = ReadingProgress(position: _position, progress: 0.4);
      final store = InMemoryKeyValueStore()
        ..write(
          'namo.position.v1',
          jsonEncode({
            'byReading': {
              'r1': good.toJson(),
              'r2': 'broken',
              'r3': {'position': 5, 'progress': 0.1},
              'r4': {
                'position': {'readingId': 'r9', 'sectionId': 's01'},
                'progress': 0.1,
              },
              'r5': {
                'position': {'readingId': 'r5', 'sectionId': 's01'},
                'progress': 'far',
              },
            },
            'lastReadingId': 'r1',
          }),
        );
      final s = containerOn(store).read(positionProvider);
      expect(s.byReading.keys, unorderedEquals(['r1', 'r5']));
      expect(s.byReading['r1']!.progress, 0.4);
      expect(s.byReading['r5']!.progress, 0);
      expect(s.lastReadingId, 'r1');
    });
  });
}
