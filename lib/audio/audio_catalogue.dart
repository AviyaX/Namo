import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_repository.dart';
import '../content/model.dart';

/// The recording of one reading.
class Recording {
  const Recording({
    required this.readingId,
    required this.path,
    this.bytes = 0,
    this.sha256 = '',
    required this.label,
    required this.placeholder,
    this.sectionCues = const {},
    this.blockTimes = const [],
    this.lineTimes = const [],
    required this.duration,
  });

  final String readingId;

  /// Where the recording lives on the host (`audio/...`), or the asset path
  /// of the placeholder tone.
  final String path;
  final int bytes;
  final String sha256;

  /// What the listener is told this is.
  final String label;

  /// True for the development tone, which is not a chant.
  final bool placeholder;

  /// Where each section starts. Not used yet.
  final Map<String, Duration> sectionCues;

  /// When each block of the reading is chanted; null where it has no time.
  final List<BlockTime?> blockTimes;

  /// When each line of each block starts; empty when only blocks are timed.
  final List<List<Duration?>> lineTimes;

  /// How long the recording plays; zero where it is not known (the
  /// placeholder tone, or an untimed recording the content gives no length).
  final Duration duration;

  bool get timed => blockTimes.isNotEmpty;
}

/// Where the app finds the recording of a reading.
abstract interface class AudioCatalogue {
  /// Null when the reading has no recording.
  Recording? recordingFor(String readingId);
}

/// Recordings named by the content.
class ContentAudioCatalogue implements AudioCatalogue {
  ContentAudioCatalogue(Library library)
    : _byReading = {
        for (final category in library.categories)
          for (final reading in category.readings)
            if (reading.audio != null)
              reading.id: _recordingOf(reading.id, reading.audio!),
      };

  static Recording _recordingOf(String readingId, RecordingInfo info) {
    if (info.blockTimes.isNotEmpty && info.duration == null) {
      throw StateError('recording for $readingId has no duration');
    }
    return Recording(
      readingId: readingId,
      path: info.path,
      bytes: info.bytes,
      sha256: info.sha256,
      label: info.label,
      placeholder: false,
      sectionCues: info.sectionCues,
      blockTimes: info.blockTimes,
      lineTimes: info.lineTimes,
      duration: info.duration ?? Duration.zero,
    );
  }

  final Map<String, Recording> _byReading;

  /// Every reading's recording, in library order.
  List<Recording> get recordings => _byReading.values.toList();

  @override
  Recording? recordingFor(String readingId) => _byReading[readingId];
}

/// The development tone: not a chant, only for trying the controls.
const placeholderToneAsset = 'assets/audio_dev/placeholder_tone_not_a_chant.wav';
const placeholderToneLabel = 'Development placeholder tone (not a chant)';

/// [real], and the labelled tone for every reading it has nothing for.
class DevPlaceholderCatalogue implements AudioCatalogue {
  DevPlaceholderCatalogue(this.real);

  final AudioCatalogue real;

  @override
  Recording? recordingFor(String readingId) =>
      real.recordingFor(readingId) ??
      Recording(
        readingId: readingId,
        path: placeholderToneAsset,
        label: placeholderToneLabel,
        placeholder: true,
        duration: Duration.zero,
      );
}

/// The placeholder catalogue only in a debug build that asked for it.
AudioCatalogue chooseCatalogue({
  required AudioCatalogue real,
  required bool debugBuild,
  required bool devAudioFlag,
}) => debugBuild && devAudioFlag ? DevPlaceholderCatalogue(real) : real;

class _NoRecordings implements AudioCatalogue {
  const _NoRecordings();

  @override
  Recording? recordingFor(String readingId) => null;
}

final audioCatalogueProvider = Provider<AudioCatalogue>((ref) {
  final library = ref.watch(libraryProvider).value;
  return chooseCatalogue(
    real: library == null
        ? const _NoRecordings()
        : ContentAudioCatalogue(library),
    debugBuild: kDebugMode,
    devAudioFlag: const bool.fromEnvironment('NAMO_DEV_AUDIO'),
  );
});
