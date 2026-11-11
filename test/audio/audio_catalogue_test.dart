import 'dart:convert';
import 'dart:io';

import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_content.dart';

class _Empty implements AudioCatalogue {
  @override
  Recording? recordingFor(String readingId) => null;
}

class _Real implements AudioCatalogue {
  @override
  Recording? recordingFor(String readingId) => const Recording(
        readingId: 'r1',
        asset: 'assets/audio/r1.mp3',
        label: 'Recording of r1',
        placeholder: false,
      );
}

void main() {
  test('the bundled content has no recording', () {
    final json = jsonDecode(
      File('assets/content/namaskaraya_to_pin_dima.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final library = Library.fromJson(json);
    final catalogue = ContentAudioCatalogue(library);
    expect(catalogue.recordingFor('namaskaraya'), isNull);
    for (final category in library.categories) {
      for (final reading in category.readings) {
        expect(catalogue.recordingFor(reading.id), isNull);
      }
    }
  });

  test('a recording named by the content is passed on as it is', () {
    const library = Library(categories: [
      Category(id: 'c', title: 'c', subtitle: 's', readings: [
        Reading(
          id: 'r1',
          title: 't',
          sections: [],
          audio: RecordingInfo(
            asset: 'assets/audio/r1.mp3',
            label: 'Chanted by someone',
            sectionCues: {'s01': Duration(seconds: 5)},
          ),
        ),
      ]),
    ]);
    final r = ContentAudioCatalogue(library).recordingFor('r1')!;
    expect(r.readingId, 'r1');
    expect(r.asset, 'assets/audio/r1.mp3');
    expect(r.label, 'Chanted by someone');
    expect(r.placeholder, isFalse);
    expect(r.sectionCues, {'s01': const Duration(seconds: 5)});
    expect(ContentAudioCatalogue(library).recordingFor('other'), isNull);
  });

  test('line times are passed on; a recording without them has none', () {
    const library = Library(categories: [
      Category(id: 'c', title: 'c', subtitle: 's', readings: [
        Reading(
          id: 'timed',
          title: 't',
          sections: [],
          audio: RecordingInfo(
            asset: 'a.m4a',
            label: 'L',
            lineTimes: [
              [Duration(seconds: 1), null],
            ],
          ),
        ),
        Reading(
          id: 'plain',
          title: 't',
          sections: [],
          audio: RecordingInfo(asset: 'b.m4a', label: 'L'),
        ),
      ]),
    ]);
    final catalogue = ContentAudioCatalogue(library);
    expect(catalogue.recordingFor('timed')!.lineTimes, [
      [const Duration(seconds: 1), null],
    ]);
    expect(catalogue.recordingFor('plain')!.lineTimes, isEmpty);
  });

  test('the bundled pirith recordings have no line times', () {
    final json = jsonDecode(File('assets/content/pirith.json').readAsStringSync())
        as Map<String, dynamic>;
    final catalogue = ContentAudioCatalogue(Library.fromJson(json));
    var n = 0;
    for (final c in Library.fromJson(json).categories) {
      for (final r in c.readings) {
        expect(catalogue.recordingFor(r.id)!.lineTimes, isEmpty, reason: r.id);
        n++;
      }
    }
    expect(n, 39);
  });

  test('the placeholder is chosen only in a debug build with the flag on', () {
    for (final (debug, flag, expected) in [
      (true, true, true),
      (true, false, false),
      (false, true, false),
      (false, false, false),
    ]) {
      final c = chooseCatalogue(
        real: _Empty(),
        debugBuild: debug,
        devAudioFlag: flag,
      );
      expect(c.recordingFor('r1') != null, expected, reason: '$debug $flag');
    }
  });

  test('the placeholder is labelled and marked as one', () {
    final r = DevPlaceholderCatalogue(_Empty()).recordingFor('r1')!;
    expect(r.placeholder, isTrue);
    expect(r.label, 'Development placeholder tone (not a chant)');
    expect(r.asset, 'assets/audio_dev/placeholder_tone_not_a_chant.wav');
  });

  test('a real recording is never replaced by the placeholder', () {
    final c = chooseCatalogue(
      real: _Real(),
      debugBuild: true,
      devAudioFlag: true,
    );
    final r = c.recordingFor('r1')!;
    expect(r.placeholder, isFalse);
    expect(r.asset, 'assets/audio/r1.mp3');
  });

  test('the fake library used by reader tests has no recording', () {
    expect(ContentAudioCatalogue(testLibrary()).recordingFor('r1'), isNull);
  });
}
