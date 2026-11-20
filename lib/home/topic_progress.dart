import '../content/model.dart';
import '../reader/position_controller.dart';

/// A reading of a topic that can be picked up again, and how far through it
/// the person is (0–1, as stored).
class TopicResume {
  const TopicResume({required this.reading, required this.progress});

  final Reading reading;
  final double progress;

  @override
  bool operator ==(Object other) =>
      other is TopicResume &&
      other.reading.id == reading.id &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(reading.id, progress);
}

/// What there is to pick up again in [c], from what is remembered only.
///
/// A topic with one reading: that reading, when it has a remembered place.
/// A topic with several: the last-read reading, when it is one of them and
/// has a remembered place. Otherwise (and for a stale id) null.
TopicResume? topicResume(Category c, PositionState s) {
  final Reading? reading;
  if (c.readings.length == 1) {
    reading = c.readings.single;
  } else {
    final last = s.lastReadingId;
    reading = last == null
        ? null
        : c.readings.where((r) => r.id == last).firstOrNull;
  }
  if (reading == null) return null;
  final remembered = s.byReading[reading.id];
  if (remembered == null) return null;
  return TopicResume(reading: reading, progress: remembered.progress);
}

/// What the featured card for a topic does.
enum FeaturedAction {
  /// Opens the reading of [topicResume] at its remembered place.
  continueReading,

  /// Opens the topic's one reading from the start.
  begin,

  /// Opens the topic in the Library.
  open,

  /// Nothing: the topic has no readings.
  none,
}

FeaturedAction featuredAction(Category c, PositionState s) {
  if (c.readings.isEmpty) return FeaturedAction.none;
  if (topicResume(c, s) != null) return FeaturedAction.continueReading;
  return c.readings.length == 1 ? FeaturedAction.begin : FeaturedAction.open;
}

/// The index in [l] of the topic that holds the last-read reading, else 0.
int startTopicIndex(Library l, PositionState s) {
  final last = s.lastReadingId;
  if (last == null) return 0;
  final i = l.categories.indexWhere((c) => c.readings.any((r) => r.id == last));
  return i < 0 ? 0 : i;
}
