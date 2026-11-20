import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/home/topic_progress.dart';
import 'package:buddhist_gatha/reader/position_controller.dart';
import 'package:buddhist_gatha/reader/reading_position.dart';
import 'package:flutter_test/flutter_test.dart';

Reading _reading(String id) =>
    Reading(id: id, title: 'Reading $id', sections: const []);

Category _topic(String id, List<String> readingIds) => Category(
  id: id,
  title: 'Topic $id',
  subtitle: 'Subtitle $id',
  readings: [for (final r in readingIds) _reading(r)],
);

final _one = _topic('one', ['a']);
final _several = _topic('several', ['b', 'c', 'd']);
final _empty = _topic('empty', []);

/// Remembered places for [progress] (reading id -> 0–1), with [last] as the
/// last-read reading.
PositionState _state(Map<String, double> progress, {String? last}) =>
    PositionState(
      byReading: {
        for (final e in progress.entries)
          e.key: ReadingProgress(
            position: ReadingPosition(
              readingId: e.key,
              sectionId: 's01',
              fraction: 0,
            ),
            progress: e.value,
          ),
      },
      lastReadingId: last,
    );

void main() {
  group('topicResume', () {
    test('one reading: that reading when it has a remembered place', () {
      final r = topicResume(_one, _state({'a': 0.34}, last: 'a'))!;
      expect(r.reading.id, 'a');
      expect(r.progress, 0.34);
      // The last-read reading being elsewhere does not matter for one reading.
      final elsewhere = topicResume(_one, _state({'a': 0.5, 'c': 0.1}, last: 'c'))!;
      expect(elsewhere.reading.id, 'a');
      expect(elsewhere.progress, 0.5);
    });

    test('one reading without a remembered place: null', () {
      expect(topicResume(_one, const PositionState()), isNull);
      expect(topicResume(_one, _state({'c': 0.2}, last: 'c')), isNull);
    });

    test('several readings: the last-read reading when it is in the topic', () {
      final r = topicResume(_several, _state({'b': 0.9, 'c': 0.25}, last: 'c'))!;
      expect(r.reading.id, 'c');
      expect(r.progress, 0.25);
    });

    test('several readings: a place in the topic that is not the last read '
        'gives null', () {
      expect(topicResume(_several, _state({'b': 0.9, 'a': 0.1}, last: 'a')), isNull);
      expect(topicResume(_several, _state({'b': 0.9})), isNull);
    });

    test('a stale last-read id gives null', () {
      // An id no topic has, with or without an entry of its own.
      expect(topicResume(_several, _state({'gone': 0.5}, last: 'gone')), isNull);
      expect(topicResume(_several, _state({'b': 0.5}, last: 'gone')), isNull);
      // The last-read id is in the topic but has no entry.
      expect(topicResume(_several, _state({}, last: 'c')), isNull);
    });

    test('no readings: null', () {
      expect(topicResume(_empty, _state({'a': 0.5}, last: 'a')), isNull);
    });
  });

  group('featuredAction', () {
    test('all four actions', () {
      expect(featuredAction(_empty, const PositionState()), FeaturedAction.none);
      expect(featuredAction(_one, const PositionState()), FeaturedAction.begin);
      expect(featuredAction(_several, const PositionState()), FeaturedAction.open);
      expect(
        featuredAction(_one, _state({'a': 0.1}, last: 'a')),
        FeaturedAction.continueReading,
      );
      expect(
        featuredAction(_several, _state({'d': 0.7}, last: 'd')),
        FeaturedAction.continueReading,
      );
    });

    test('the last-read reading in another topic: begin or open', () {
      final elsewhere = _state({'x': 0.4}, last: 'x');
      expect(featuredAction(_one, elsewhere), FeaturedAction.begin);
      expect(featuredAction(_several, elsewhere), FeaturedAction.open);
      // Pirith-like: a place in the several-reading topic, but a reading of
      // another topic was read after it.
      expect(
        featuredAction(_several, _state({'b': 0.4, 'a': 0.2}, last: 'a')),
        FeaturedAction.open,
      );
    });

    test('a stale last-read id: begin or open, never continue', () {
      final stale = _state({'gone': 0.4}, last: 'gone');
      expect(featuredAction(_one, stale), FeaturedAction.begin);
      expect(featuredAction(_several, stale), FeaturedAction.open);
    });
  });

  group('startTopicIndex', () {
    final library = Library(
      categories: [
        _topic('t1', ['a']),
        _topic('t2', ['b', 'c']),
        _topic('t3', ['d', 'e']),
      ],
    );

    test('nothing read: the first topic', () {
      expect(startTopicIndex(library, const PositionState()), 0);
    });

    test('the topic that holds the last-read reading', () {
      expect(startTopicIndex(library, _state({'a': 0.1}, last: 'a')), 0);
      expect(startTopicIndex(library, _state({'c': 0.1}, last: 'c')), 1);
      expect(startTopicIndex(library, _state({'e': 0.1}, last: 'e')), 2);
    });

    test('a stale last-read id: the first topic', () {
      expect(startTopicIndex(library, _state({'gone': 0.1}, last: 'gone')), 0);
    });

    test('an empty library: 0', () {
      expect(
        startTopicIndex(const Library(categories: []), _state({'a': 0.1}, last: 'a')),
        0,
      );
    });
  });
}
