import 'package:flutter/foundation.dart';

import 'audio_catalogue.dart';
import 'audio_host.dart';
import 'recording_location.dart';

/// Where a recording is, as the reader sees it.
enum Availability { downloaded, downloading, waiting, failed, notDownloaded }

/// The state of one recording.
class RecordingStatus {
  const RecordingStatus({
    required this.availability,
    this.progress = 0,
    this.reason,
    required this.bytes,
  });

  final Availability availability;

  /// From 0 to 1 while downloading.
  final double progress;

  /// Why it failed, in words for the reader.
  final String? reason;

  /// The size of the whole recording.
  final int bytes;

  @override
  bool operator ==(Object other) =>
      other is RecordingStatus &&
      other.availability == availability &&
      other.progress == progress &&
      other.reason == reason &&
      other.bytes == bytes;

  @override
  int get hashCode => Object.hash(availability, progress, reason, bytes);

  @override
  String toString() =>
      'RecordingStatus($availability, $progress, $reason, $bytes)';
}

/// Every recording's state at one moment, by reading id, in library order.
class RecordingsSnapshot {
  const RecordingsSnapshot(this.statuses);

  static const empty = RecordingsSnapshot({});

  final Map<String, RecordingStatus> statuses;

  RecordingStatus? of(String readingId) => statuses[readingId];

  int get total => statuses.length;
  int get downloaded => _count(Availability.downloaded);
  int get failed => _count(Availability.failed);

  /// Downloading or waiting.
  int get active =>
      _count(Availability.downloading) + _count(Availability.waiting);

  int get bytesTotal => statuses.values.fold(0, (sum, s) => sum + s.bytes);

  /// Downloaded bytes, plus the part of each download under way.
  int get bytesDownloaded => statuses.values.fold(
    0,
    (sum, s) => switch (s.availability) {
      Availability.downloaded => sum + s.bytes,
      Availability.downloading => sum + (s.progress * s.bytes).round(),
      _ => sum,
    },
  );

  bool get anyDownloading => _count(Availability.downloading) > 0;
  bool get allDownloaded => total > 0 && downloaded == total;

  int _count(Availability a) =>
      statuses.values.where((s) => s.availability == a).length;

  @override
  bool operator ==(Object other) =>
      other is RecordingsSnapshot && mapEquals(other.statuses, statuses);

  @override
  int get hashCode => Object.hashAllUnordered(
    statuses.entries.map((e) => Object.hash(e.key, e.value)),
  );

  @override
  String toString() => 'RecordingsSnapshot($statuses)';
}

const damagedMessage =
    'The downloaded recording was damaged. It will be fetched again.';
const notOnServerMessage = 'This recording is not on the server yet.';
const connectionMessage =
    'Could not download the recording. Check your connection.';
const unavailableMessage = 'Downloads are not available on this device.';

/// Decimal megabytes: one decimal under 10 MB ("1.0 MB"), whole from 10 MB.
String formatSize(int bytes) {
  final mb = bytes / 1000000;
  return mb < 10 ? '${mb.toStringAsFixed(1)} MB' : '${mb.round()} MB';
}

/// Saved JSON object: recording path → the SHA-256 its file was checked
/// against.
const verifiedKey = 'namo.recordings.verified.v1';

/// Keeps the recordings on the device and tells the player where they are.
abstract interface class RecordingStore {
  ValueListenable<RecordingsSnapshot> get snapshot;

  /// Null when [r] is not on the device yet.
  RecordingLocation? locationFor(Recording r);

  /// Fetches [r] now, on any connection.
  Future<void> download(Recording r);

  /// Fetches every missing recording now, on any connection.
  Future<void> downloadAll();

  Future<void> removeAll();
}

/// No recordings at all (before the library is loaded).
class EmptyRecordingStore implements RecordingStore {
  EmptyRecordingStore();

  final _snapshot = ValueNotifier(RecordingsSnapshot.empty);

  @override
  ValueListenable<RecordingsSnapshot> get snapshot => _snapshot;

  @override
  RecordingLocation? locationFor(Recording r) =>
      r.placeholder ? AssetLocation(r.path) : null;

  @override
  Future<void> download(Recording r) async {}

  @override
  Future<void> downloadAll() async {}

  @override
  Future<void> removeAll() async {}
}

/// The browser: nothing is kept, every recording plays from the host.
class WebRecordingStore implements RecordingStore {
  WebRecordingStore(List<Recording> recordings, {this._urlOf = recordingUrl})
    : _snapshot = ValueNotifier(
        RecordingsSnapshot({
          for (final r in recordings)
            r.readingId: RecordingStatus(
              availability: Availability.downloaded,
              bytes: r.bytes,
            ),
        }),
      );

  final Uri Function(Recording) _urlOf;
  final ValueNotifier<RecordingsSnapshot> _snapshot;

  @override
  ValueListenable<RecordingsSnapshot> get snapshot => _snapshot;

  @override
  RecordingLocation? locationFor(Recording r) =>
      r.placeholder ? AssetLocation(r.path) : UrlLocation(_urlOf(r));

  @override
  Future<void> download(Recording r) async {}

  @override
  Future<void> downloadAll() async {}

  @override
  Future<void> removeAll() async {}
}
