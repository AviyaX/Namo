import 'dart:async';

import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/recording_location.dart';
import 'package:buddhist_gatha/audio/recording_store.dart';
import 'package:buddhist_gatha/audio/recording_store_provider.dart';
import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_recording_store.dart';
import '../support/test_content.dart';

class _NeverLoads implements ContentRepository {
  @override
  Future<Library> load() => Completer<Library>().future;
}

Reading _reading(String id, {RecordingInfo? audio}) => Reading(
  id: id,
  title: id,
  sections: const [],
  audio: audio,
);

RecordingInfo _info(String path) =>
    RecordingInfo(path: path, bytes: 10, sha256: 'x', label: 'l');

void main() {
  test('while the library loads the store is empty', () {
    final container = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(_NeverLoads()),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(recordingStoreProvider), isA<EmptyRecordingStore>());
  });

  test('ContentAudioCatalogue.recordings lists every reading with audio in '
      'library order', () {
    final first = testLibrary().categories.single;
    final library = Library(
      categories: [
        first,
        Category(
          id: 'c2',
          title: 'category 2',
          subtitle: 'subtitle 2',
          readings: [
            _reading('r2', audio: _info('audio/two.mp3')),
            _reading('r3'),
            _reading('r4', audio: _info('audio/four.mp3')),
          ],
        ),
      ],
    );
    final recordings = ContentAudioCatalogue(library).recordings;
    expect(recordings.map((r) => r.path), ['audio/two.mp3', 'audio/four.mp3']);
  });

  test('the fake store gives a file for a downloaded recording, nothing for '
      'a waiting one and the asset for the placeholder', () {
    const downloaded = Recording(
      readingId: 'a',
      path: 'audio/a.mp3',
      label: 'a',
      placeholder: false,
    );
    const waiting = Recording(
      readingId: 'b',
      path: 'audio/b.mp3',
      label: 'b',
      placeholder: false,
    );
    const tone = Recording(
      readingId: 'c',
      path: placeholderToneAsset,
      label: placeholderToneLabel,
      placeholder: true,
    );
    final store = FakeRecordingStore(everything: Availability.waiting)
      ..set(
        'a',
        const RecordingStatus(availability: Availability.downloaded, bytes: 1),
      )
      ..set(
        'b',
        const RecordingStatus(availability: Availability.waiting, bytes: 1),
      );
    expect(store.locationFor(downloaded), const FileLocation('/fake/audio/a.mp3'));
    expect(store.locationFor(waiting), isNull);
    expect(store.locationFor(tone), const AssetLocation(placeholderToneAsset));
  });
}
