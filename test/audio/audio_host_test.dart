import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/audio_host.dart';
import 'package:buddhist_gatha/audio/recording_location.dart';
import 'package:flutter_test/flutter_test.dart';

const r = Recording(
  readingId: 'x',
  path: 'audio/pirith/08-mahamangala.m4a',
  label: '',
  placeholder: false,
);

void main() {
  test('the default host and path make one URL', () {
    expect(
      recordingUrlAt('https://audio.intendable.us', r).toString(),
      'https://audio.intendable.us/audio/pirith/08-mahamangala.m4a',
    );
  });

  test('a trailing slash on the base is not doubled', () {
    expect(
      recordingUrlAt('https://x.example/', r).toString(),
      'https://x.example/audio/pirith/08-mahamangala.m4a',
    );
  });

  test('without a dart-define the base is the default host', () {
    expect(audioBaseUrl, defaultAudioBaseUrl);
    expect(recordingUrl(r).host, 'namo-audio.v-g-a-induwara.workers.dev');
  });

  test('locations compare by value', () {
    expect(const FileLocation('/a'), const FileLocation('/a'));
    expect(const FileLocation('/a'), isNot(const AssetLocation('/a')));
  });
}
