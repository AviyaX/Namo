import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/recording_location.dart';
import 'package:buddhist_gatha/audio/recording_store.dart';
import 'package:flutter/foundation.dart';

/// A [RecordingStore] for tests: no files, no network, and the statuses are
/// whatever the test sets.
class FakeRecordingStore implements RecordingStore {
  FakeRecordingStore({this.everything = Availability.downloaded});

  /// What a recording with no status of its own counts as.
  final Availability everything;

  @override
  final ValueNotifier<RecordingsSnapshot> snapshot =
      ValueNotifier(RecordingsSnapshot.empty);

  /// [Recording.path] of every recording passed to [download], in order.
  final downloads = <String>[];
  int downloadAllCalls = 0;
  int removeAllCalls = 0;

  /// Gives [readingId] this status; listeners are told.
  void set(String readingId, RecordingStatus status) {
    snapshot.value = RecordingsSnapshot({
      ...snapshot.value.statuses,
      readingId: status,
    });
  }

  @override
  RecordingLocation? locationFor(Recording r) {
    if (r.placeholder) return AssetLocation(r.path);
    final status = snapshot.value.of(r.readingId);
    final downloaded = status == null
        ? everything == Availability.downloaded
        : status.availability == Availability.downloaded;
    return downloaded ? FileLocation('/fake/${r.path}') : null;
  }

  @override
  Future<void> download(Recording r) async => downloads.add(r.path);

  @override
  Future<void> downloadAll() async => downloadAllCalls++;

  @override
  Future<void> removeAll() async => removeAllCalls++;
}
